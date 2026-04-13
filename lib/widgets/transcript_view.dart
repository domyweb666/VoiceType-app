import 'package:flutter/material.dart';
import '../models/transcription_segment.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: scheme.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TranscriptView extends StatefulWidget {
  final List<TranscriptionSegment> segments;
  final bool isTranscribing;
  final bool isRecording;

  /// 例如「轉錄第 2/5 段」；單段轉錄可為 null，由內文顯示「轉錄中…」。
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
    if (widget.segments.isEmpty &&
        !widget.isTranscribing &&
        !widget.isRecording) {
      return const _EmptyHint(
        icon: Icons.graphic_eq_outlined,
        title: '尚無口語稿',
        subtitle: '點中央麥克風開始錄音；結束後會自動轉成逐段口語稿。',
      );
    }

    if (widget.segments.isEmpty && widget.isRecording && !widget.isTranscribing) {
      return const _EmptyHint(
        icon: Icons.fiber_manual_record_outlined,
        title: '錄音進行中',
        subtitle: '結束錄音後才會開始轉錄。長時間口述可連續錄製約 20–30 分鐘。',
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: widget.segments.length + (widget.isTranscribing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.segments.length) {
          final sub = widget.transcribeProgressLabel;
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Material(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '轉錄中…',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor:
                            scheme.onPrimaryContainer.withValues(alpha: 0.12),
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: SelectableText(
                widget.segments[index].text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.65,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
