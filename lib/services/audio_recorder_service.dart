import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../config/constants.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Stream<Uint8List>> startRecording() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: AppConstants.numChannels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    return stream.map((data) => Uint8List.fromList(data));
  }

  Future<void> stopRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Build a WAV file from raw PCM data.
  static Uint8List buildWav(Uint8List pcmData) {
    final byteRate =
        AppConstants.sampleRate * AppConstants.numChannels * (AppConstants.bitsPerSample ~/ 8);
    final blockAlign = AppConstants.numChannels * (AppConstants.bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E

    // fmt chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6D); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, AppConstants.numChannels, Endian.little);
    buffer.setUint32(24, AppConstants.sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, AppConstants.bitsPerSample, Endian.little);

    // data chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);

    // PCM data
    final wavBytes = buffer.buffer.asUint8List();
    wavBytes.setRange(44, 44 + dataSize, pcmData);

    return wavBytes;
  }

  void dispose() {
    _recorder.dispose();
  }
}
