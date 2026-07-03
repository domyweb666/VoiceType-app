import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../services/recording_hotkey_bus.dart';

/// Windows：全域快捷鍵、系統匣（關閉視窗直接結束，不收到匣）。
class DesktopIntegration {
  DesktopIntegration._();

  static bool get isSupported => Platform.isWindows || Platform.isMacOS;

  static Future<void> initIfWindows() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();

    const opts = WindowOptions(
      size: Size(920, 740),
      minimumSize: Size(600, 500),
      center: true,
      backgroundColor: Color(0xFF0B0F10),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });

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

    final menu = Menu(
      items: [
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
