import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/transcript_record.dart';
import 'hive_encryption_service.dart';

class HistoryService {
  /// 與 [main.dart] 註冊的 adapter 一致；勿隨意改名以免舊檔路徑不一致。
  static const String hiveBoxName = 'transcripts';

  static bool _isFileLockOrAccessIssue(Object e) {
    if (e is FileSystemException) {
      final c = e.osError?.errorCode;
      if (c == 32 || c == 33) return true; // Windows: 使用中／已鎖定
      final m = '${e.message}${e.osError?.message}'.toLowerCase();
      if (m.contains('being used') ||
          m.contains('locked') ||
          m.contains('another program') ||
          m.contains('鎖定') ||
          m.contains('另一個程序')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _closeIfOpen() async {
    if (!Hive.isBoxOpen(hiveBoxName)) return;
    try {
      await Hive.box(hiveBoxName).close();
    } catch (_) {}
  }

  /// 開啟 box；若檔案損毀導致無法開啟，會刪除磁碟上的 box 後再建空盒（歷史筆數歸零）。
  Future<Box<TranscriptRecord>> _getBox() async {
    if (Hive.isBoxOpen(hiveBoxName)) {
      return Hive.box<TranscriptRecord>(hiveBoxName);
    }
    try {
      // 加密開啟：與遷移後的加密盒一致（金鑰取自 secure storage）。
      return await Hive.openBox<TranscriptRecord>(
        hiveBoxName,
        encryptionCipher: await HiveEncryptionService.cipher(),
      );
    } catch (e, st) {
      debugPrint('Hive.openBox($hiveBoxName) failed: $e\n$st');
      // 檔案被同步軟體／第二個程序占用時，刪除只會再失敗並留下未處理的 async 錯誤。
      if (_isFileLockOrAccessIssue(e)) {
        rethrow;
      }
      await _closeIfOpen();
      try {
        await Hive.deleteBoxFromDisk(hiveBoxName);
      } catch (e2) {
        debugPrint('Hive.deleteBoxFromDisk failed: $e2');
      }
      try {
        // 重建的空盒也用加密開啟，維持磁碟格式一致。
        return await Hive.openBox<TranscriptRecord>(
          hiveBoxName,
          encryptionCipher: await HiveEncryptionService.cipher(),
        );
      } catch (e3, st3) {
        debugPrint('Hive.openBox retry failed: $e3\n$st3');
        rethrow;
      }
    }
  }

  Future<void> save(TranscriptRecord record) async {
    final box = await _getBox();
    await box.put(record.id, record);
  }

  /// 逐筆讀取，略過無法反序列化的 key（並從 box 刪除），避免整盒報廢。
  Future<List<TranscriptRecord>> getAll() async {
    final box = await _getBox();
    final records = <TranscriptRecord>[];
    final keys = box.keys.toList();
    for (final key in keys) {
      try {
        final v = box.get(key);
        if (v != null) records.add(v);
      } catch (e, st) {
        debugPrint('Hive transcripts skip corrupt key=$key: $e\n$st');
        try {
          await box.delete(key);
        } catch (_) {}
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<TranscriptRecord?> getById(String id) async {
    final box = await _getBox();
    try {
      return box.get(id);
    } catch (e, st) {
      debugPrint('Hive getById failed id=$id: $e\n$st');
      try {
        await box.delete(id);
      } catch (_) {}
      return null;
    }
  }

  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  Future<void> deleteAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
