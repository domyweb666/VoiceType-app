import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/transcript_record.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  final HistoryService _service = HistoryService();

  List<TranscriptRecord> _records = [];
  bool _isLoading = false;
  String? _loadError;
  Future<void>? _loadInFlight;

  List<TranscriptRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  static String _deriveTitle(String organizedText, DateTime fallbackTime) {
    if (organizedText.isNotEmpty) {
      final clean = organizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isNotEmpty) {
        return clean.length > 20 ? clean.substring(0, 20) : clean;
      }
    }
    return '${fallbackTime.month}/${fallbackTime.day} '
        '${fallbackTime.hour}:${fallbackTime.minute.toString().padLeft(2, '0')}';
  }

  /// 從 Hive 載入歷史；並行呼叫會共用同一 Future，且發生錯誤時仍會結束 loading。
  Future<void> loadRecords() async {
    if (_loadInFlight != null) {
      await _loadInFlight!;
      return;
    }

    _loadInFlight = _loadRecordsInner();
    try {
      await _loadInFlight!;
    } finally {
      _loadInFlight = null;
    }
  }

  Future<void> _loadRecordsInner() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _records = await _service.getAll();
      _loadError = null;
    } catch (e, st) {
      if (_records.isEmpty) {
        final code = e is FileSystemException ? e.osError?.errorCode : null;
        if (code == 32 || code == 33) {
          _loadError =
              '歷史資料檔正被占用（常見：同時開兩個程式、或「文件」在 OneDrive 同步）。'
              '請只保留一個 VoiceType、關閉多餘視窗後按重試；並建議更新至最新版（歷史已改存本機 AppData，較不受雲端同步影響）。';
        } else {
          _loadError = '無法讀取本地歷史紀錄，請點重試或重啟應用程式。';
        }
      } else {
        _loadError = '無法重新載入，已保留目前清單。';
      }
      debugPrint('HistoryProvider.loadRecords failed: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TranscriptRecord> saveRecord({
    required String rawText,
    required String organizedText,
    required int durationSeconds,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final title = _deriveTitle(organizedText, now);

    final record = TranscriptRecord(
      id: id,
      title: title,
      rawText: rawText,
      organizedText: organizedText,
      createdAt: now,
      durationSeconds: durationSeconds,
    );

    await _service.save(record);
    _records.insert(0, record);
    notifyListeners();
    return record;
  }

  /// 覆寫既有筆記的文字稿（口語稿不變）。
  Future<void> updateOrganizedText({
    required String id,
    required String organizedText,
  }) async {
    final rec = await _service.getById(id);
    if (rec == null) return;
    final newTitle = organizedText.isNotEmpty
        ? _deriveTitle(organizedText, rec.createdAt)
        : rec.title;
    final updated = TranscriptRecord(
      id: rec.id,
      title: newTitle,
      rawText: rec.rawText,
      organizedText: organizedText,
      createdAt: rec.createdAt,
      durationSeconds: rec.durationSeconds,
    );
    await _service.save(updated);
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _records[idx] = updated;
    }
    notifyListeners();
  }

  /// 以相同口語稿另存新筆（新 id／建立時間）。
  Future<TranscriptRecord> savePolishedVariant({
    required TranscriptRecord source,
    required String organizedText,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final title = _deriveTitle(organizedText, now);
    final record = TranscriptRecord(
      id: id,
      title: title,
      rawText: source.rawText,
      organizedText: organizedText,
      createdAt: now,
      durationSeconds: source.durationSeconds,
    );
    await _service.save(record);
    _records.insert(0, record);
    notifyListeners();
    return record;
  }

  Future<void> deleteRecord(String id) async {
    await _service.delete(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
