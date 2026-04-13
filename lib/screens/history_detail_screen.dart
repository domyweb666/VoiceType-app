import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transcript_record.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transcription_provider.dart';
import '../services/cost_estimate_service.dart';
import '../services/export_service.dart';
import 'settings_screen.dart';

class HistoryDetailScreen extends StatefulWidget {
  final TranscriptRecord record;

  const HistoryDetailScreen({super.key, required this.record});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late TranscriptRecord _record;
  bool _polishing = false;
  late final SettingsProvider _settingsRef;
  late final VoidCallback _syncTranscriptionApiKey;
  late final TextEditingController _organizedController;
  late final FocusNode _organizedFocus;

  bool get _showOrganizedSection =>
      _record.organizedText.isNotEmpty || _record.rawText.isNotEmpty;

  String get _textForCopy {
    final live = _organizedController.text;
    if (live.trim().isNotEmpty) return live;
    if (_record.organizedText.isNotEmpty) return _record.organizedText;
    return _record.rawText;
  }

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _organizedController =
        TextEditingController(text: widget.record.organizedText);
    _organizedFocus = FocusNode();
    _organizedFocus.addListener(_onOrganizedFocusChange);
    _settingsRef = context.read<SettingsProvider>();
    _syncTranscriptionApiKey = () {
      if (!mounted) return;
      context.read<TranscriptionProvider>().updateApiKey(_settingsRef.apiKey);
    };
    _settingsRef.addListener(_syncTranscriptionApiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTranscriptionApiKey();
    });
  }

  void _onOrganizedFocusChange() {
    if (!_organizedFocus.hasFocus) {
      unawaited(_persistOrganizedIfChanged());
    }
  }

  /// 若有變更並成功寫入則為 `true`（供按鈕顯示「已儲存」提示）。
  Future<bool> _persistOrganizedIfChanged() async {
    if (!mounted || !_showOrganizedSection) return false;
    final text = _organizedController.text;
    if (text == _record.organizedText) return false;
    final history = context.read<HistoryProvider>();
    await history.updateOrganizedText(id: _record.id, organizedText: text);
    if (!mounted) return false;
    try {
      final updated = history.records.firstWhere((r) => r.id == _record.id);
      setState(() => _record = updated);
    } catch (_) {}
    return true;
  }

  void _syncOrganizedControllerFromRecord() {
    if (_organizedController.text == _record.organizedText) return;
    _organizedController.value = TextEditingValue(
      text: _record.organizedText,
      selection:
          TextSelection.collapsed(offset: _record.organizedText.length),
    );
  }

  @override
  void dispose() {
    _organizedFocus.removeListener(_onOrganizedFocusChange);
    _organizedController.dispose();
    _organizedFocus.dispose();
    _settingsRef.removeListener(_syncTranscriptionApiKey);
    super.dispose();
  }

  Future<void> _runPolishThenSave() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('請先至設定輸入 API 金鑰'),
          action: SnackBarAction(
            label: '設定',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
      );
      return;
    }

    final mode = await showDialog<_PolishSaveMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('只潤飾文字稿（不重轉錄）'),
        content: const Text('將以目前設定的潤飾提示詞，對此筆口語稿重新產生文字稿。要覆寫原文字稿，或另存成一筆新紀錄？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PolishSaveMode.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _PolishSaveMode.overwrite),
            child: const Text('覆寫此筆'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _PolishSaveMode.newCopy),
            child: const Text('另存新筆'),
          ),
        ],
      ),
    );
    if (mode == null || mode == _PolishSaveMode.cancel || !mounted) return;

    final transcription = context.read<TranscriptionProvider>();
    transcription.updateApiKey(settings.apiKey);

    setState(() => _polishing = true);
    final result = await transcription.polishStandalone(
      rawText: _record.rawText,
      systemPrompt: settings.buildOrganizeSystemPrompt(),
    );
    if (!mounted) return;
    setState(() => _polishing = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '潤飾失敗'),
        ),
      );
      return;
    }

    final costHint = SessionCostEstimateService.buildPolishOnlyTwdRangeHint(
      organizePromptTokens: result.promptTokens,
      organizeCompletionTokens: result.completionTokens,
      rawTranscriptCharCount: _record.rawText.length,
    );
    final tokenLine = (result.promptTokens != null &&
            result.completionTokens != null)
        ? '\n本次 API token（約）：輸入 ${result.promptTokens}／輸出 ${result.completionTokens}'
        : '';

    final history = context.read<HistoryProvider>();
    if (mode == _PolishSaveMode.overwrite) {
      await history.updateOrganizedText(
        id: _record.id,
        organizedText: result.organizedText!,
      );
      try {
        final updated =
            history.records.firstWhere((r) => r.id == _record.id);
        if (mounted) {
          setState(() => _record = updated);
          _syncOrganizedControllerFromRecord();
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已覆寫此筆文字稿\n\n$costHint$tokenLine'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } else {
      final saved = await history.savePolishedVariant(
        source: _record,
        organizedText: result.organizedText!,
      );
      if (mounted) {
        setState(() => _record = saved);
        _syncOrganizedControllerFromRecord();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已另存新筆紀錄\n\n$costHint$tokenLine'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _showExportSheet() async {
    await _persistOrganizedIfChanged();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('分享文字稿（.txt）'),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.shareRecordAsTxt(
                  record: _record,
                  organizedOnly: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('分享口語稿（.txt）'),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.shareRecordRawTxt(_record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('分享 Markdown（.md）'),
              onTap: () async {
                Navigator.pop(ctx);
                await ExportService.shareRecordMarkdown(_record);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _persistOrganizedIfChanged();
        if (!context.mounted) return;
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_record.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: '匯出／分享',
            onPressed: _showExportSheet,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製文字稿',
            onPressed: () {
              final text = _textForCopy;
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已複製'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '刪除',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final scheme = Theme.of(ctx).colorScheme;
                  return AlertDialog(
                    icon: Icon(
                      Icons.delete_forever_outlined,
                      color: scheme.error,
                      size: 28,
                    ),
                    title: const Text('刪除此筆紀錄？'),
                    content: const Text('口語稿與文字稿都會一併移除，且無法復原。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('刪除'),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true && context.mounted) {
                await context.read<HistoryProvider>().deleteRecord(_record.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_record.createdAt.year}/${_record.createdAt.month}/${_record.createdAt.day} '
                            '${_record.createdAt.hour}:${_record.createdAt.minute.toString().padLeft(2, '0')}  ·  '
                            '長度 ${_record.durationSeconds ~/ 60}:'
                            '${(_record.durationSeconds % 60).toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _polishing ? null : _runPolishThenSave,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 22),
                  label: const Text('只潤飾文字稿（調提示詞後重跑）'),
                ),
                const SizedBox(height: 20),
                if (_showOrganizedSection) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '文字稿（潤飾後）',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final saved = await _persistOrganizedIfChanged();
                          if (!context.mounted) return;
                          if (saved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已儲存文字稿'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('儲存'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _organizedController,
                        focusNode: _organizedFocus,
                        maxLines: null,
                        minLines: 6,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.85,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: _record.organizedText.isEmpty
                              ? '可在此手動輸入，或點上方「只潤飾文字稿」由口語稿產生'
                              : null,
                          hintStyle: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.85,
                            ),
                            height: 1.85,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    '口語稿（語音轉錄）',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  initiallyExpanded: _record.organizedText.isEmpty,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _record.rawText,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_polishing)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.72),
                  child: Center(
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '潤飾中…',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '請勿關閉此畫面',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

enum _PolishSaveMode { cancel, overwrite, newCopy }
