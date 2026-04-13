import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/constants.dart';

/// 停錄後將 WAV 複製到固定目錄，失敗時可對同一路徑重試轉錄。
class PendingSessionService {
  PendingSessionService._();

  static Future<Directory> getPendingDirectory() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${doc.path}/${AppConstants.pendingTranscriptionRelativeDir}',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 將暫存錄音檔複製到待轉錄目錄，回傳新路徑的 [File]。
  static Future<File> copyFromTempToPending(File tempWav) async {
    final dir = await getPendingDirectory();
    final name = 'session_${DateTime.now().millisecondsSinceEpoch}.wav';
    final target = File('${dir.path}/$name');
    await tempWav.copy(target.path);
    return target;
  }

  /// 從任意路徑複製到待轉錄目錄（本機匯入 WAV／M4A）。
  static Future<File> copyImportToPending(File source) async {
    final dir = await getPendingDirectory();
    final ext = p.extension(source.path).toLowerCase();
    final tail = (ext == '.m4a' || ext == '.wav') ? ext : '.audio';
    final name = 'import_${DateTime.now().millisecondsSinceEpoch}$tail';
    final target = File('${dir.path}/$name');
    await source.copy(target.path);
    return target;
  }

  static Future<List<File>> listPendingWavs() async {
    final dir = await getPendingDirectory();
    if (!await dir.exists()) return [];
    final out = <File>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.wav') && !lower.endsWith('.m4a')) continue;
      out.add(entity);
    }
    out.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return out;
  }

  static Future<void> deletePendingFile(File f) async {
    if (await f.exists()) {
      await f.delete();
    }
  }
}
