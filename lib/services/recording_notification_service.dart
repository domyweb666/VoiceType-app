import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 手機背景錄音保護：
/// - Android：常駐通知 + 啟動 native ForegroundService
/// - iOS：啟用 audio_session（搭配 Info.plist 的 UIBackgroundModes: audio）
/// - 桌面：no-op
class RecordingNotificationService {
  RecordingNotificationService._();
  static final RecordingNotificationService instance =
      RecordingNotificationService._();

  static const _channel = MethodChannel('com.voicetype/recording_fg');
  static const _notificationId = 4711;
  static const _androidChannelId = 'voicetype_recording_active';

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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          '錄音中',
          description: '顯示錄音進行中與已錄時長',
          importance: Importance.low,
          showBadge: false,
        ),
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

    if (Platform.isAndroid) {
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}
      try {
        await _channel.invokeMethod('start');
      } catch (_) {}
    }

    if (Platform.isIOS) {
      try {
        await _audioSession?.setActive(true);
      } catch (_) {}
    }

    _isActive = true;
    await _showNotification(elapsedText: elapsedText);
  }

  /// 每秒由 RecordingProvider 計時器呼叫，刷新通知文字。
  Future<void> updateElapsed(String elapsedText) async {
    if (!_enabledPlatform || !_isActive) return;
    await _showNotification(elapsedText: elapsedText);
  }

  /// 結束錄音時呼叫：關通知、關 ForegroundService、釋放 audio session。
  Future<void> stopRecording() async {
    if (!_enabledPlatform) return;
    _isActive = false;

    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    }

    if (Platform.isIOS) {
      try {
        await _audioSession?.setActive(false);
      } catch (_) {}
    }
  }

  Future<void> _showNotification({required String elapsedText}) async {
    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      '錄音中',
      channelDescription: '顯示錄音進行中與已錄時長',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      onlyAlertOnce: true,
      silent: true,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );
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
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (_) {}
  }
}
