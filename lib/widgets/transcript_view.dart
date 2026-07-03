import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/transcription_segment.dart';

/// 口語稿（raw）。段落式排版（無時間戳），dim 文字色。
class TranscriptView extends StatefulWidget {
  final List<TranscriptionSegment> segments;
  final bool isTranscribing;
  final bool isRecording;

  /// 例如「轉錄第 2/5 段」；單段轉錄可為 null。
  final String? transcribeProgressLabel;

  const TranscriptView({
    super.key,
    required this.segments,
    this.isTranscribing = false,
    this.isRecording = false,
    this.transcribeProgressLabel,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.segments.length > oldWidget.segments.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (widget.segments.isEmpty &&
        !widget.isTranscribing &&
        !widget.isRecording) {
      return _EmptyHint(
        icon: Icons.graphic_eq_outlined,
        title: '尚無口語稿',
        subtitle: '錄音結束後會自動產生逐段口語稿。',
      );
    }

    if (widget.segments.isEmpty &&
        widget.isRecording &&
        !widget.isTranscribing) {
      return _EmptyHint(
        icon: Icons.fiber_manual_record_outlined,
        title: '錄音進行中',
        subtitle: '結束錄音後才會開始轉錄。',
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seg in widget.segments)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: SelectableText(
                seg.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.85,
                  color: t.fgDim,
                ),
              ),
            ),
          if (widget.isTranscribing)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: _TranscribingChip(
                label: widget.transcribeProgressLabel ?? '轉錄中…',
              ),
            ),
        ],
      ),
    );
  }
}

class _TranscribingChip extends StatelessWidget {
  final String label;
  const _TranscribingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.bgChip,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: t.fgDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyHint({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: t.fgMute),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.fgDim,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: t.fgMute, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
