import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../providers/transcription_provider.dart';

// ── Error panel ──
class ErrorPanel extends StatelessWidget {
  final TranscriptionProvider transcription;
  final bool online;
  final Future<void> Function() onRetryLast;
  final VoidCallback onGoToSettings;

  const ErrorPanel({
    super.key,
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
