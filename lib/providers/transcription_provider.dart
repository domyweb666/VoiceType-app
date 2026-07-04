import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/constants.dart';
import '../models/polish_raw_result.dart';
import '../models/transcription_segment.dart';
import '../services/byteplus_asr_service.dart';
import '../services/cost_estimate_service.dart';
import '../services/openai_service.dart';
import '../services/wav_split_service.dart';
import '../utils/openai_retry.dart';

class TranscriptionProvider extends ChangeNotifier {
  OpenAIService? _openAIService;
  BytePlusAsrService? _bytePlusService;

  /// 轉錄引擎；潤飾一律走 OpenAI。
  AsrEngine _engine = AsrEngine.openai;

  final List<TranscriptionSegment> _segments = [];
  /// 快取的口語稿（逐字合併）；僅在 [_segments] 變動時失效，避免每次讀取都重算。
  String? _rawTranscriptCache;
  String _organizedText = '';
  /// 由轉錄／潤飾／清除等流程遞增；UI 依此同步文字稿欄位，避免蓋過使用者正在編輯的內容。
  int _organizedTextVersion = 0;
  bool _isTranscribing = false;
  bool _isOrganizing = false;

  String? _error;
  String? _errorDebugLine;
  int _transcribePartIndex = 0;
  int _transcribePartTotal = 0;
  /// 最近一次轉錄使用的 WAV 絕對路徑（失敗時供「重試轉錄」；成功刪檔後會清除）。
  String? _lastTranscribeSessionPath;
  int _lastTranscribeAudioSecondsForCost = 0;
  String? _lastSessionCostHint;
  /// 多段轉錄失敗時：與 [sessionWav] 相同路徑且從 [_resumeFromPartIndex] 段繼續（0-based）。
  String? _resumeSessionAbsolutePath;
  int? _resumeFromPartIndex;

  List<TranscriptionSegment> get segments => List.unmodifiable(_segments);
  String get rawTranscript =>
      _rawTranscriptCache ??= _segments.map((s) => s.text).join('');
  String get organizedText => _organizedText;

  int get organizedTextVersion => _organizedTextVersion;

  bool get isTranscribing => _isTranscribing;
  bool get isOrganizing => _isOrganizing;
  String? get error => _error;
  String? get errorDebugLine => _errorDebugLine;
  bool get hasTranscript => _segments.isNotEmpty;

  /// 長錄音分段上傳時「第幾段／共幾段」，未在轉錄或僅一段時為 0。
  int get transcribePartIndex => _transcribePartIndex;
  int get transcribePartTotal => _transcribePartTotal;
  String? get lastTranscribeSessionPath => _lastTranscribeSessionPath;

  /// 是否有「分段失敗後可自同一檔自該段重試」的狀態。
  bool get hasPartialTranscribeResume =>
      _resumeSessionAbsolutePath != null && _resumeFromPartIndex != null;

  /// 上一輪「轉錄 + 潤飾」完成後的粗估新台幣說明（僅供參考）。
  String? get lastSessionCostHint => _lastSessionCostHint;

  /// 供複製：使用者可見說明 + 簡短技術列（如 HTTP 狀態）。
  String? get errorClipboardText {
    if (_error == null) return null;
    if (_errorDebugLine == null || _errorDebugLine!.isEmpty) {
      return _error;
    }
    return '${_error!}\n[$_errorDebugLine]';
  }

  String? _whisperVocabularyHint;

  /// 轉錄 API 的 `prompt`：繁體提示 + 可選專有名詞 + 前段逐字結尾（在字數上限內）。
  String _buildTranscriptionPrompt() {
    final hint = AppConstants.transcriptionTraditionalHint;
    final max = AppConstants.maxPromptChars;
    var head = hint;
    final rawVocab = _whisperVocabularyHint?.trim();
    if (rawVocab != null && rawVocab.isNotEmpty) {
      const prefix = '\n專有名詞：';
      var budgetForVocab = max - hint.length - prefix.length;
      if (budgetForVocab > 4) {
        var v = rawVocab;
        if (v.length > budgetForVocab) {
          v = v.substring(0, budgetForVocab);
        }
        head = '$hint$prefix$v';
      }
    }
    if (head.length >= max) {
      return head.substring(0, max);
    }
    const sep = '\n';
    if (rawTranscript.isEmpty) {
      return head;
    }
    final budget = max - head.length - sep.length;
    if (budget <= 0) {
      return head.substring(0, max);
    }
    final t = rawTranscript;
    final tail = t.length > budget ? t.substring(t.length - budget) : t;
    return '$head$sep$tail';
  }

