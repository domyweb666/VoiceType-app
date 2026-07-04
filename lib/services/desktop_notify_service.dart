import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面平台的完成／失敗系統通知：只在視窗未聚焦時發（人在看畫面時
/// App 內 SnackBar 就夠了），點擊通知把視窗帶回前景。
class DesktopNotifyService {
  DesktopNotifyService._();

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool _ready = false;

  static Future<void> init() async {
    if (!isSupported) return;
    try {
      await localNotifier.setup(appName: 'VoiceType');
      _ready = true;
    } catch (e) {
      debugPrint('DesktopNotifyService init: $e');
    }
  }

  /// 視窗聚焦時不打擾；未聚焦（最小化、收在系統匣、在別的視窗工作）才通知。
  static Future<void> showIfUnfocused({required String body}) async {
    if (!_ready) return;
    try {
      if (await windowManager.isFocused()) return;
      final notification = LocalNotification(title: 'VoiceType', body: body);
      notification.onClick = () async {
        await windowManager.show();
        await windowManager.focus();
      };
      await notification.show();
    } catch (e) {
      debugPrint('DesktopNotifyService show: $e');
    }
  }
}
