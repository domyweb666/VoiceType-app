import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../config/constants.dart';
import '../../providers/pending_queue_provider.dart';
import '../../providers/recording_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transcription_provider.dart';
import '../organized_view.dart';
import '../record_button.dart';
import '../record_hud_pill.dart';
import '../transcript_view.dart';
import 'error_panel.dart';
import 'pending_queue_card.dart';

// ─────────────────── HOME STAGE (錄音／文件) ───────────────────

class HomeStage extends StatelessWidget {
  final bool isMobile;
  final bool online;
  final int mobileTranscriptTab;
  final ValueChanged<int> onMobileTranscriptTabChange;
  final bool showDesktopSpaceHint;
  final Future<void> Function() onPickFile;
  final Future<void> Function() onToggleRecord;
  final Future<void> Function(File) onRetryFile;
  final Future<void> Function() onRetryAll;
  final Future<void> Function() onRetryLast;
  final VoidCallback onGoToSettings;
  final VoidCallback onGoToHistory;

  const HomeStage({
    super.key,
    required this.isMobile,
    required this.online,
    required this.mobileTranscriptTab,
    required this.onMobileTranscriptTabChange,
    required this.showDesktopSpaceHint,
    required this.onPickFile,
    required this.onToggleRecord,
    required this.onRetryFile,
    required this.onRetryAll,
    required this.onRetryLast,
    required this.onGoToSettings,
    required this.onGoToHistory,
  });

  @override
  Widget build(BuildContext context) {
    // 只依賴「粗粒度」的 isRecording，避免每 90ms 波形 tick 觸發整個 stage
    // （含 TextField／SelectableText 子樹）重建。快速變動的資料（波形、計時）
    // 各自用 Consumer 局部訂閱。
    final isRecording = context.select<RecordingProvider, bool>(
      (r) => r.isRecording,
    );
    final transcription = context.watch<TranscriptionProvider>();
    final pendingQueue = context.watch<PendingQueueProvider>();
    // 首次啟動引導：金鑰還沒備妥時，idle hero 改顯示「第一步：設定金鑰」。
    final needsKeySetup = context.select<SettingsProvider, bool>(
      (s) => !s.isLoading && !s.canTranscribe,
    );

    final hasContent =
        transcription.hasTranscript || transcription.organizedText.isNotEmpty;
    final isIdle = !isRecording &&
        !transcription.isTranscribing &&
        !transcription.isOrganizing &&
        !hasContent;
    final recordEnabled = isRecording ||
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
                            _IdleHero(
                              isMobile: isMobile,
                              showDesktopSpaceHint: showDesktopSpaceHint,
                              onTapMic: onToggleRecord,
                              recordEnabled: recordEnabled,
                              isRecording: isRecording,
                              needsKeySetup: needsKeySetup,
                              onGoToSettings: onGoToSettings,
                            )
                          else
                            _DocBody(
                              isMobile: isMobile,
                              isRecording: isRecording,
                              transcription: transcription,
                              mobileTranscriptTab: mobileTranscriptTab,
                              onMobileTranscriptTabChange: onMobileTranscriptTabChange,
                            ),
                          if (transcription.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ErrorPanel(
                                transcription: transcription,
                                online: online,
                                onRetryLast: onRetryLast,
                                onGoToSettings: onGoToSettings,
                              ),
                            ),
                          if (pendingQueue.files.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: PendingQueueCard(
                                files: pendingQueue.files,
                                online: online,
                                onRetryFile: onRetryFile,
                                onRetryAll: onRetryAll,
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
        if (!isIdle || hasContent || isRecording)
          Positioned(
            left: 0,
            right: 0,
            bottom: isMobile ? 24 : 36,
            child: Center(
              // 波形與計時每 90ms 更新，僅在此局部訂閱 RecordingProvider，
              // 不觸發外層 stage 重建。
              child: Consumer<RecordingProvider>(
                builder: (context, recording, _) => RecordHUDPill(
                  isRecording: recording.isRecording,
                  enabled: recordEnabled,
                  onToggle: onToggleRecord,
                  elapsed: _shortElapsed(recording.elapsedFormatted),
                  waveformSamples: recording.waveformSamples,
                ),
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
  final bool needsKeySetup;
  final VoidCallback onGoToSettings;

  const _IdleHero({
    required this.isMobile,
    required this.showDesktopSpaceHint,
    required this.onTapMic,
    required this.recordEnabled,
    required this.isRecording,
    required this.needsKeySetup,
    required this.onGoToSettings,
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
                  needsKeySetup ? '第一步：設定轉錄金鑰' : '準備好了，按下開始錄音',
                  textAlign: TextAlign.center,
                  style: serifItalic(size: isMobile ? 22 : 26, color: t.fg),
                ),
                const SizedBox(height: 8),
                Text(
                  needsKeySetup
                      ? '現在也可以直接錄，錄好的檔會先存進「待轉錄」；\n設定金鑰後會自動轉成文字。'
                      : '錄音結束後會自動轉成口語稿、再潤飾並儲存到歷史。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: t.fgDim,
                    height: 1.6,
                  ),
                ),
                if (needsKeySetup) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onGoToSettings,
                        icon: const Icon(Icons.vpn_key_outlined, size: 16),
                        label: const Text('前往設定金鑰'),
                      ),
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(AppConstants.openaiKeyHelpUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('如何取得金鑰？'),
                      ),
                    ],
                  ),
                ],
                if (showDesktopSpaceHint && !needsKeySetup) ...[
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
  final bool isRecording;
  final TranscriptionProvider transcription;
  final int mobileTranscriptTab;
  final ValueChanged<int> onMobileTranscriptTabChange;

  const _DocBody({
    required this.isMobile,
    required this.isRecording,
    required this.transcription,
    required this.mobileTranscriptTab,
    required this.onMobileTranscriptTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isRec = isRecording;
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
            // 錄音中的計時每秒更新，僅局部訂閱 RecordingProvider，
            // 避免與波形 tick 一起重建整個轉錄欄位。
            if (isRec)
              Consumer<RecordingProvider>(
                builder: (context, recording, _) =>
                    _MetaChip(label: recording.elapsedFormatted),
              )
            else
              _MetaChip(label: 'gpt-4o-mini'),
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

// ── Action bar: 複製口語稿 / 複製文字稿 / 分享（手機） ──
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

  static bool get _showShare =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    final shareText = hasPolished ? polishedText : rawText;
    return Container(
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasPolished)
            FilledButton.icon(
              onPressed: () => _copy(context, polishedText, '文字稿'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('複製文字稿'),
            ),
          if (hasRaw)
            OutlinedButton.icon(
              onPressed: () => _copy(context, rawText, '口語稿'),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('複製口語稿'),
            ),
          if (_showShare && shareText.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => Share.share(shareText),
              icon: const Icon(Icons.ios_share_outlined, size: 16),
              label: const Text('分享'),
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