  void updateApiKey(String? apiKey) {
    if (apiKey != null && apiKey.isNotEmpty) {
      if (_openAIService == null) {
        _openAIService = OpenAIService(apiKey: apiKey);
      } else {
        _openAIService!.updateApiKey(apiKey);
      }
    } else {
      if (_openAIService != null) {
        _openAIService = null;
        _isTranscribing = false;
        notifyListeners();
      }
    }
  }

  void updateBytePlusKey(String? apiKey) {
    if (apiKey != null && apiKey.isNotEmpty) {
      if (_bytePlusService == null) {
        _bytePlusService = BytePlusAsrService(apiKey: apiKey);
      } else {
        _bytePlusService!.updateApiKey(apiKey);
      }
    } else {
      _bytePlusService = null;
    }
  }

  void setEngine(AsrEngine engine) {
    _engine = engine;
  }

  /// 目前引擎是否已有可用的轉錄服務。
  bool get _hasTranscribeService => _engine == AsrEngine.byteplus
      ? _bytePlusService != null
      : _openAIService != null;

  /// 錄音結束後：將整段音訊切成數段（必要時）並依序轉錄成口語稿（逐字合併）。
  /// 僅在**整段轉錄成功**後才刪除 [sessionWav]；失敗時保留檔案以便重試。
  /// 多段時若中段失敗，對**同一檔案**再呼叫會自失敗段繼續，已成功的口語稿段落保留。
  ///
  /// [whisperVocabularyHint] 會併入轉錄 `prompt`（字數受限），例如自訂專有名詞。
  Future<void> transcribeSessionWav(
    File sessionWav, {
    String? whisperVocabularyHint,
  }) async {
    _whisperVocabularyHint = whisperVocabularyHint;
    final abs = sessionWav.absolute.path;

    if (_resumeSessionAbsolutePath != null &&
        _resumeSessionAbsolutePath != abs) {
      _resumeSessionAbsolutePath = null;
      _resumeFromPartIndex = null;
    }

    final resumeHere = _resumeSessionAbsolutePath != null &&
        _resumeSessionAbsolutePath == abs &&
        _resumeFromPartIndex != null;

    _lastTranscribeSessionPath = abs;
    if (!resumeHere) {
      _lastSessionCostHint = null;
    }

    if (!_hasTranscribeService) {
      _error = _engine == AsrEngine.byteplus
          ? '尚未設定 BytePlus 金鑰，請至設定輸入。'
          : '尚未設定 API 金鑰';
      _errorDebugLine = null;
      _whisperVocabularyHint = null;
      notifyListeners();
      return;
    }

    _isTranscribing = true;
    _error = null;
    _errorDebugLine = null;
    _transcribePartIndex = 0;
    _transcribePartTotal = 0;
    if (!resumeHere) {
      _segments.clear();
      _rawTranscriptCache = null;
    }
    _organizedText = '';
    _organizedTextVersion++;
    notifyListeners();

    List<File> parts = [];
    var allSucceeded = false;

    try {
      parts = await WavSplitService.prepareTranscriptionParts(sessionWav);
      if (parts.isEmpty) {
        _error = '沒有錄到音訊';
        return;
      }

      // 單檔上限為 OpenAI 端限制；BytePlus 以 base64 內嵌、上限寬鬆許多。
      if (parts.length == 1 && _engine == AsrEngine.openai) {
        final sz = await parts[0].length();
        if (sz > AppConstants.maxOpenAITranscribeFileBytes) {
          _error = AppConstants.oversizedTranscribeFileUserHint;
          return;
        }
      }

      _transcribePartTotal = parts.length;
      notifyListeners();

      final startIndex = resumeHere ? _resumeFromPartIndex! : 0;

      if (resumeHere && startIndex > 0) {
        for (var k = 0; k < startIndex; k++) {
          final skipSlice = parts.length > 1 ||
              parts[k].absolute.path != sessionWav.absolute.path;
          if (skipSlice) {
            try {
              await parts[k].delete();
            } catch (_) {}
          }
        }
      }

      allSucceeded = true;
      for (var i = startIndex; i < parts.length; i++) {
        _transcribePartIndex = i + 1;
        notifyListeners();

        final isDisposableSlice = parts.length > 1 ||
            parts[i].absolute.path != sessionWav.absolute.path;
        final ok = await _transcribeOneFileWithRetries(
          parts[i],
          isDisposableSlice: isDisposableSlice,
        );
        if (!ok) {
          for (var j = i + 1; j < parts.length; j++) {
            try {
              await parts[j].delete();
            } catch (_) {}
          }
          allSucceeded = false;
          _resumeSessionAbsolutePath = abs;
          if (parts.length > 1) {
            _resumeFromPartIndex = i;
            if (_error != null) {
              _error =
                  '$_error（第 ${i + 1}/${parts.length} 段失敗；重試將自該段繼續，前段口語稿已保留）';
            }
          } else {
            _resumeFromPartIndex = null;
          }
          break;
        }
      }
    } catch (e) {
      _error = '無法處理錄音檔：${_safeErrorText(e)}';
      _errorDebugLine = _debugLineForException(e);
      allSucceeded = false;
      _resumeFromPartIndex = null;
    } finally {
      _whisperVocabularyHint = null;
      _transcribePartIndex = 0;
      _transcribePartTotal = 0;
      _isTranscribing = false;
      notifyListeners();
    }

    if (allSucceeded) {
      _resumeSessionAbsolutePath = null;
      _resumeFromPartIndex = null;
      var est = await WavSplitService.estimatePlaybackSeconds(sessionWav);
      if (est == null || est < 1) {
        final charsPerSec =
            SessionCostEstimateService.assumedCharsPerSpokenMinute / 60.0;
        final approx = (rawTranscript.length / charsPerSec).ceil();
        est = approx.clamp(1, 24 * 3600);
      }
      _lastTranscribeAudioSecondsForCost = est;
      try {
        if (await sessionWav.exists()) {
          await sessionWav.delete();
        }
      } catch (_) {}
      _lastTranscribeSessionPath = null;
    }
  }

