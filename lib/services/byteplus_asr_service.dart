import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/constants.dart';

/// BytePlus ASR 的業務錯誤（HTTP 可能是 200，但 X-Api-Status-Code 表頭帶錯誤碼）。
class BytePlusAsrException implements Exception {
  final String message;

  /// X-Api-Status-Code 表頭值；45 開頭為金鑰／權限、55 開頭為伺服器暫時錯誤。
  final String? statusCode;

  BytePlusAsrException(this.message, {this.statusCode});

  /// 伺服器暫時錯誤可重試；金鑰／權限與內容錯誤不重試。
  bool get isRetryable => statusCode != null && statusCode!.startsWith('55');

  @override
  String toString() => message;
}

/// BytePlus Seed Speech ASR（Audio File 2.0 / bigmodel）非同步轉錄：
/// submit 以 base64 內嵌音檔 → 用同一個 Request-Id 輪詢 query 直到完成。
/// 流程與欄位參考官方文件（狀態碼 20000000 完成、20000001/20000002 處理中）。
class BytePlusAsrService {
  final Dio _dio;
  String _apiKey;

  BytePlusAsrService({required String apiKey})
      : _apiKey = apiKey,
        _dio = Dio(BaseOptions(
          baseUrl: AppConstants.bytePlusAsrBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  void updateApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  static final Random _rng = Random.secure();

  /// RFC 4122 v4 形式的隨機 Request-Id（避免為此多拉一個 uuid 依賴）。
  static String newRequestId() {
    String hex(int n) =>
        List.generate(n, (_) => _rng.nextInt(16).toRadixString(16)).join();
    final variant = (8 + _rng.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }

  Map<String, String> _headers(String requestId, {bool withSequence = false}) {
    return {
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
      'X-Api-Resource-Id': AppConstants.bytePlusResourceId,
      'X-Api-Request-Id': requestId,
      if (withSequence) 'X-Api-Sequence': '-1',
    };
  }

  static String? _statusOf(Response<dynamic> r) =>
      r.headers.value('X-Api-Status-Code');

  Future<void> _submit({
    required String requestId,
    required List<int> audioBytes,
    required String format,
  }) async {
    final body = {
      'user': {'uid': 'voicetype'},
      'audio': {
        'data': base64Encode(audioBytes),
        'format': format,
        'language': AppConstants.bytePlusLanguage,
      },
      'request': {
        'model_name': AppConstants.bytePlusModelName,
        'enable_itn': true,
        'enable_punc': true,
        // 口語稿需要逐字（verbatim），贅字清理交給後段潤飾，故不開 ddc。
        'enable_ddc': false,
      },
    };
    final r = await _dio.post<dynamic>(
      '/submit',
      data: body,
      options: Options(
        headers: _headers(requestId, withSequence: true),
        validateStatus: (_) => true,
      ),
    );
    final sc = _statusOf(r);
    if (r.statusCode != 200 || sc != '20000000') {
      throw _errorFor(sc, httpStatus: r.statusCode, phase: 'submit');
    }
  }

  Future<String> _pollResult(String requestId) async {
    final deadline = DateTime.now().add(AppConstants.bytePlusMaxWait);
    while (true) {
      final r = await _dio.post<dynamic>(
        '/query',
        data: const <String, dynamic>{},
        options: Options(
          headers: _headers(requestId),
          validateStatus: (_) => true,
        ),
      );
      final sc = _statusOf(r);
      if (sc == '20000000') {
        final data = r.data;
        if (data is Map) {
          final result = data['result'];
          if (result is Map && result['text'] is String) {
            return (result['text'] as String).trim();
          }
        }
        throw BytePlusAsrException(
          'BytePlus 轉錄回應格式異常（缺少 result.text）',
          statusCode: sc,
        );
      }
      if (sc == '20000001' || sc == '20000002') {
        if (DateTime.now().isAfter(deadline)) {
          throw BytePlusAsrException(
            'BytePlus 轉錄逾時（等待超過 ${AppConstants.bytePlusMaxWait.inMinutes} 分鐘），請重試。',
            statusCode: sc,
          );
        }
        await Future<void>.delayed(AppConstants.bytePlusPollInterval);
        continue;
      }
      throw _errorFor(sc, httpStatus: r.statusCode, phase: 'query');
    }
  }

  static BytePlusAsrException _errorFor(
    String? sc, {
    int? httpStatus,
    required String phase,
  }) {
    if (sc != null && sc.startsWith('45')) {
      return BytePlusAsrException(
        'BytePlus 金鑰無效、權限不足或模型未開通（$sc），請至設定檢查。',
        statusCode: sc,
      );
    }
    if (sc != null && sc.startsWith('55')) {
      return BytePlusAsrException(
        'BytePlus 伺服器暫時無法服務（$sc），請稍後再試。',
        statusCode: sc,
      );
    }
    return BytePlusAsrException(
      'BytePlus $phase 失敗（狀態碼 ${sc ?? 'HTTP $httpStatus'}）',
      statusCode: sc,
    );
  }

  /// 轉錄單一音檔（WAV／M4A）為文字。呼叫端負責切段與重試。
  Future<String> transcribeAudio(File audioFile) async {
    final format =
        audioFile.path.toLowerCase().endsWith('.m4a') ? 'm4a' : 'wav';
    final bytes = await audioFile.readAsBytes();
    final requestId = newRequestId();
    await _submit(requestId: requestId, audioBytes: bytes, format: format);
    return _pollResult(requestId);
  }

  /// 驗證金鑰：提交 0.2 秒靜音 WAV，submit 被接受（20000000）即視為有效，
  /// 不等轉錄結果。金鑰錯誤會擲出 [BytePlusAsrException]（45 開頭狀態碼）。
  Future<void> verifyKey() async {
    await _submit(
      requestId: newRequestId(),
      audioBytes: _silentWav(),
      format: 'wav',
    );
  }

  /// 產生 0.2 秒 16kHz／16bit／mono 的靜音 WAV 位元組（僅供金鑰驗證）。
  static List<int> _silentWav() {
    const sampleRate = 16000;
    const samples = 3200; // 0.2 秒
    const dataLen = samples * 2;
    final b = BytesBuilder();
    void str(String s) => b.add(ascii.encode(s));
    void u32(int v) =>
        b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(dataLen);
    b.add(List.filled(dataLen, 0));
    return b.takeBytes();
  }
}
