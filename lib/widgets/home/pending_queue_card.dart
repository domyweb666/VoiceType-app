import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/pending_queue_provider.dart';

// ── Pending queue card ──
class PendingQueueCard extends StatelessWidget {
  final List<File> files;
  final bool online;
  final Future<void> Function(File) onRetryFile;
  final Future<void> Function() onRetryAll;
  final bool isTranscribing;

  const PendingQueueCard({
    super.key,
    required this.files,
    required this.online,
    required this.onRetryFile,
    required this.onRetryAll,
    required this.isTranscribing,
  });

  /// 刪除是永久的（錄音檔就沒了），先確認再動手。
  Future<void> _confirmDelete(BuildContext context, File f) async {
    final name =
        f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : f.path;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這個錄音檔？'),
        content: Text('「$name」還沒轉錄，刪掉後就找不回來了。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<PendingQueueProvider>().deletePending(f);
  }

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
              Expanded(
                child: Text(
                  '待轉錄（${files.length}）',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                  ),
                ),
              ),
              if (files.length > 1)
                TextButton.icon(
                  onPressed:
                      isTranscribing || !online ? null : () => onRetryAll(),
                  icon: const Icon(Icons.playlist_play_rounded, size: 18),
                  label: const Text('全部轉錄'),
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
                          : () => _confirmDelete(context, f),
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