  Future<bool> _transcribeOneFileWithRetries(
    File wavFile, {
    required bool isDisposableSlice,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt < AppConstants.transcriptionMaxAttempts; attempt++) {
      if (!_hasTranscribeService) break;

      try {
        // BytePlus 不支援 Whisper 式 prompt 銜接；詞彙表仍會在潤飾階段套用。
        final text = _engine == AsrEngine.byteplus
            ? await _bytePlusService!.transcribeAudio(wavFile)
            : await _openAIService!
                .transcribeAudio(wavFile, prompt: _buildTranscriptionPrompt());
        if (text.isNotEmpty) {
          _segments.add(TranscriptionSegment(
            text: text,
            timestamp: DateTime.now(),
          ));
          _rawTranscriptCache = null;
        }
        _error = null;
        _errorDebugLine = null;
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
        final retryable = isRetryableOpenAIRequestError(e) ||
            (e is BytePlusAsrException && e.isRetryable);
        final canRetry =
            attempt < AppConstants.transcriptionMaxAttempts - 1 && retryable;
        if (canRetry) {
          final delay = AppConstants.transcriptionRetryBaseDelay * (1 << attempt);
          await Future<void>.delayed(delay);
        } else {
          break;
        }
      }
    }

    if (isDisposableSlice) {
      try {
        await wavFile.delete();
      } catch (_) {}
    }

    if (lastError != null) {
      _error = _formatTranscriptionError(lastError);
      _errorDebugLine = _debugLineForException(lastError);
      notifyListeners();
      return false;
    }
    return true;
  }

  static String? _debugLineForException(Object e) {
    if (e is DioException) {
      final c = e.response?.statusCode;
      return 'Dio ${e.type.name}${c != null ? ' HTTP $c' : ''}';
    }
    if (e is BytePlusAsrException) {
      return 'BytePlus ${e.statusCode ?? '?'}';
    }
    return e.runtimeType.toString();
  }

