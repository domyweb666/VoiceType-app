import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'history_service.dart';

/// 將 Hive 放在 [getApplicationSupportDirectory] 底下（本機 AppData），
/// 避免 `Hive.initFlutter()` 預設使用「文件」資料夾時落在 OneDrive 而與同步鎖檔衝突。
Future<void> initVoiceTypeHive() async {
  final support = await getApplicationSupportDirectory();
  final hiveDir = Directory(p.join(support.path, 'hive'));
  await hiveDir.create(recursive: true);
  Hive.init(hiveDir.path);

  await _migrateTranscriptsFromDocumentsIfNeeded(hiveDir.path);
}

/// 若新位置尚無 transcripts，且「文件」資料夾裡有舊檔，則複製 `.hive`（不複製 `.lock`）。
Future<void> _migrateTranscriptsFromDocumentsIfNeeded(String newHiveDir) async {
  final box = HistoryService.hiveBoxName;
  final newHive = File(p.join(newHiveDir, '$box.hive'));
  if (await newHive.exists()) return;

  try {
    final docs = await getApplicationDocumentsDirectory();
    final oldHive = File(p.join(docs.path, '$box.hive'));
    if (!await oldHive.exists()) return;

    debugPrint('Hive: 正在從「文件」資料夾遷移 $box.hive 至 App 支援目錄（避開 OneDrive 鎖檔）…');
    await oldHive.copy(newHive.path);
  } catch (e, st) {
    debugPrint('Hive 遷移略過（可為 OneDrive 鎖定或無舊檔）: $e\n$st');
  }
}
