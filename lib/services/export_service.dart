import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transcript_record.dart';

/// 單筆／批次匯出 .txt、.md 或 ZIP，並可呼叫系統分享。
class ExportService {
  ExportService._();

  static Future<File> _writeTemp(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(content, encoding: utf8);
    return f;
  }

  static String _safeFileStem(String title) {
    var s = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (s.isEmpty) s = 'voicetype_export';
    if (s.length > 40) s = s.substring(0, 40);
    return s;
  }

  static Future<void> shareRecordAsTxt({
    required TranscriptRecord record,
    required bool organizedOnly,
  }) async {
    final stem = _safeFileStem(record.title);
    final body = organizedOnly
        ? record.organizedText
        : (record.organizedText.isNotEmpty
            ? record.organizedText
            : record.rawText);
    final name = organizedOnly ? '${stem}_文字稿.txt' : '$stem.txt';
    final f = await _writeTemp(name, body);
    await Share.shareXFiles([XFile(f.path)], text: record.title);
  }

  static Future<void> shareRecordRawTxt(TranscriptRecord record) async {
    final stem = _safeFileStem(record.title);
    final f = await _writeTemp('${stem}_口語稿.txt', record.rawText);
    await Share.shareXFiles([XFile(f.path)], text: '${record.title}（口語稿）');
  }

  static Future<void> shareRecordMarkdown(TranscriptRecord record) async {
    final stem = _safeFileStem(record.title);
    final buf = StringBuffer();
    buf.writeln('# ${record.title}');
    buf.writeln();
    buf.writeln('## 文字稿（潤飾後）');
    buf.writeln();
    buf.writeln(record.organizedText.isEmpty ? '（無）' : record.organizedText);
    buf.writeln();
    buf.writeln('## 口語稿（轉錄）');
    buf.writeln();
    buf.writeln(record.rawText);
    final f = await _writeTemp('$stem.md', buf.toString());
    await Share.shareXFiles([XFile(f.path)], text: record.title);
  }

  static Future<void> shareRecordsZip({
    required List<TranscriptRecord> records,
  }) async {
    if (records.isEmpty) return;
    final archive = Archive();
    for (final r in records) {
      final stem = _safeFileStem(r.title);
      final md = StringBuffer()
        ..writeln('# ${r.title}')
        ..writeln()
        ..writeln('## 文字稿')
        ..writeln()
        ..writeln(r.organizedText.isEmpty ? '（無）' : r.organizedText)
        ..writeln()
        ..writeln('## 口語稿')
        ..writeln()
        ..writeln(r.rawText);
      final name = '${stem}_${r.id}.md';
      final bytes = utf8.encode(md.toString());
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) return;
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/voicetype_export_${DateTime.now().millisecondsSinceEpoch}.zip',
    );
    await out.writeAsBytes(zipBytes);
    await Share.shareXFiles([XFile(out.path)], text: 'VoiceType 批次匯出');
  }
}
