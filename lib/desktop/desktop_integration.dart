import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../services/recording_hotkey_bus.dart';

/// Windows：關閉視窗收到系統匣、全域快捷鍵、匣選單。
class DesktopIntegration {
  DesktopIntegration._();

  static bool get isSupported => Platform.isWindows || Platform.isMacOS;

  static final _VoiceWindowListener _winListener = _VoiceWindowListener();
  static final _VoiceTrayListener _trayListener = _VoiceTrayListener();

  static Future<void> initIfWindows() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();

    const opts = WindowOptions(
      size: Size(920, 740),
      center: true,
      // 全透明在部分顯示環境下會變成整片白／閃爍，改為不透明底色。
      backgroundColor: Color(0xFFF8FAFA),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setPreventClose(true);
    windowManager.removeListener(_winListener);
    windowManager.addListener(_winListener);

    try {
      final data = await rootBundle.load('assets/tray_icon.png');
      final dir = await getTemporaryDirectory();
      final iconFile = File('${dir.path}/voicetype_tray.png');
      await iconFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await trayManager.setIcon(iconFile.path);
    } catch (e) {
      debugPrint('Tray icon: $e');
    }

    await trayManager.setToolTip('VoiceType');
    trayManager.removeListener(_trayListener);
    trayManager.addListener(_trayListener);

    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '顯示主視窗',
          onClick: (_) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuItem(
          key: 'toggle',
          label: '開始／停止錄音',
          onClick: (_) {
            RecordingHotkeyBus.instance.requestToggle();
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: '結束 VoiceType',
          onClick: (_) async {
            await hotKeyManager.unregisterAll();
            await trayManager.destroy();
            await windowManager.destroy();
            exit(0);
          },
        ),
      ],
    );
    await trayManager.setContextMenu(menu);

    await hotKeyManager.register(
      HotKey(
        identifier: 'voicetype.toggleRecord',
        key: LogicalKeyboardKey.keyV,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      ),
      keyDownHandler: (_) {
        RecordingHotkeyBus.instance.requestToggle();
      },
    );
  }
}

class _VoiceWindowListener with WindowListener {
  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }
}

class _VoiceTrayListener with TrayListener {
  @override
  void onTrayIconMouseDown() {
    unawaited(() async {
      await windowManager.show();
      await windowManager.focus();
    }());
  }
}
