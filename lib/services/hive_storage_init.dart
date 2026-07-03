import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/transcript_record.dart';
import 'history_service.dart';
import 'hive_encryption_service.dart';

/// 回傳 Hive 資料夾路徑（[getApplicationSupportDirectory]/hive），供初始化與遷移共用。
Future<String> _resolveHiveDir() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'hive');
}

/// 將 Hive 放在 [getApplicationSupportDirectory] 底下（本機 AppData），
/// 避免 `Hive.initFlutter()` 預設使用「文件」資料夾時落在 OneDrive 而與同步鎖檔衝突。
Future<void> initVoiceTypeHive() async {
  final hiveDir = Directory(await _resolveHiveDir());
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

/// 遷移完成的「sidecar 標記檔」名稱（置於 Hive 資料夾內，與資料同目錄）。
///
/// 刻意不把標記放 secure storage：一旦 secure storage 標記遺失（重裝、Credential
/// Manager 被清）但加密後的 `.hive` 還在，重跑遷移會拿「無加密」去開加密檔，而 Hive
/// 預設 `crashRecovery` 會把讀不懂的密文當損毀截斷、回傳 0 筆，接著把 0 筆寫回、
/// 驗證 0==0 通過、刪掉真資料——整包歷史歸零。標記與資料同放一個目錄即可同生共滅，
/// 從源頭杜絕這條路徑。
const String _encMigratedMarkerFile = 'transcripts.encrypted';

/// 空 Hive box 檔頭很小；明文開啟得 0 筆卻超過此體積，極可能是「拿明文開加密檔被
/// crashRecovery 截斷」的假象，屬危險訊號，絕不可據此刪檔重建。
const int _emptyBoxByteCeiling = 256;

/// 把既有的明文 transcripts box 一次性遷移成加密盒。
///
/// 資料安全是第一優先，全程採防禦式設計：
/// - 標記檔與資料同目錄（見 [_encMigratedMarkerFile]），標記與資料不會脫鉤；
/// - 先「無加密」開盒確認真的是明文、且通過「0 筆但檔案很大」防線，才動手刪檔；
/// - 先備份明文檔（`.plain.bak`）再刪，任何一步崩潰都能從備份回復；
/// - 只有在確認加密盒筆數 == 原明文筆數後，才寫下標記檔；
/// - 遇到任何非預期例外一律「不寫標記、不刪資料」，寧可維持明文也不遺失歷史。
///
/// 必須在 `Hive.registerAdapter(TranscriptRecordAdapter())` 之後呼叫，
/// 因為過程會反序列化 [TranscriptRecord]。
Future<void> migratePlaintextTranscriptsIfNeeded() async {
  final box = HistoryService.hiveBoxName;

  final String hiveDir;
  try {
    hiveDir = await _resolveHiveDir();
  } catch (e, st) {
    debugPrint('解析 Hive 目錄失敗，略過加密遷移（維持現狀不動資料）: $e\n$st');
    return;
  }

  final plainFile = File(p.join(hiveDir, '$box.hive'));
  final bakFile = File(p.join(hiveDir, '$box.plain.bak'));
  final doneMarker = File(p.join(hiveDir, _encMigratedMarkerFile));

  // 已遷移過：標記檔存在即結束（標記與資料同目錄，不會脫鉤）。
  if (await doneMarker.exists()) return;

  try {
    final plainExists = await plainFile.exists();
    final bakExists = await bakFile.exists();

    // 全新安裝：明文檔與備份都不存在，沒有東西要搬。
    // 直接寫標記，之後 HistoryService 會以加密盒開啟全新資料。
    if (!plainExists && !bakExists) {
      await doneMarker.create();
      return;
    }

    // 復原：明文檔不見了但備份還在，代表上次遷移中途崩潰（已刪明文、尚未寫標記）。
    // 先從備份還原明文檔，再照正常流程重跑。
    if (!plainExists && bakExists) {
      debugPrint('偵測到上次遷移中斷，正從備份還原明文檔: ${bakFile.path}');
      await bakFile.copy(plainFile.path);
    }

    // 先「無加密」開盒，確認它真的是明文。若其實已是加密檔，openBox 會拋錯（→ 下方
    // _looksLikeAlreadyEncrypted 補標記），或被 crashRecovery 讀成 0 筆（→ 下方體積防線）。
    final plainLenBefore = await plainFile.length();
    final Box<TranscriptRecord> plainBox;
    try {
      plainBox = await Hive.openBox<TranscriptRecord>(box);
    } catch (e) {
      if (_looksLikeAlreadyEncrypted(e)) {
        debugPrint('明文開啟失敗，判定盒已為加密狀態，補寫標記檔: $e');
        await doneMarker.create();
        return;
      }
      rethrow; // 交給外層 fail-safe（不刪資料、不寫標記）
    }

    final saved = Map<dynamic, TranscriptRecord>.from(plainBox.toMap());
    final savedCount = saved.length;
    await plainBox.close();

    // 危險訊號防線：檔案有相當體積卻讀成 0 筆，極可能是拿明文開加密檔的假象。
    // 此時絕不刪檔重建（會歸零），視為已加密、補標記後結束。
    if (savedCount == 0 && plainLenBefore > _emptyBoxByteCeiling) {
      debugPrint(
        '明文開啟得 0 筆但檔案 $plainLenBefore bytes，疑似已加密，不動資料、補標記結束。',
      );
      await doneMarker.create();
      return;
    }

    // 確認是明文且已讀出 → 備份（安全網），再刪明文檔以同名重建加密盒。
    await plainFile.copy(bakFile.path);
    if (await plainFile.exists()) {
      await plainFile.delete();
    }
    final lockFile = File(p.join(hiveDir, '$box.lock'));
    if (await lockFile.exists()) {
      try {
        await lockFile.delete();
      } catch (_) {}
    }

    // 以加密開啟同名盒，寫回全部資料。
    final encBox = await Hive.openBox<TranscriptRecord>(
      box,
      encryptionCipher: await HiveEncryptionService.cipher(),
    );
    await encBox.putAll(saved);

    // 驗證：加密盒筆數需與原明文一致，否則保留備份、不寫標記，等待手動復原。
    if (encBox.length != savedCount) {
      throw StateError(
        '遷移筆數不一致（明文 $savedCount vs 加密 ${encBox.length}），已保留備份: ${bakFile.path}',
      );
    }

    // 成功：寫下標記檔。明文備份先不刪，留作使用者的安全網（確認無誤後可自行刪除）。
    await doneMarker.create();
    debugPrint('transcripts 已成功加密（$savedCount 筆）；明文備份保留於: ${bakFile.path}');
    // 刻意讓 encBox 保持開啟：後續 HistoryService._getBox 會直接取用同一個已開啟的加密盒。
  } catch (e, st) {
    // 特例：過程中判定盒已是加密狀態（上次已寫完但標記漏設）→ 補標記即可。
    if (_looksLikeAlreadyEncrypted(e)) {
      debugPrint('遷移過程判定盒已為加密狀態，補寫標記檔: $e');
      try {
        await doneMarker.create();
      } catch (_) {}
      return;
    }
    // 其餘任何非預期例外：不寫標記、不刪資料（fail safe），寧可維持明文也不遺失歷史。
    debugPrint('transcripts 加密遷移失敗，維持現狀不動資料: $e\n$st');
  }
}

/// 粗略判斷例外是否來自「盒已加密卻用明文開啟」造成的損毀誤判。
bool _looksLikeAlreadyEncrypted(Object e) {
  final m = e.toString().toLowerCase();
  return m.contains('corrupt') ||
      m.contains('unknown typeid') ||
      m.contains('cipher') ||
      m.contains('encrypt') ||
      m.contains('checksum');
}
