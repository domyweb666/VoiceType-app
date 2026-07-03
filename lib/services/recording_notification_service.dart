import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 手機背景錄音保護：
/// - Android：通知完全由 native ForegroundService（通知 4711）獨占，
///   本類只透過 MethodChannel 下 start / update / stop 指令並申請通知權限。
/// - iOS：啟用 audio_session + flutter_local_notifications 顯示常駐通知
///   （搭配 Info.plist 的 UIBackgroundModes: audio）
/// - 桌面：no-op
class RecordingNotificationService {
  RecordingNotificationService._();
  static final RecordingNotificationService instance =
      RecordingNotificationService._();

  static const _channel = MethodChannel('com.voicetype/recording_fg');
  static const _notificationId = 4711; // 僅 iOS 使用

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isActive = false;
  AudioSession? _audioSession;

  bool get _enabledPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized || !_enabledPlatform) return;
    _initialized = true;

    // Android 的錄音通知完全交給 native ForegroundService（通知 4711），
    // 這裡不再初始化 flutter_local_notifications，避免兩邊搶同一個 id 打架。
    if (Platform.isIOS) {
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(iOS: iosInit),
      );
    }

    if (Platform.isIOS) {
      try {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.measurement,
        ));
      } catch (_) {}
    }
  }

  /// 開始錄音時呼叫：申請通知權限、啟動 ForegroundService、亮通知。
  Future<void> startRecording({required String elapsedText}) async {
    if (!_enabledPlatform) return;
    await initialize();
    _isActive = true;

    if (Platform.isAndroid) {
      // 先申請通知權限，通知本體由 native ForegroundService 顯示。
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}
      try {
        await _channel.invokeMethod('start', {'elapsed': elapsedText});
      } catch (_) {}
    }

    if (Platform.isIOS) {
      try {
        await _audioSession?.setActive(true);
      } catch (_) {}
      await _showNotification(elapsedText: elapsedText);
    }
  }

  /// 每秒由 RecordingProvider 計時器呼叫，刷新通知文字。
  Future<void> updateElapsed(String elapsedText) async {
    if (!_enabledPlatform || !_isActive) return;

    if (Platform.isAndroid) {
      // 交給 native 服務原地更新同一則通知 4711。
      try {
        await _channel.invokeMethod('update', {'elapsed': elapsedText});
      } catch (_) {}
    }

    if (Platform.isIOS) {
      await _showNotification(elapsedText: elapsedText);
    }
  }

  /// 結束錄音時呼叫：關通知、關 ForegroundService、釋放 audio session。
  Future<void> stopRecording() async {
    if (!_enabledPlatform) return;
    _isActive = false;

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    }

    if (Platform.isIOS) {
      try {
        await _plugin.cancel(_notificationId);
      } catch (_) {}
      try {
        await _audioSession?.setActive(false);
      } catch (_) {}
    }
  }

  /// 僅 iOS 使用：透過 flutter_local_notifications 顯示 / 更新錄音通知。
  Future<void> _showNotification({required String elapsedText}) async {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );
    try {
      await _plugin.show(
        _notificationId,
        'VoiceType 錄音中',
        elapsedText,
        const NotificationDetails(iOS: iosDetails),
      );
    } catch (_) {}
  }
}
