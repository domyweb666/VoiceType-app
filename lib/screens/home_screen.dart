import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart' show windowManager, DragToMoveArea;
import '../config/app_theme.dart';
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
import '../widgets/record_hud_pill.dart';
import '../widgets/transcript_view.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// 空白鍵切換錄音（首頁焦點時）。
class ToggleRecordingIntent extends Intent {
  const ToggleRecordingIntent();
}

/// HomeScreen view modes（在同一個 Scaffold 裡切換，不再 push routes）。
enum _NavView { home, history, settings }

const double _kMobileBreakpoint = 980;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  static const _androidLaunchChannel = MethodChannel('com.voicetype/app');

  bool _privacyDialogPostFrameScheduled = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<void>? _desktopRecordHotkeySub;
  bool _online = true;
  final FocusNode _homeShortcutFocus = FocusNode();
  late final SettingsProvider _settingsRef;
  late final VoidCallback _syncTranscriptionApiKey;

  _NavView _view = _NavView.home;
  // Mobile: 0 = raw 口語, 1 = polished 文字 (預設文字稿)。
  int _mobileTranscriptTab = 1;

  bool _autoResumeFired = false;
  bool _autoResumeSettingsListenerAttached = false;

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
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      if (!mounted) return;
      final wasOffline = !_online;
      setState(() => _online = _isOnlineResult(r));
      if (wasOffline && _online) {
        _autoResumeFired = false;
        unawaited(_autoResumePendingIfPossible());
      }
    });
    Connectivity().checkConnectivity().then((r) {
      if (!mounted) return;
      setState(() => _online = _isOnlineResult(r));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<PendingQueueProvider>().refresh();
      if (!mounted) return;
      _consumeAndroidRecordIntent();
      _attachAutoResumeSettingsListener();
      unawaited(_autoResumePendingIfPossible());
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
      _autoResumeFired = false;
      unawaited(() async {
        if (!mounted) return;
        await context.read<PendingQueueProvider>().refresh();
        if (!mounted) return;
        await _autoResumePendingIfPossible();
      }());
    }
  }

  void _attachAutoResumeSettingsListener() {
    if (_autoResumeSettingsListenerAttached) return;
    _autoResumeSettingsListenerAttached = true;
    _settingsRef.addListener(_onSettingsChangedForAutoResume);
  }

  void _onSettingsChangedForAutoResume() {
    if (!mounted) return;
    if (!_settingsRef.hasApiKey) return;
    if (!_settingsRef.hasSeenPrivacyDisclosure) return;
    if (_autoResumeFired) return;
    unawaited(_autoResumePendingIfPossible());
  }

  Future<void> _autoResumePendingIfPossible() async {
    if (!mounted || _autoResumeFired) return;

    final settings = context.read<SettingsProvider>();
    final transcription = context.read<TranscriptionProvider>();
    final recording = context.read<RecordingProvider>();
    final pending = context.read<PendingQueueProvider>();

    if (settings.isLoading) return;
    if (!settings.hasSeenPrivacyDisclosure) return;
    if (!settings.hasApiKey) return;
    if (!_online) return;
    if (recording.isRecording) return;
    if (transcription.isTranscribing || transcription.isOrganizing) return;
    if (pending.files.isEmpty) return;

    _autoResumeFired = true;

    final fileCount = pending.files.length;
    final target = pending.files.last; // 最舊（時間戳最小）

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            fileCount == 1
                ? '找到 1 個未完成錄音，自動續轉中…'
                : '找到 $fileCount 個未完成錄音，依序自動續轉中…',
          ),
        ),
      );
    }

    await _retryTranscribeFile(target);

    if (!mounted) return;
    await context.read<PendingQueueProvider>().refresh();
    if (!mounted) return;
    if (context.read<PendingQueueProvider>().files.isNotEmpty) {
      _autoResumeFired = false;
      unawaited(_autoResumePendingIfPossible());
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
          final t = dialogContext.tokens;
          return AlertDialog(
            icon: Icon(Icons.info_outline_rounded, color: t.accent, size: 28),
            title: const Text(UserDisclosure.privacyAndCostTitle),
            content: SingleChildScrollView(
              child: Text(
                UserDisclosure.privacyAndCostBody,
                style: TextStyle(height: 1.5, color: t.fgDim, fontSize: 13.5),
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
    if (_autoResumeSettingsListenerAttached) {
      _settingsRef.removeListener(_onSettingsChangedForAutoResume);
    }
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _desktopRecordHotkeySub?.cancel();
    _homeShortcutFocus.dispose();
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

    final t = context.read<TranscriptionProvider>();
    if (!t.hasTranscript) {
      if (t.error == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有辨識到語音內容')),
        );
      }
      return;
    }
    if (t.error != null) return;

    await _polishAndSaveToHistory(
      doneMessage: '已完成轉錄、潤飾並儲存至歷史',
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

    if (_view != _NavView.home) {
      setState(() => _view = _NavView.home);
    }

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
                content: Text('離線無法轉錄。錄音已存入「待轉錄」，連上網路後請點「轉錄」。'),
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
          onPressed: () => setState(() => _view = _NavView.settings),
        ),
      ),
    );
  }

  String? _whisperVocabularyHint(SettingsProvider settings) {
    final s = settings.buildWhisperVocabularyHintLine().trim();
    return s.isEmpty ? null : s;
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(doneMessage),
        duration: const Duration(milliseconds: 2800),
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


  // ────────────────────────── BUILD ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    _schedulePrivacyDialogIfNeeded(settings);

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < _kMobileBreakpoint;
              final t = context.tokens;
              return Scaffold(
                backgroundColor: t.bg,
                body: Column(
                  children: [
                    if (Platform.isWindows)
                      _WinTitleBar(bg: t.bg, iconColor: t.fgDim),
                    Expanded(
                      child: isMobile ? _buildMobile() : _buildDesktop(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Desktop: 三欄 sidebar + main + (optional) rail ───
  Widget _buildDesktop() {
    final t = context.tokens;
    final showRail = _view == _NavView.home || _view == _NavView.history;

    return Row(
      children: [
        SizedBox(width: 260, child: _Sidebar(view: _view, onSelect: (v) => setState(() => _view = v))),
        Container(width: 1, color: t.line),
        Expanded(child: _buildMainStage(isMobile: false)),
        if (showRail) ...[
          Container(width: 1, color: t.line),
          SizedBox(width: 360, child: _RightRail(view: _view)),
        ],
      ],
    );
  }

  // ─── Mobile: 單欄 + Stack 浮動 mic ───
  Widget _buildMobile() => _buildMainStage(isMobile: true);

  Widget _buildMainStage({required bool isMobile}) {
    switch (_view) {
      case _NavView.home:
        return _HomeStage(
          isMobile: isMobile,
          online: _online,
          mobileTranscriptTab: _mobileTranscriptTab,
          onMobileTranscriptTabChange: (i) =>
              setState(() => _mobileTranscriptTab = i),
          showDesktopSpaceHint: _showDesktopSpaceHint,
          onPickFile: _pickAudioFromFiles,
          onToggleRecord: _toggleRecording,
          onRetryFile: _retryTranscribeFile,
          onRetryLast: _retryLastTranscribeSession,
          onGoToSettings: () => setState(() => _view = _NavView.settings),
          onGoToHistory: () => setState(() => _view = _NavView.history),
        );
      case _NavView.history:
        return HistoryScreen(
          embedded: true,
          onBack: () => setState(() => _view = _NavView.home),
        );
      case _NavView.settings:
        return SettingsScreen(
          embedded: true,
          onBack: () => setState(() => _view = _NavView.home),
        );
    }
  }
}

// ─────────────────── SIDEBAR (desktop) ───────────────────

class _Sidebar extends StatelessWidget {
  final _NavView view;
  final ValueChanged<_NavView> onSelect;

  const _Sidebar({required this.view, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // brand
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: t.accentGlow, blurRadius: 16, spreadRadius: -8),
                    ],
                  ),
                  child: Text(
                    'V',
                    style: mono(size: 14, color: t.accentInk, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'VoiceType',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'β',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: t.fgMute,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _NavSectionTitle('工作區'),
          _NavItem(
            icon: Icons.home_outlined,
            label: '錄音',
            kbd: 'Space',
            active: view == _NavView.home,
            onTap: () => onSelect(_NavView.home),
          ),
          _NavSectionTitle('資料'),
          _NavItem(
            icon: Icons.history_rounded,
            label: '歷史紀錄',
            kbd: '⌘H',
            active: view == _NavView.history,
            onTap: () => onSelect(_NavView.history),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: '設定',
            kbd: '⌘,',
            active: view == _NavView.settings,
            onTap: () => onSelect(_NavView.settings),
          ),
          const Spacer(),
          // status card
          Consumer<HistoryProvider>(
            builder: (context, history, _) {
              final mCount = history.records.length;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.bgChip,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: t.ok,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: t.ok.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '共 $mCount 筆',
                          style: TextStyle(fontSize: 12, color: t.fgDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '本地儲存 · OpenAI 雲端轉錄',
                      style: mono(size: 10.5, color: t.fgMute),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavSectionTitle extends StatelessWidget {
  final String label;
  const _NavSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.5,
          color: t.fgMute,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? kbd;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.kbd,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? t.bgChip : Colors.transparent,
              border: Border.all(
                color: active ? t.lineStrong : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? t.accent : t.fgDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: active ? t.fg : t.fgDim,
                    ),
                  ),
                ),
                if (kbd != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.bgChip,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kbd!,
                      style: mono(size: 10.5, color: t.fgMute),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── RIGHT RAIL (desktop) ───────────────────

class _RightRail extends StatelessWidget {
  final _NavView view;
  const _RightRail({required this.view});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.bg,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RailTitle(view == _NavView.history ? '本月概況' : '最近'),
            const SizedBox(height: 10),
            if (view == _NavView.home)
              Consumer<HistoryProvider>(
                builder: (context, history, _) {
                  final recent = history.records.take(5).toList();
                  if (recent.isEmpty) {
                    return Text(
                      '還沒有任何錄音紀錄。',
                      style: TextStyle(fontSize: 12.5, color: t.fgMute, height: 1.6),
                    );
                  }
                  return Column(
                    children: recent.map((r) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: t.line),
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: t.fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.createdAt.year}/${r.createdAt.month}/${r.createdAt.day} · ${r.durationSeconds}s',
                              style: mono(size: 11.5, color: t.fgMute),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              )
            else
              Consumer<HistoryProvider>(
                builder: (context, history, _) {
                  final n = history.records.length;
                  final totalSec = history.records.fold<int>(
                    0,
                    (s, r) => s + r.durationSeconds,
                  );
                  final mins = (totalSec / 60).round();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StreakRow(label: '總筆數', value: '$n'),
                      _StreakRow(label: '總時長', value: '$mins min'),
                      const SizedBox(height: 12),
                      Text(
                        '篩選結果可用上方搜尋與時間 chip。',
                        style: TextStyle(fontSize: 12, color: t.fgMute, height: 1.55),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RailTitle extends StatelessWidget {
  final String label;
  const _RailTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.5,
        color: t.fgMute,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final String label;
  final String value;
  const _StreakRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: serifItalic(size: 30, color: t.fg)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12.5, color: t.fgDim)),
        ],
      ),
    );
  }
}

// ─────────────────── HOME STAGE (錄音／文件) ───────────────────

class _HomeStage extends StatelessWidget {
  final bool isMobile;
  final bool online;
  final int mobileTranscriptTab;
  final ValueChanged<int> onMobileTranscriptTabChange;
  final bool showDesktopSpaceHint;
  final Future<void> Function() onPickFile;
  final Future<void> Function() onToggleRecord;
  final Future<void> Function(File) onRetryFile;
  final Future<void> Function() onRetryLast;
  final VoidCallback onGoToSettings;
  final VoidCallback onGoToHistory;

  const _HomeStage({
    required this.isMobile,
    required this.online,
    required this.mobileTranscriptTab,
    required this.onMobileTranscriptTabChange,
    required this.showDesktopSpaceHint,
    required this.onPickFile,
    required this.onToggleRecord,
    required this.onRetryFile,
    required this.onRetryLast,
    required this.onGoToSettings,
    required this.onGoToHistory,
  });

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final transcription = context.watch<TranscriptionProvider>();
    final pendingQueue = context.watch<PendingQueueProvider>();

    final hasContent =
        transcription.hasTranscript || transcription.organizedText.isNotEmpty;
    final isIdle = !recording.isRecording &&
        !transcription.isTranscribing &&
        !transcription.isOrganizing &&
        !hasContent;
    final recordEnabled = recording.isRecording ||
        (!transcription.isTranscribing && !transcription.isOrganizing);

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _StageHead(
                isMobile: isMobile,
                online: online,
                onPickFile: onPickFile,
                onGoToHistory: onGoToHistory,
                onGoToSettings: onGoToSettings,
                isTranscribing: transcription.isTranscribing,
                isOrganizing: transcription.isOrganizing,
              ),
              if (transcription.isTranscribing || transcription.isOrganizing)
                _ProgressStrip(
                  label: transcription.isTranscribing ? '步驟 1/2：轉錄口語稿' : '步驟 2/2：潤飾文字稿',
                  detail: transcription.isTranscribing &&
                          transcription.transcribePartTotal > 1
                      ? '長錄音分段上傳（第 ${transcription.transcribePartIndex}／${transcription.transcribePartTotal} 段）'
                      : null,
                ),
              if (!online)
                _OfflineStrip(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 48,
                    isMobile ? 24 : 36,
                    isMobile ? 20 : 48,
                    isMobile ? 200 : 180,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isIdle)
                            _IdleHero(isMobile: isMobile, showDesktopSpaceHint: showDesktopSpaceHint, onTapMic: onToggleRecord, recordEnabled: recordEnabled, isRecording: recording.isRecording)
                          else
                            _DocBody(
                              isMobile: isMobile,
                              recording: recording,
                              transcription: transcription,
                              mobileTranscriptTab: mobileTranscriptTab,
                              onMobileTranscriptTabChange: onMobileTranscriptTabChange,
                            ),
                          if (transcription.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _ErrorPanel(
                                transcription: transcription,
                                online: online,
                                onRetryLast: onRetryLast,
                                onGoToSettings: onGoToSettings,
                              ),
                            ),
                          if (pendingQueue.files.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: _PendingQueueCard(
                                files: pendingQueue.files,
                                online: online,
                                onRetryFile: onRetryFile,
                                isTranscribing: transcription.isTranscribing,
                              ),
                            ),
                          if (hasContent &&
                              !transcription.isTranscribing &&
                              !transcription.isOrganizing)
                            Padding(
                              padding: const EdgeInsets.only(top: 28),
                              child: _ActionBar(
                                hasRaw: transcription.hasTranscript,
                                hasPolished:
                                    transcription.organizedText.isNotEmpty,
                                rawText: transcription.rawTranscript,
                                polishedText: transcription.organizedText,
                              ),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating Pill HUD — bottom-center
        if (!isIdle || hasContent || recording.isRecording)
          Positioned(
            left: 0,
            right: 0,
            bottom: isMobile ? 24 : 36,
            child: Center(
              child: RecordHUDPill(
                isRecording: recording.isRecording,
                enabled: recordEnabled,
                onToggle: onToggleRecord,
                elapsed: _shortElapsed(recording.elapsedFormatted),
                waveformSamples: recording.waveformSamples,
              ),
            ),
          ),
      ],
    );
  }

  String _shortElapsed(String hms) {
    // 「HH:MM:SS」→「MM:SS」（小時為 0 時）
    final parts = hms.split(':');
    if (parts.length == 3 && parts[0] == '00') {
      return '${parts[1]}:${parts[2]}';
    }
    return hms;
  }
}

// ── Stage head: crumbs + spacer + actions ──
class _StageHead extends StatelessWidget {
  final bool isMobile;
  final bool online;
  final Future<void> Function() onPickFile;
  final VoidCallback onGoToHistory;
  final VoidCallback onGoToSettings;
  final bool isTranscribing;
  final bool isOrganizing;

  const _StageHead({
    required this.isMobile,
    required this.online,
    required this.onPickFile,
    required this.onGoToHistory,
    required this.onGoToSettings,
    required this.isTranscribing,
    required this.isOrganizing,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = isTranscribing || isOrganizing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 18 : 28, vertical: 14),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          if (!isMobile) ...[
            Text('VoiceType',
                style: TextStyle(fontSize: 12.5, color: t.fgMute)),
            const SizedBox(width: 8),
            Text('/', style: TextStyle(fontSize: 12.5, color: t.fgMute)),
            const SizedBox(width: 8),
          ],
          Text(
            '錄音',
            style: TextStyle(
              fontSize: 12.5,
              color: t.fg,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.audio_file_outlined,
            tooltip: '從檔案轉錄（WAV／M4A）',
            onTap: disabled ? null : onPickFile,
          ),
          if (isMobile) ...[
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.history_rounded,
              tooltip: '歷史紀錄',
              onTap: onGoToHistory,
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.settings_outlined,
              tooltip: '設定',
              onTap: onGoToSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
              color: onTap == null ? t.fgMute : t.fgDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle hero: large mic CTA ──
class _IdleHero extends StatelessWidget {
  final bool isMobile;
  final bool showDesktopSpaceHint;
  final Future<void> Function() onTapMic;
  final bool recordEnabled;
  final bool isRecording;

  const _IdleHero({
    required this.isMobile,
    required this.showDesktopSpaceHint,
    required this.onTapMic,
    required this.recordEnabled,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = isMobile ? 96.0 : 84.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: t.lineStrong, style: BorderStyle.solid),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.accent.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                RecordButton(
                  isRecording: isRecording,
                  enabled: recordEnabled,
                  onTap: onTapMic,
                  size: size,
                ),
                const SizedBox(height: 18),
                Text(
                  '準備好了，按下開始錄音',
                  textAlign: TextAlign.center,
                  style: serifItalic(size: isMobile ? 22 : 26, color: t.fg),
                ),
                const SizedBox(height: 8),
                Text(
                  '錄音結束後會自動轉成口語稿、再潤飾並儲存到歷史。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: t.fgDim,
                    height: 1.6,
                  ),
                ),
                if (showDesktopSpaceHint) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: t.bgChip,
                            border: Border.all(color: t.lineStrong),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text('Space', style: mono(size: 11, color: t.fg)),
                        ),
                        const SizedBox(width: 8),
                        Text('或 Ctrl+Alt+V 全域切換',
                            style: TextStyle(fontSize: 11.5, color: t.fgDim)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Doc body: title + meta + transcript columns ──
class _DocBody extends StatelessWidget {
  final bool isMobile;
  final RecordingProvider recording;
  final TranscriptionProvider transcription;
  final int mobileTranscriptTab;
  final ValueChanged<int> onMobileTranscriptTabChange;

  const _DocBody({
    required this.isMobile,
    required this.recording,
    required this.transcription,
    required this.mobileTranscriptTab,
    required this.onMobileTranscriptTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isRec = recording.isRecording;
    final progressLabel = transcription.isTranscribing
        ? (transcription.transcribePartTotal > 1
            ? '轉錄第 ${transcription.transcribePartIndex}/${transcription.transcribePartTotal} 段'
            : '正在將錄音轉成口語稿…')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          isRec ? '錄音中…' : '本次錄音',
          style: serifItalic(size: isMobile ? 32 : 44, color: t.fg, height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(
          '即時轉錄並潤飾',
          style: TextStyle(fontSize: 14, color: t.fgDim, letterSpacing: 0.2),
        ),
        const SizedBox(height: 22),

        // Meta row
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _RecDot(live: isRec),
            _MetaChip(
              label: isRec ? recording.elapsedFormatted : 'gpt-4o-mini',
            ),
            _MetaChip(label: 'whisper · 繁中'),
          ],
        ),
        const SizedBox(height: 24),

        // transcript columns
        if (isMobile) ...[
          _MobileTranscriptTabs(
            current: mobileTranscriptTab,
            onChange: onMobileTranscriptTabChange,
          ),
          const SizedBox(height: 16),
          _ColumnLabel(
            label: mobileTranscriptTab == 0 ? '口語稿' : '文字稿',
            primary: mobileTranscriptTab == 1,
          ),
          const SizedBox(height: 12),
          if (mobileTranscriptTab == 0)
            TranscriptView(
              segments: transcription.segments,
              isTranscribing: transcription.isTranscribing,
              isRecording: isRec,
              transcribeProgressLabel: progressLabel,
            )
          else
            OrganizedView(
              text: transcription.organizedText,
              textVersion: transcription.organizedTextVersion,
              isOrganizing: transcription.isOrganizing,
              organizingMessage: '產生文字稿中…',
              organizingDetail: transcription.isOrganizing
                  ? '步驟 2/2：完成後會自動寫入歷史'
                  : null,
              emptyMessage: '錄音結束後會自動潤飾並寫入歷史。',
              onTextChanged: transcription.setOrganizedTextUser,
            ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ColumnLabel(label: '口語稿', primary: false),
                      const SizedBox(height: 14),
                      TranscriptView(
                        segments: transcription.segments,
                        isTranscribing: transcription.isTranscribing,
                        isRecording: isRec,
                        transcribeProgressLabel: progressLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ColumnLabel(label: '文字稿', primary: true),
                      const SizedBox(height: 14),
                      OrganizedView(
                        text: transcription.organizedText,
                        textVersion: transcription.organizedTextVersion,
                        isOrganizing: transcription.isOrganizing,
                        organizingMessage: '產生文字稿中…',
                        organizingDetail: transcription.isOrganizing
                            ? '步驟 2/2：完成後會自動寫入歷史'
                            : null,
                        emptyMessage: '錄音結束後會自動潤飾並寫入歷史。',
                        onTextChanged: transcription.setOrganizedTextUser,
                      ),
                    ],
                  ),
                ),
              ],
          ),
      ],
    );
  }
}

class _MobileTranscriptTabs extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChange;

  const _MobileTranscriptTabs({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(int idx, String label) {
      final on = current == idx;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(idx),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: on ? t.bgCard : Colors.transparent,
              border: Border.all(
                color: on ? t.lineStrong : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? t.accent : t.fgMute,
                    boxShadow: on
                        ? [BoxShadow(color: t.accentGlow, blurRadius: 8)]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: on ? t.fg : t.fgDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.bgChip,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          btn(0, '口語'),
          const SizedBox(width: 4),
          btn(1, '文字'),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  final String label;
  final bool primary;
  const _ColumnLabel({required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary ? t.accent : t.fgMute,
            boxShadow:
                primary ? [BoxShadow(color: t.accentGlow, blurRadius: 10)] : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w500,
            color: t.fgMute,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.bgChip,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: mono(size: 11, color: t.fgDim)),
    );
  }
}

class _RecDot extends StatelessWidget {
  final bool live;
  const _RecDot({required this.live});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? t.danger : t.fgMute,
        boxShadow: live
            ? [BoxShadow(color: t.dangerGlow, blurRadius: 0, spreadRadius: 3)]
            : null,
      ),
    );
  }
}

// ── Action bar (簡化：只剩 口語 / 文字 複製) ──
class _ActionBar extends StatelessWidget {
  final bool hasRaw;
  final bool hasPolished;
  final String rawText;
  final String polishedText;

  const _ActionBar({
    required this.hasRaw,
    required this.hasPolished,
    required this.rawText,
    required this.polishedText,
  });

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已複製$label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasRaw)
            OutlinedButton.icon(
              onPressed: () => _copy(context, rawText, '口語'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('口語'),
            ),
          if (hasPolished)
            FilledButton.icon(
              onPressed: () => _copy(context, polishedText, '文字'),
              icon: const Icon(Icons.article_outlined, size: 16),
              label: const Text('文字'),
            ),
        ],
      ),
    );
  }
}

// ── Strips ──
class _OfflineStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: t.bgChip,
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: t.fgDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '目前為離線：轉錄需要網路。連上後再按「轉錄」或「重試轉錄」。',
              style: TextStyle(fontSize: 12.5, color: t.fgDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final String label;
  final String? detail;
  const _ProgressStrip({required this.label, this.detail});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.accent.withValues(alpha: 0.10), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: t.bgChip,
              valueColor: AlwaysStoppedAnimation(t.accent),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: TextStyle(fontSize: 12, color: t.fgDim, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error panel ──
class _ErrorPanel extends StatelessWidget {
  final TranscriptionProvider transcription;
  final bool online;
  final Future<void> Function() onRetryLast;
  final VoidCallback onGoToSettings;

  const _ErrorPanel({
    required this.transcription,
    required this.online,
    required this.onRetryLast,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: t.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        color: t.danger.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transcription.hasPartialTranscribeResume)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '重試轉錄將從失敗段繼續，已成功的口語稿段落會保留。',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.danger,
                ),
              ),
            ),
          SelectableText(
            transcription.error!,
            style: TextStyle(color: t.fg, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (transcription.errorClipboardText != null)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: transcription.errorClipboardText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製錯誤詳情')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('複製錯誤'),
                ),
              if (transcription.error!.contains('金鑰'))
                TextButton.icon(
                  onPressed: onGoToSettings,
                  icon: const Icon(Icons.settings, size: 14),
                  label: const Text('前往設定'),
                ),
              if (transcription.lastTranscribeSessionPath != null &&
                  !transcription.isTranscribing)
                TextButton.icon(
                  onPressed: () => onRetryLast(),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('重試轉錄'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pending queue card ──
class _PendingQueueCard extends StatelessWidget {
  final List<File> files;
  final bool online;
  final Future<void> Function(File) onRetryFile;
  final bool isTranscribing;

  const _PendingQueueCard({
    required this.files,
    required this.online,
    required this.onRetryFile,
    required this.isTranscribing,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: t.bgCard,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions_outlined, size: 16, color: t.accent),
              const SizedBox(width: 8),
              Text(
                '待轉錄（${files.length}）',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: t.fg,
                ),
              ),
            ],
          ),
          if (!online)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '離線中：連上網路後再按「轉錄」。',
                style: TextStyle(fontSize: 12, color: t.fgMute),
              ),
            ),
          const SizedBox(height: 6),
          ...files.asMap().entries.expand((e) {
            final i = e.key;
            final f = e.value;
            final name = f.uri.pathSegments.isNotEmpty
                ? f.uri.pathSegments.last
                : f.path;
            return [
              if (i > 0) Divider(height: 1, color: t.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.audio_file_outlined, size: 18, color: t.fgDim),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.fg),
                      ),
                    ),
                    TextButton(
                      onPressed: isTranscribing || !online
                          ? null
                          : () => onRetryFile(f),
                      child: const Text('轉錄'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: '刪除此待轉錄檔',
                      onPressed: isTranscribing
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
    );
  }
}

// ── Windows 自訂標題列（拖移 + 最小化/最大化/關閉）──
class _WinTitleBar extends StatelessWidget {
  final Color bg;
  final Color iconColor;
  const _WinTitleBar({required this.bg, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          Positioned.fill(child: DragToMoveArea(child: Container(color: bg))),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleBtn(
                  icon: Icons.remove,
                  color: iconColor,
                  onTap: () => windowManager.minimize(),
                ),
                _TitleBtn(
                  icon: Icons.crop_square_outlined,
                  color: iconColor,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                _TitleBtn(
                  icon: Icons.close,
                  color: iconColor,
                  hoverDanger: true,
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool hoverDanger;
  final VoidCallback onTap;
  const _TitleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.hoverDanger = false,
  });

  @override
  State<_TitleBtn> createState() => _TitleBtnState();
}

class _TitleBtnState extends State<_TitleBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dangerBg = t.danger.withAlpha(200);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: 32,
          color: _hovering
              ? (widget.hoverDanger ? dangerBg : t.line)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: (_hovering && widget.hoverDanger) ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}
