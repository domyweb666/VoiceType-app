import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';
import '../config/user_disclosure.dart';
import '../providers/history_provider.dart';
import '../providers/pending_queue_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transcription_provider.dart';
import '../services/desktop_notify_service.dart';
import '../services/pending_session_service.dart';
import '../services/recording_hotkey_bus.dart';
import '../widgets/home/home_nav.dart';
import '../widgets/home/home_stage.dart';
import '../widgets/home/win_title_bar.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// 空白鍵切換錄音（首頁焦點時）。
class ToggleRecordingIntent extends Intent {
  const ToggleRecordingIntent();
}

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

  NavView _view = NavView.home;
  // Mobile: 0 = raw 口語, 1 = polished 文字 (預設文字稿)。
  int _mobileTranscriptTab = 1;

  bool _autoResumeFired = false;

  // 使用者在首頁引導卡按「先略過」後為 true：本次啟動不再把金鑰引導
  // 當成強制擋牆，改顯示一般錄音畫面（仍可直接錄，錄檔進「待轉錄」）。
  bool _onboardingDismissed = false;

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

  /// 離線守門：離線時彈出提示並回傳 false（呼叫端據此提早 return），
  /// 線上時回傳 true。集中原本散落各處的相同離線檢查 + SnackBar。
  bool _guardOnline({required String message}) {
    if (_online) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _settingsRef = context.read<SettingsProvider>();
    _settingsRef.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTranscriptionConfig();
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

  /// 把設定同步到 TranscriptionProvider（引擎、兩把金鑰）。
  void _syncTranscriptionConfig() {
    if (!mounted) return;
    final t = context.read<TranscriptionProvider>();
    t.setEngine(_settingsRef.asrEngine);
    t.updateApiKey(_settingsRef.apiKey);
    t.updateBytePlusKey(_settingsRef.bytePlusApiKey);
  }

  /// 設定變更：同步金鑰／引擎，並在條件齊備時觸發待轉錄自動續轉。
  void _onSettingsChanged() {
    if (!mounted) return;
    _syncTranscriptionConfig();
    if (!_settingsRef.canTranscribe) return;
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
    if (!settings.canTranscribe) return;
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
    // 只有在目標檔已被消化（轉錄成功刪檔）時才續轉下一個；
    // 失敗的檔仍留在佇列時停止連鎖，避免無限重試與提示條閃爍，
    // 改由使用者手動點「轉錄」重試。
    final remaining = context.read<PendingQueueProvider>().files;
    final targetConsumed = !remaining.any((f) => f.path == target.path);
    if (remaining.isNotEmpty && targetConsumed) {
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
                onPressed: () {
                  // 先同步關閉對話框，再 fire-and-forget 寫入旗標。
                  // 避免「先 await 再 pop」在重建空檔中讓 pop 被跳過而卡死。
                  Navigator.of(dialogContext).pop();
                  context.read<SettingsProvider>().markPrivacyDisclosureSeen();
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
    _settingsRef.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _desktopRecordHotkeySub?.cancel();
    _homeShortcutFocus.dispose();
    super.dispose();
  }

  void _onSpaceShortcut() {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final transcription = context.read<TranscriptionProvider>();
    final recording = context.read<RecordingProvider>();
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
    if (t.error != null) {
      unawaited(DesktopNotifyService.showIfUnfocused(
        body: '轉錄失敗，點一下回到 VoiceType 查看詳情。',
      ));
      return;
    }

    // BytePlus 引擎可能沒有 OpenAI 金鑰：跳過潤飾，先把口語稿存進歷史。
    final settings = context.read<SettingsProvider>();
    if (!settings.hasApiKey) {
      final history = context.read<HistoryProvider>();
      final recording = context.read<RecordingProvider>();
      await history.saveRecord(
        rawText: t.rawTranscript,
        organizedText: '',
        durationSeconds: recording.elapsed.inSeconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已轉錄並儲存口語稿（潤飾需要 OpenAI 金鑰，可至設定補上）'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    await _polishAndSaveToHistory(
      doneMessage: '已完成轉錄、潤飾並儲存至歷史',
    );
  }

  Future<void> _retryTranscribeFile(File wav) async {
    if (!_guardOnline(message: '離線無法轉錄，請連上網路後再試。')) return;
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
    if (!settings.canTranscribe) {
      _showSettingsPrompt();
      return;
    }
    if (!_guardOnline(message: '離線狀態無法轉錄，請連上網路後再試。')) return;
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
    if (!_guardOnline(message: '離線無法轉錄，請連上網路後再試。')) return;
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

    if (_view != NavView.home) {
      setState(() => _view = NavView.home);
    }

    // 沒金鑰也照樣能錄：錄音不需要 API，錄完存進「待轉錄」，
    // 設定金鑰後由自動續轉接手，不讓設定問題吃掉當下的靈感。

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
        if (!settings.canTranscribe) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('錄音已存入「待轉錄」。設定轉錄金鑰後會自動幫你轉成文字。'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: '去設定',
                  onPressed: () => setState(() => _view = NavView.settings),
                ),
              ),
            );
          }
          return;
        }
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
        content: const Text('請先至設定輸入轉錄金鑰'),
        action: SnackBarAction(
          label: '設定',
          onPressed: () => setState(() => _view = NavView.settings),
        ),
      ),
    );
  }

  /// 待轉錄卡「全部轉錄」：重置旗標後交給自動續轉依序處理。
  Future<void> _retryAllPending() async {
    _autoResumeFired = false;
    await _autoResumePendingIfPossible();
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
      // BytePlus 引擎的轉錄費不走 OpenAI 計價，費用提示只算潤飾段。
      fullRoundTripCost:
          fullRoundTripCost && settings.asrEngine == AsrEngine.openai,
    );
    if (!mounted) return;
    if (transcription.error != null || transcription.organizedText.isEmpty) {
      if (transcription.error != null) {
        unawaited(DesktopNotifyService.showIfUnfocused(
          body: '潤飾失敗，點一下回到 VoiceType 查看詳情。',
        ));
      }
      return;
    }

    final saved = await history.saveRecord(
      rawText: transcription.rawTranscript,
      organizedText: transcription.organizedText,
      durationSeconds: recording.elapsed.inSeconds,
    );
    if (!mounted) return;

    // 懶人流：完成即複製，錄完直接去別的視窗貼上。
    var message = doneMessage;
    if (settings.autoCopyPolished) {
      await Clipboard.setData(
        ClipboardData(text: transcription.organizedText),
      );
      message = '$doneMessage，文字稿已複製';
    }
    if (!mounted) return;

    unawaited(DesktopNotifyService.showIfUnfocused(
      body: settings.autoCopyPolished
          ? '轉錄完成，文字稿已複製到剪貼簿，可直接貼上。'
          : '轉錄完成，文字稿已儲存到歷史。',
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
                      WinTitleBar(bg: t.bg, iconColor: t.fgDim),
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
    final showRail = _view == NavView.home || _view == NavView.history;

    return Row(
      children: [
        SizedBox(width: 260, child: Sidebar(view: _view, onSelect: (v) => setState(() => _view = v))),
        Container(width: 1, color: t.line),
        Expanded(child: _buildMainStage(isMobile: false)),
        if (showRail) ...[
          Container(width: 1, color: t.line),
          SizedBox(width: 360, child: RightRail(view: _view)),
        ],
      ],
    );
  }

  // ─── Mobile: 單欄 + Stack 浮動 mic ───
  // SafeArea 只在此處包一次：底下的歷史／設定內嵌畫面都在這個 SafeArea 內，
  // 不必各自再包（桌面三欄不走這條路徑，維持原樣）。
  Widget _buildMobile() => SafeArea(child: _buildMainStage(isMobile: true));

  Widget _buildMainStage({required bool isMobile}) {
    switch (_view) {
      case NavView.home:
        return HomeStage(
          isMobile: isMobile,
          online: _online,
          mobileTranscriptTab: _mobileTranscriptTab,
          onMobileTranscriptTabChange: (i) =>
              setState(() => _mobileTranscriptTab = i),
          showDesktopSpaceHint: _showDesktopSpaceHint,
          onboardingDismissed: _onboardingDismissed,
          onSkipOnboarding: () => setState(() => _onboardingDismissed = true),
          onPickFile: _pickAudioFromFiles,
          onToggleRecord: _toggleRecording,
          onRetryFile: _retryTranscribeFile,
          onRetryAll: _retryAllPending,
          onRetryLast: _retryLastTranscribeSession,
          onGoToSettings: () => setState(() => _view = NavView.settings),
          onGoToHistory: () => setState(() => _view = NavView.history),
        );
      case NavView.history:
        return HistoryScreen(
          embedded: true,
          onBack: () => setState(() => _view = NavView.home),
        );
      case NavView.settings:
        return SettingsScreen(
          embedded: true,
          onBack: () => setState(() => _view = NavView.home),
        );
    }
  }
}
