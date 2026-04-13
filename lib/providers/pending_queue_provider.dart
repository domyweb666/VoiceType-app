import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/pending_session_service.dart';

/// 待轉錄 WAV 目錄列表（供 UI 顯示佇列與手動刪除）。
class PendingQueueProvider extends ChangeNotifier {
  List<File> _files = [];

  List<File> get files => List.unmodifiable(_files);

  Future<void> refresh() async {
    _files = await PendingSessionService.listPendingWavs();
    notifyListeners();
  }

  Future<void> deletePending(File f) async {
    await PendingSessionService.deletePendingFile(f);
    await refresh();
  }
}