  String _formatTranscriptionError(Object e) {
    if (e is BytePlusAsrException) {
      return e.message;
    }
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'API 金鑰無效或未授權，請至設定檢查。';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return '連線逾時（已重試仍失敗），請檢查網路後再試。';
      }
      if (e.type == DioExceptionType.connectionError) {
        return '無法連線至伺服器（已重試仍失敗），請檢查網路。';
      }
      if (code == 429) return '請求過於頻繁（429），請稍後再試。';
      if (code == 413) {
        return AppConstants.oversizedTranscribeFileUserHint;
      }
    }
    return '轉錄失敗（已自動重試）：${_safeErrorText(e)}';
  }

  /// 供使用者可複製的錯誤字串：DioException 只保留「類型 (HTTP 狀態)」，
  /// 不外洩伺服器回應內容（response body）；其餘例外照原樣。
  static String _safeErrorText(Object e) {
    if (e is DioException) {
      final c = e.response?.statusCode;
      return '${e.type.name}${c != null ? ' (HTTP $c)' : ''}';
    }
    return e.toString();
  }

  /// 第二階段：口語稿 → 文字稿（潤飾）。
  /// [fullRoundTripCost] 為 true 時，費用提示含「轉錄 + 潤飾」；僅手動再次潤飾時請傳 false。
  Future<void> organizeTranscript({
    required String systemPrompt,
    bool fullRoundTripCost = true,
  }) async {
    if (_openAIService == null) {
      _error = '尚未設定 OpenAI 金鑰（潤飾需要），請至設定輸入。';
      _errorDebugLine = null;
      notifyListeners();
      return;
    }

    if (rawTranscript.isEmpty) return;

    _isOrganizing = true;
    _error = null;
    _errorDebugLine = null;
    _lastSessionCostHint = null;
    notifyListeners();

    Object? lastError;
    try {
      for (var attempt = 0; attempt < AppConstants.organizeMaxAttempts; attempt++) {
        try {
          final r = await _openAIService!.organizeText(
            rawTranscript,
            systemPrompt: systemPrompt,
          );
          _organizedText = r.text;
          _organizedTextVersion++;
          lastError = null;

          if (fullRoundTripCost) {
            var audioSecs = _lastTranscribeAudioSecondsForCost;
            if (audioSecs < 1) {
              final charsPerSec =
                  SessionCostEstimateService.assumedCharsPerSpokenMinute / 60.0;
              audioSecs =
                  (rawTranscript.length / charsPerSec).ceil().clamp(1, 86400);
            }
            _lastSessionCostHint =
                SessionCostEstimateService.buildRoundTripTwdRangeHint(
              audioSeconds: audioSecs,
              organizePromptTokens: r.promptTokens,
              organizeCompletionTokens: r.completionTokens,
              rawTranscriptCharCount: rawTranscript.length,
            );
          } else {
            _lastSessionCostHint =
                SessionCostEstimateService.buildPolishOnlyTwdRangeHint(
              organizePromptTokens: r.promptTokens,
              organizeCompletionTokens: r.completionTokens,
              rawTranscriptCharCount: rawTranscript.length,
            );
          }
          break;
        } catch (e) {
          lastError = e;
          final canRetry = attempt < AppConstants.organizeMaxAttempts - 1 &&
              isRetryableOpenAIRequestError(e);
          if (canRetry) {
            final delay = AppConstants.organizeRetryBaseDelay * (1 << attempt);
            await Future<void>.delayed(delay);
          } else {
            break;
          }
        }
      }

      if (lastError != null) {
        _error = '產生文字稿失敗（已重試）：${_safeErrorText(lastError)}';
        _errorDebugLine = _debugLineForException(lastError);
      }
    } finally {
      _isOrganizing = false;
      notifyListeners();
    }
  }

  /// 歷史詳情「只潤飾」：不修改首頁口語稿狀態。
  Future<PolishRawResult> polishStandalone({
    required String rawText,
    required String systemPrompt,
  }) async {
    if (_openAIService == null) {
      return PolishRawResult.failure('尚未設定 API 金鑰');
    }
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return PolishRawResult.failure('口語稿為空');
    }

    _isOrganizing = true;
    _error = null;
    _errorDebugLine = null;
    notifyListeners();

    Object? lastError;
    try {
      for (var attempt = 0; attempt < AppConstants.organizeMaxAttempts; attempt++) {
        try {
          final r = await _openAIService!.organizeText(
            trimmed,
            systemPrompt: systemPrompt,
          );
          final out = r.text.trim();
          if (out.isEmpty) {
            return PolishRawResult.failure('潤飾結果為空');
          }
          return PolishRawResult.success(
            text: out,
            promptTokens: r.promptTokens,
            completionTokens: r.completionTokens,
          );
        } catch (e) {
          lastError = e;
          final canRetry = attempt < AppConstants.organizeMaxAttempts - 1 &&
              isRetryableOpenAIRequestError(e);
          if (canRetry) {
            final delay = AppConstants.organizeRetryBaseDelay * (1 << attempt);
            await Future<void>.delayed(delay);
          } else {
            break;
          }
        }
      }
      return PolishRawResult.failure(
        '潤飾失敗（已重試）：${lastError != null ? _safeErrorText(lastError) : '未知錯誤'}',
      );
    } finally {
      _isOrganizing = false;
      notifyListeners();
    }
  }

  /// 使用者於文字稿分頁手動編輯時同步（不遞增 [organizedTextVersion]）。
  void setOrganizedTextUser(String value) {
    _organizedText = value;
    notifyListeners();
  }

  void clear() {
    _segments.clear();
    _rawTranscriptCache = null;
    _organizedText = '';
    _organizedTextVersion++;
    _error = null;
    _errorDebugLine = null;
    _isTranscribing = false;
    _transcribePartIndex = 0;
    _transcribePartTotal = 0;
    _lastTranscribeSessionPath = null;
    _lastTranscribeAudioSecondsForCost = 0;
    _lastSessionCostHint = null;
    _resumeSessionAbsolutePath = null;
    _resumeFromPartIndex = null;
    notifyListeners();
  }
}
