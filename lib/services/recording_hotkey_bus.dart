import 'dart:async';

/// Windows 系統匣／全域快捷鍵與首頁錄音邏輯的橋接（避免直接依賴 BuildContext）。
class RecordingHotkeyBus {
  RecordingHotkeyBus._();
  static final RecordingHotkeyBus instance = RecordingHotkeyBus._();

  final StreamController<void> _ctrl = StreamController<void>.broadcast();

  Stream<void> get requests => _ctrl.stream;

  void requestToggle() {
    if (!_ctrl.isClosed) _ctrl.add(null);
  }
}
