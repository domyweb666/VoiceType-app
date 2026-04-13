import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/user_disclosure.dart';
import '../providers/history_provider.dart';
import '../providers/pending_queue_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transcription_provider.dart';
import '../services/pending_session_service.dart';
import '../services/recording_hotkey_bus.dart';
import '../widgets/organized_view.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_waveform_bar.dart';
import '../widgets/transcript_view.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// 空白鍵切換錄音（首頁焦點時）。
class ToggleRecordingIntent extends Intent {
  const ToggleRecordingIntent();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _androidLaunchChannel = MethodChannel('com.voicetype/app');

  late TabController _tabController;
  bool _privacyDialogPostFrameScheduled = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<void>? _desktopRecordHotkeySub;
  bool _online = true;
  final FocusNode _homeShortcutFocus = FocusNode();
  late final SettingsProvider _settingsRef;
  late final VoidCallback _syncTranscriptionApiKey;

  static bool _isOnlineResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.any(
      (e) =>
          e == ConnectivityResult.mobile ||
          e == ConnectivityResult.wifi ||
          e == ConnectivityResult.ethernet ||
          e == ConnectivityResult.vpn ||
          e == ConnectivityResult.other,
    );
  }

  /// 僅桌面平台顯示空白鍵捷徑說明（手機／網頁不打擾）。
  static bool get _showDesktopSpaceHint {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    _settingsRef = context.read<SettingsProvider>();
    _syncTranscriptionApiKey = () {
      if (!mounted) return;
      context.read<TranscriptionProvider>().updateApiKey(_settingsRef.apiKey);
    };
    _settingsRef.addListener(_syncTranscriptionApiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTranscriptionApiKey();
    });
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      if (!mounted) return;
      setState(() => _online = _isOnlineResult(r));
    });
    Connectivity().checkConnectivity().then((r) {
      if (!mounted) return;
      setState(() => _online = _isOnlineResult(r));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PendingQueueProvider>().refresh();
      _consumeAndroidRecordIntent();
    });

    _desktopRecordHotkeySub =
        RecordingHotkeyBus.instance.requests.listen((_) {
      if (!mounted) return;
      _onSpaceShortcut();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumeAndroidRecordIntent();
    }
  }

  Future<void> _consumeAndroidRecordIntent() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final v = await _androidLaunchChannel
          .invokeMethod<bool>('consumeToggleRecordIntent');
      if (v != true || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onSpaceShortcut();
      });
    } catch (_) {}
  }

  void _schedulePrivacyDialogIfNeeded(SettingsProvider settings) {
    if (settings.isLoading ||
        settings.hasSeenPrivacyDisclosure ||
        _privacyDialogPostFrameScheduled) {
      return;
    }
    _privacyDialogPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _privacyDialogPostFrameScheduled = false;
      if (!mounted) return;
      final s = context.read<SettingsProvider>();
      if (s.isLoading || s.hasSeenPrivacyDisclosure) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            icon: Icon(
              Icons.info_outline_rounded,
              color: scheme.primary,
              size: 28,
            ),
            title: const Text(UserDisclosure.privacyAndCostTitle),
            content: SingleChildScrollView(
              child: Text(
                UserDisclosure.privacyAndCostBody,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  await context
                      .read<SettingsProvider>()
                      .markPrivacyDisclosureSeen();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _settingsRef.removeListener(_syncTranscriptionApiKey);
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _desktopRecordHotkeySub?.cancel();
    _homeShortcutFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSpaceShortcut() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final settings = context.read<SettingsProvider>();
    final transcription = context.read<TranscriptionProvider>();
    final recording = context.read<RecordingProvider>();
    if (!settings.hasApiKey) {
      _showSettingsPrompt();
      return;
    }
    if (!recording.isRecording &&
        (transcription.isTranscribing || transcription.isOrganizing)) {
      return;
    }
    _toggleRecording();
  }

  Future<void> _handleTranscriptionOutcome() async {
    if (!mounted) return;
    await context.read<PendingQueueProvider>().refresh();
    if (!mounted) return;
    _tabController.animateTo(0);

    final t = context.read<TranscriptionProvider>();
    if (!t.hasTranscript) {
      if (t.error == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有辨識到語音內容')),
        );
      }
      return;
    }
    if (t.error != null) {
      return;
    }

    await _polishAndSaveToHistory(
      doneMessage: '已完成轉錄、潤飾並儲存至歷史（口語稿與文字稿）',
    );
  }

  Future<void> _retryTranscribeFile(File wav) async {
    if (!_online) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('離線無法轉錄，請連上網路後再試。')),
        );
      }
      return;
    }
    final transcription = context.read<TranscriptionProvider>();
    if (transcription.isTranscribing) return;
    final settings = context.read<SettingsProvider>();
    await transcription.transcribeSessionWav(
      wav,
      whisperVocabularyHint: _whisperVocabularyHint(settings),
    );
    if (!mounted) return;
    await _handleTranscriptionOutcome();
  }

  Future<void> _pickAudioFromFiles() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.hasApiKey) {
      _showSettingsPrompt();
      return;
    }
    if (!_online) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('離線狀態無法轉錄，請連上網路後再試。')),
        );
      }
      return;
    }
    final transcription = context.read<TranscriptionProvider>();
    if (transcription.isTranscribing || transcription.isOrganizing) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請等待目前轉錄或潤飾完成')),
        );
      }
      return;
    }
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'm4a', 'WAV', 'M4A'],
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.single.path;
    if (path == null) return;
    final src = File(path);
    if (!mounted) return;
    final pending = await PendingSessionService.copyImportToPending(src);
    if (!mounted) return;
    await context.read<PendingQueueProvider>().refresh();
    await transcription.transcribeSessionWav(
      pending,
      whisperVocabularyHint: _whisperVocabularyHint(settings),
    );
    if (!mounted) return;
    await _handleTranscriptionOutcome();
  }

  Future<void> _retryLastTranscribeSession() async {
    if (!_online) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('離線無法轉錄，請連上網路後再試。')),
        );
      }
      return;
    }
    final t = context.read<TranscriptionProvider>();
    final path = t.lastTranscribeSessionPath;
    if (path == null) return;
    final f = File(path);
    if (!await f.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('錄音檔已不存在，請從下方待轉錄清單操作')),
      );
      await context.read<PendingQueueProvider>().refresh();
      return;
    }
    await _retryTranscribeFile(f);
  }

  Future<void> _toggleRecording() async {
    final settings = context.read<SettingsProvider>();
    final transcription = context.read<TranscriptionProvider>();
    final recording = context.read<RecordingProvider>();

    if (!settings.hasApiKey) {
      _showSettingsPrompt();
      return;
    }

    if (!recording.isRecording &&
        (transcription.isTranscribing || transcription.isOrganizing)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請等待轉錄或文字稿處理完成後再開新錄音')),
        );
      }
      return;
    }

    if (recording.isRecording) {
      final wav = await recording.stopRecording();
      if (wav != null && mounted) {
        File pending;
        try {
          pending = await PendingSessionService.copyFromTempToPending(wav);
        } finally {
          try {
            if (await wav.exists()) await wav.delete();
          } catch (_) {}
        }
        if (!mounted) return;
        await context.read<PendingQueueProvider>().refresh();
        if (!_online) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '離線無法轉錄。錄音已存入「待轉錄」，連上網路後請在清單點「轉錄」或「重試轉錄」。',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
        await transcription.transcribeSessionWav(
          pending,
          whisperVocabularyHint: _whisperVocabularyHint(settings),
        );
        if (!mounted) return;
        await _handleTranscriptionOutcome();
      }
    } else {
      if (Platform.isAndroid) {
        final st = await Permission.microphone.request();
        if (!st.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要麥克風權限才能錄音')),
            );
          }
          return;
        }
      }
      final hasPermission = await recording.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麥克風權限才能錄音')),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      transcription.clear();
      await recording.startRecording();
    }
  }

  void _showSettingsPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('請先至設定輸入 OpenAI API 金鑰'),
        action: SnackBarAction(
          label: '設定',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ),
    );
  }

  String? _whisperVocabularyHint(SettingsProvider settings) {
    final s = settings.buildWhisperVocabularyHintLine().trim();
    return s.isEmpty ? null : s;
  }

  /// 第二階段：潤飾並寫入歷史（自動流程與手動「再次潤飾」共用）。
  Future<void> _polishAndSaveToHistory({
    required String doneMessage,
    bool fullRoundTripCost = true,
  }) async {
    final transcription = context.read<TranscriptionProvider>();
    final settings = context.read<SettingsProvider>();
    final history = context.read<HistoryProvider>();
    final recording = context.read<RecordingProvider>();

    await transcription.organizeTranscript(
      systemPrompt: settings.buildOrganizeSystemPrompt(),
      fullRoundTripCost: fullRoundTripCost,
    );
    if (!mounted) return;
    if (transcription.error != null || transcription.organizedText.isEmpty) {
      return;
    }

    final saved = await history.saveRecord(
      rawText: transcription.rawTranscript,
      organizedText: transcription.organizedText,
      durationSeconds: recording.elapsed.inSeconds,
    );
    if (!mounted) return;
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(doneMessage),
        duration: const Duration(milliseconds: 2800),
        dismissDirection: DismissDirection.down,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '查看歷史',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryScreen(scrollToRecordId: saved.id),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _transcribeProgressLabel(TranscriptionProvider t) {
    if (!t.isTranscribing) return null;
    if (t.transcribePartTotal > 1) {
      return '轉錄第 ${t.transcribePartIndex}/${t.transcribePartTotal} 段（長錄音會分段上傳）';
    }
    return '正在將錄音轉成口語稿…';
  }

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final transcription = context.watch<TranscriptionProvider>();
    final settings = context.watch<SettingsProvider>();
    final pendingQueue = context.watch<PendingQueueProvider>();

    _schedulePrivacyDialogIfNeeded(settings);

    final recordEnabled = recording.isRecording ||
        (!transcription.isTranscribing && !transcription.isOrganizing);

    final estWavMb = (recording.estimatedRecordingPcmBytes + 44) / (1024 * 1024);

    return Focus(
      focusNode: _homeShortcutFocus,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ToggleRecordingIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ToggleRecordingIntent: CallbackAction<ToggleRecordingIntent>(
              onInvoke: (_) {
                _onSpaceShortcut();
                return null;
              },
            ),
          },
          child: Scaffold(
      appBar: AppBar(
        title: const Text('VoiceType'),
        actions: [
          IconButton(
            icon: const Icon(Icons.audio_file_outlined),
            tooltip: '從檔案轉錄（WAV／M4A）',
            onPressed: (!transcription.isTranscribing &&
                    !transcription.isOrganizing)
                ? _pickAudioFromFiles
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '歷史紀錄',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '口語稿'),
            Tab(text: '文字稿'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_online)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '目前為離線或無可用連線，轉錄需要網路。連上後可使用「轉錄」或「重試轉錄」。',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color:
                              Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (transcription.isTranscribing || transcription.isOrganizing)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          transcription.isTranscribing
                              ? Icons.transcribe_outlined
                              : Icons.auto_fix_high_outlined,
                          size: 22,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            transcription.isTranscribing
                                ? '步驟 1/2：轉錄口語稿'
                                : '步驟 2/2：潤飾文字稿',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    if (transcription.isTranscribing &&
                        transcription.transcribePartTotal > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '長錄音會分段上傳（第 ${transcription.transcribePartIndex}／${transcription.transcribePartTotal} 段），請稍候。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                TranscriptView(
                  segments: transcription.segments,
                  isTranscribing: transcription.isTranscribing,
                  isRecording: recording.isRecording,
                  transcribeProgressLabel: _transcribeProgressLabel(transcription),
                ),
                OrganizedView(
                  text: transcription.organizedText,
                  textVersion: transcription.organizedTextVersion,
                  isOrganizing: transcription.isOrganizing,
                  organizingMessage: '產生文字稿中…',
                  organizingDetail: transcription.isOrganizing
                      ? '步驟 2/2：完成後會自動寫入歷史'
                      : null,
                  emptyMessage:
                      '錄音結束後會自動轉成口語稿、再自動潤飾並存進歷史。也可按下方 ✨ 對既有口語稿再潤飾並儲存一筆。',
                  onTextChanged: transcription.setOrganizedTextUser,
                ),
              ],
            ),
          ),

          if (transcription.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (transcription.hasPartialTranscribeResume)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '重試轉錄將從失敗段繼續，已成功轉出的口語稿段落會保留。',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  SelectableText(
                    transcription.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                  if (transcription.errorClipboardText != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: transcription.errorClipboardText!,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已複製錯誤說明'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('複製錯誤詳情'),
                      ),
                    ),
                  if (transcription.error!.contains('金鑰'))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('前往設定'),
                      ),
                    ),
                  if (transcription.lastTranscribeSessionPath != null &&
                      !transcription.isTranscribing)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _retryLastTranscribeSession,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重試轉錄'),
                      ),
                    ),
                ],
              ),
            ),

          if (pendingQueue.files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pending_actions_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '待轉錄（${pendingQueue.files.length}）',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      if (!_online)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            '離線中：連上網路後再按「轉錄」。',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      ...pendingQueue.files.asMap().entries.expand((entry) {
                        final i = entry.key;
                        final f = entry.value;
                        final name = f.uri.pathSegments.isNotEmpty
                            ? f.uri.pathSegments.last
                            : f.path;
                        return [
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.audio_file_outlined,
                              size: 22,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed:
                                      transcription.isTranscribing || !_online
                                          ? null
                                          : () => _retryTranscribeFile(f),
                                  child: const Text('轉錄'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 22),
                                  tooltip: '刪除此待轉錄檔',
                                  onPressed: transcription.isTranscribing
                                      ? null
                                      : () async {
                                          await context
                                              .read<PendingQueueProvider>()
                                              .deletePending(f);
                                        },
                                ),
                              ],
                            ),
                          ),
                        ];
                      }),
                    ],
                  ),
                ),
              ),
            ),

        ], // End of Column children
      ), // End of Scaffold body Column
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.55),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recording.isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.error,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withValues(alpha: 0.55),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              recording.elapsedFormatted,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: RecordingWaveformBar(
                                  samples: recording.waveformSamples,
                                  height: 56,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '即時音量波形 · 確認麥克風有收到聲音',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        if (recording.estimatedRecordingPcmBytes > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '暫存約 ${estWavMb.toStringAsFixed(1)} MB（停止後寫成 WAV）',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (_showDesktopSpaceHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '桌面版：空白鍵（首頁焦點）或 Ctrl+Alt+V 全域切換錄音；關閉視窗可收到系統匣',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: transcription.hasTranscript &&
                              !transcription.isTranscribing &&
                              !transcription.isOrganizing &&
                              !recording.isRecording
                          ? () => transcription.clear()
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: '清除本筆',
                    ),
                    const SizedBox(width: 12),

                    RecordButton(
                      isRecording: recording.isRecording,
                      enabled: recordEnabled,
                      onTap: _toggleRecording,
                    ),
                    const SizedBox(width: 12),

                    IconButton.filledTonal(
                      onPressed: transcription.hasTranscript &&
                              !transcription.isOrganizing &&
                              !recording.isRecording &&
                              !transcription.isTranscribing
                          ? () => _polishAndSaveToHistory(
                                doneMessage: '已再次潤飾並儲存至歷史',
                                fullRoundTripCost: false,
                              )
                          : null,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      tooltip: '再次潤飾並儲存至歷史',
                    ),
                  ],
                ),

                if (transcription.hasTranscript ||
                    transcription.organizedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (transcription.hasTranscript)
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                    text: transcription.rawTranscript),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已複製口語稿'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('複製口語稿'),
                          ),
                        if (transcription.organizedText.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                    text: transcription.organizedText),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已複製文字稿'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(Icons.article_outlined,
                                size: 18),
                            label: const Text('複製文字稿'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ), // End of Scaffold
        ), // End of Actions
      ), // End of Shortcuts
    ); // End of Focus
  }
}
