import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';
import 'audio_recorder_service.dart';

/// 將整段錄音 WAV 切成多個檔（符合 API 單檔大小上限），或維持單檔。
class WavSplitService {
  WavSplitService._();

  static int get _bytesPerSecond =>
      AppConstants.sampleRate *
      AppConstants.numChannels *
      (AppConstants.bitsPerSample ~/ 8);

  /// 每段最長秒數（PCM）；整段小於此則不切割。
  static int get _sliceSeconds => AppConstants.postRecordTranscribeSliceSeconds;

  static int get _maxPcmPerSlice => _bytesPerSecond * _sliceSeconds;

  /// PCM 位元組率（16-bit mono），供由 WAV 檔長度粗估播放秒數。
  static int get pcmBytesPerSecond => _bytesPerSecond;

  /// 由 WAV 檔大小粗估播放秒數；非 WAV 回傳 `null`。
  static Future<int?> estimatePlaybackSeconds(File wavFile) async {
    if (!wavFile.path.toLowerCase().endsWith('.wav')) return null;
    final len = await wavFile.length();
    if (len <= 44) return null;
    return ((len - 44) / _bytesPerSecond).ceil().clamp(1, 24 * 3600);
  }

  /// 轉錄前準備上傳檔：WAV 可能切成多段；其餘格式（如 M4A）維持單檔。
  static Future<List<File>> prepareTranscriptionParts(File file) async {
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.wav')) {
      return splitToTempParts(file);
    }
    if (!await file.exists()) return [];
    if (await file.length() == 0) return [];
    return [file];
  }

  /// 回傳待上傳的 WAV 檔列表。若僅一段，回傳 `[original]`（不複製）。
  ///
  /// 位元組解析與各段 WAV 組裝屬 CPU 密集，長錄音時會卡住 UI isolate（掉幀）。
  /// 因此把純運算搬到背景 isolate（[compute]），只在主 isolate 做檔案 IO。
  static Future<List<File>> splitToTempParts(File originalWav) async {
    final bytes = await originalWav.readAsBytes();

    // 背景 isolate 做位元組驗證與切段組裝（無任何 Flutter/UI 依賴）。
    final result = await compute(
      _splitWavBytesInIsolate,
      _WavSplitInput(bytes: bytes, maxPcmPerSlice: _maxPcmPerSlice),
    );

    if (result.errorMessage != null) {
      throw FormatException(result.errorMessage!);
    }

    // 空音訊。
    if (result.sliceWavBytes == null) {
      return [];
    }

    // 未超過單段上限：回傳原檔（不複製）。
    if (result.useOriginal) {
      return [originalWav];
    }

    final slices = result.sliceWavBytes!;
    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final parts = <File>[];
    for (var i = 0; i < slices.length; i++) {
      final f = File('${tempDir.path}/slice_${stamp}_$i.wav');
      await f.writeAsBytes(slices[i]);
      parts.add(f);
    }
    return parts;
  }
}

/// [compute] 的輸入：原始 WAV 位元組與每段 PCM 上限（打包成單一參數）。
class _WavSplitInput {
  const _WavSplitInput({
    required this.bytes,
    required this.maxPcmPerSlice,
  });

  final Uint8List bytes;
  final int maxPcmPerSlice;
}

/// [compute] 的輸出：驗證錯誤、是否沿用原檔、或各段 WAV 位元組。
class _WavSplitResult {
  const _WavSplitResult({
    this.errorMessage,
    this.useOriginal = false,
    this.sliceWavBytes,
  });

  /// 非 null 表示驗證失敗，主 isolate 應丟出對應 [FormatException]。
  final String? errorMessage;

  /// true 表示未超過單段上限，主 isolate 沿用原檔。
  final bool useOriginal;

  /// 各段組裝好的 WAV 位元組；為 null 且未沿用原檔時代表空音訊（回傳空清單）。
  final List<Uint8List>? sliceWavBytes;
}

/// 背景 isolate 執行的純運算：驗證 WAV 標頭、切 PCM、組裝各段 WAV。
/// 不得依賴 Flutter/UI；僅使用 [AudioRecorderService.buildWav] 與純位元組操作。
_WavSplitResult _splitWavBytesInIsolate(_WavSplitInput input) {
  final bytes = input.bytes;
  final maxPcmPerSlice = input.maxPcmPerSlice;

  if (bytes.length < 44) {
    return const _WavSplitResult(errorMessage: '音訊檔過短或損毀');
  }
  final header = String.fromCharCodes(bytes.sublist(0, 4));
  if (header != 'RIFF') {
    return const _WavSplitResult(errorMessage: '非 WAV 格式');
  }

  final pcm = bytes.sublist(44);
  if (pcm.isEmpty) {
    // 空音訊：主 isolate 回傳空清單。
    return const _WavSplitResult();
  }

  if (pcm.length <= maxPcmPerSlice) {
    return const _WavSplitResult(useOriginal: true);
  }

  final slices = <Uint8List>[];
  for (var offset = 0; offset < pcm.length; offset += maxPcmPerSlice) {
    final end = offset + maxPcmPerSlice > pcm.length
        ? pcm.length
        : offset + maxPcmPerSlice;
    final slice = pcm.sublist(offset, end);
    slices.add(AudioRecorderService.buildWav(slice));
  }
  return _WavSplitResult(sliceWavBytes: slices);
}
