import 'dart:io';

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
  static Future<List<File>> splitToTempParts(File originalWav) async {
    final bytes = await originalWav.readAsBytes();
    if (bytes.length < 44) {
      throw const FormatException('音訊檔過短或損毀');
    }
    final header = String.fromCharCodes(bytes.sublist(0, 4));
    if (header != 'RIFF') {
      throw const FormatException('非 WAV 格式');
    }

    final pcm = bytes.sublist(44);
    if (pcm.isEmpty) {
      return [];
    }

    if (pcm.length <= _maxPcmPerSlice) {
      return [originalWav];
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final parts = <File>[];

    for (var offset = 0, i = 0; offset < pcm.length; offset += _maxPcmPerSlice, i++) {
      final end = offset + _maxPcmPerSlice > pcm.length
          ? pcm.length
          : offset + _maxPcmPerSlice;
      final slice = pcm.sublist(offset, end);
      final wavBytes = AudioRecorderService.buildWav(slice);
      final f = File('${tempDir.path}/slice_${stamp}_$i.wav');
      await f.writeAsBytes(wavBytes);
      parts.add(f);
    }

    return parts;
  }
}
