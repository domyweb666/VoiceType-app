import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/audio_recorder_service.dart';
import '../services/recording_notification_service.dart';

/// 連續寫入 PCM，停止時組成單一 WAV（與轉錄／待轉錄佇列相容）。
class RecordingProvider extends ChangeNotifier {
  final AudioRecorderService _recorderService = AudioRecorderService();

  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;
  StreamSubscription<Uint8List>? _streamSub;
  Completer<void>? _pcmStreamEnded;
  RandomAccessFile? _pcmOut;
  File? _pcmTempFile;
  double _inputLevel = 0;
  DateTime? _lastLevelNotify;
  int _pcmBytesWritten = 0;
  static const int _maxWaveformSamples = 80;
  final List<double> _waveformSamples = <double>[];

  bool get isRecording => _isRecording;
  Duration get elapsed => _elapsed;
  double get inputLevel => _inputLevel;
  List<double> get waveformSamples => List<double>.unmodifiable(_waveformSamples);
  int get estimatedRecordingPcmBytes => _pcmBytesWritten;

  String get elapsedFormatted {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<bool> hasPermission() => _recorderService.hasPermission();

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerms = await _recorderService.hasPermission();
    if (!hasPerms) return;

    _isRecording = true;
    _elapsed = Duration.zero;
    _inputLevel = 0;
    _pcmBytesWritten = 0;
    _waveformSamples.clear();
    notifyListeners();

    final tempDir = await getTemporaryDirectory();
    _pcmTempFile = File(
      '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.pcm',
    );
    _pcmOut = await _pcmTempFile!.open(mode: FileMode.write);

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
      unawaited(
        RecordingNotificationService.instance
            .updateElapsed(elapsedFormatted),
      );
    });

    unawaited(
      RecordingNotificationService.instance
          .startRecording(elapsedText: elapsedFormatted),
    );

    final stream = await _recorderService.startRecording();
    _pcmStreamEnded = Completer<void>();
    final ended = _pcmStreamEnded!;
    _streamSub = stream.listen(
      _onPcmData,
      onError: (Object err, StackTrace stackTrace) {
        if (!ended.isCompleted) ended.complete();
      },
      onDone: () {
        if (!ended.isCompleted) ended.complete();
      },
      cancelOnError: false,
    );
  }

  void _onPcmData(Uint8List data) {
    // 停止錄音後 UI 會先設 _isRecording=false，但仍須寫入尾端 PCM（record 套件要求依賴 onDone）。
    if (_pcmOut == null) return;
    try {
      _pcmOut?.writeFromSync(data);
      _pcmBytesWritten += data.length;
    } catch (_) {}

    double sum = 0;
    var count = 0;
    for (var i = 0; i + 1 < data.length; i += 2) {
      final lo = data[i];
      final hi = data[i + 1];
      var sample = hi << 8 | lo;
      if (sample & 0x8000 != 0) sample -= 65536;
      sum += sample * sample;
      count++;
    }
    if (count == 0) return;
    final rms = math.sqrt(sum / count) / 32768.0;
    _inputLevel = math.min(1.0, rms * 10);
    _waveformSamples.add(_inputLevel);
    while (_waveformSamples.length > _maxWaveformSamples) {
      _waveformSamples.removeAt(0);
    }
    final now = DateTime.now();
    if (_lastLevelNotify == null ||
        now.difference(_lastLevelNotify!).inMilliseconds > 90) {
      _lastLevelNotify = now;
      notifyListeners();
    }
  }

  /// 結束錄音並產生完整 WAV。無有效音訊時回傳 `null`。
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    _inputLevel = 0;
    _waveformSamples.clear();
    _lastLevelNotify = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    notifyListeners();

    unawaited(RecordingNotificationService.instance.stopRecording());

    final ended = _pcmStreamEnded;
    await _recorderService.stopRecording();

    if (ended != null) {
      try {
        await ended.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      } catch (_) {}
    }

    await _streamSub?.cancel();
    _streamSub = null;
    _pcmStreamEnded = null;

    try {
      await _pcmOut?.flush();
      await _pcmOut?.close();
    } catch (_) {}
    _pcmOut = null;

    final pcmFile = _pcmTempFile;
    _pcmTempFile = null;

    notifyListeners();

    if (pcmFile == null || !await pcmFile.exists()) {
      return null;
    }

    final pcm = await pcmFile.readAsBytes();
    try {
      await pcmFile.delete();
    } catch (_) {}

    if (pcm.isEmpty) {
      return null;
    }

    final wavBytes = AudioRecorderService.buildWav(pcm);
    final tempDir = await getTemporaryDirectory();
    final wavFile = File(
      '${tempDir.path}/session_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await wavFile.writeAsBytes(wavBytes);
    return wavFile;
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    final pcmFile = _pcmTempFile;
    _pcmTempFile = null;
    unawaited(() async {
      try {
        await _streamSub?.cancel();
      } catch (_) {}
      try {
        await _pcmOut?.flush();
      } catch (_) {}
      try {
        await _pcmOut?.close();
      } catch (_) {}
      if (pcmFile != null) {
        try {
          if (await pcmFile.exists()) await pcmFile.delete();
        } catch (_) {}
      }
    }());
    _recorderService.dispose();
    super.dispose();
  }
}
