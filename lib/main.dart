import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'desktop/desktop_integration.dart';
import 'models/transcript_record.dart';
import 'providers/history_provider.dart';
import 'services/hive_storage_init.dart';
import 'services/recording_notification_service.dart';
import 'providers/pending_queue_provider.dart';
import 'providers/recording_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transcription_provider.dart';

/// 供系統匣／深層連結等導覽使用。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 放在 ApplicationSupport（本機），勿用 initFlutter 預設「文件」路徑（易落在 OneDrive 而鎖檔）。
  await initVoiceTypeHive();
  Hive.registerAdapter(TranscriptRecordAdapter());

  // 一次性把明文 transcripts 盒遷移成加密盒；防禦式設計，失敗時維持明文不遺失資料。
  // 必須在 registerAdapter 之後（遷移會反序列化 TranscriptRecord）、runApp 之前執行。
  await migratePlaintextTranscriptsIfNeeded();

  if (Platform.isWindows) {
    await DesktopIntegration.initIfWindows();
  }

  if (Platform.isAndroid || Platform.isIOS) {
    await RecordingNotificationService.instance.initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => RecordingProvider()),
        ChangeNotifierProvider(create: (_) => TranscriptionProvider()),
        ChangeNotifierProvider(create: (_) => PendingQueueProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: VoiceTypeApp(navigatorKey: rootNavigatorKey),
    ),
  );
}
