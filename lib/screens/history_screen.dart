import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/transcript_record.dart';
import '../providers/history_provider.dart';
import '../services/export_service.dart';
import 'history_detail_screen.dart';

enum _HistoryDateFilter { all, today, week, month }

class HistoryScreen extends StatefulWidget {
  /// 開啟後捲動並微幅標示該筆。
  final String? scrollToRecordId;

  /// 是否嵌入在 HomeScreen 內部（桌面三欄佈局）；若為 true 則不顯示自有 Scaffold/AppBar。
  final bool embedded;

  /// 內嵌時的返回 callback。
  final VoidCallback? onBack;

  const HistoryScreen({
    super.key,
    this.scrollToRecordId,
    this.embedded = false,
    this.onBack,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  _HistoryDateFilter _dateFilter = _HistoryDateFilter.all;
  bool _didScrollToTarget = false;
  bool _scrollTargetPostFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HistoryProvider>().loadRecords();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inWeek(DateTime t, DateTime now) {
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    return !t.isBefore(start);
  }

  bool _inMonth(DateTime t, DateTime now) =>
      t.year == now.year && t.month == now.month;

  List<TranscriptRecord> _filtered(List<TranscriptRecord> all) {
    var list = List<TranscriptRecord>.from(all);
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.rawText.toLowerCase().contains(q) ||
            r.organizedText.toLowerCase().contains(q);
      }).toList();
    }
    final now = DateTime.now();
    switch (_dateFilter) {
      case _HistoryDateFilter.all:
        break;
      case _HistoryDateFilter.today:
        list = list.where((r) => _sameDay(r.createdAt, now)).toList();
        break;
      case _HistoryDateFilter.week:
        list = list.where((r) => _inWeek(r.createdAt, now)).toList();
        break;
      case _HistoryDateFilter.month:
        list = list.where((r) => _inMonth(r.createdAt, now)).toList();
        break;
    }
    return list;
  }

  void _tryScrollToTarget(List<TranscriptRecord> visible) {
    final id = widget.scrollToRecordId;
    if (id == null || _didScrollToTarget || _scrollTargetPostFrameScheduled) {
      return;
    }
    final idx = visible.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    _scrollTargetPostFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _didScrollToTarget = true;
      if (!_scrollController.hasClients) return;
      final offset = (idx * 76.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _exportFilteredZip(List<TranscriptRecord> list) async {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前清單為空，無法匯出')),
      );
      return;
    }
    await ExportService.shareRecordsZip(records: list);
  }

  /// 將紀錄按日期分群（今天 / 昨天 / 本週 / 本月 / 更早）。
  Map<String, List<TranscriptRecord>> _groupByDay(
    List<TranscriptRecord> list,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final groups = <String, List<TranscriptRecord>>{};
    for (final r in list) {
      final d = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      String key;
      if (d == today) {
        key = '今天';
      } else if (d == yesterday) {
        key = '昨天';
      } else if (!d.isBefore(weekStart)) {
        key = '本週';
      } else if (!d.isBefore(monthStart)) {
        key = '本月';
      } else {
        key = '更早';
      }
      groups.putIfAbsent(key, () => []).add(r);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final t = context.tokens;
    final visible = _filtered(history.records);
    _tryScrollToTarget(visible);

    final body = history.isLoading && history.records.isEmpty
        ? Center(
            child: CircularProgressIndicator(color: t.accent),
          )
        : (!history.isLoading &&
                history.records.isEmpty &&
                history.loadError != null)
            ? _ErrorRetry(
                message: history.loadError!,
                onRetry: () => context.read<HistoryProvider>().loadRecords(),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  widget.embedded ? 48 : 24,
                  24,
                  widget.embedded ? 48 : 24,
                  120,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero
                        _Hero(
                          totalCount: history.records.length,
                          onExport: () => _exportFilteredZip(visible),
                          onBack: widget.onBack,
                          embedded: widget.embedded,
                        ),
                        const SizedBox(height: 22),
                        // Search
                        _SearchBox(
                          controller: _searchController,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        // filter pills
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _FilterPill(
                              label: '全部',
                              on: _dateFilter == _HistoryDateFilter.all,
                              onTap: () => setState(() =>
                                  _dateFilter = _HistoryDateFilter.all),
                            ),
                            _FilterPill(
                              label: '今天',
                              on: _dateFilter == _HistoryDateFilter.today,
                              onTap: () => setState(() =>
                                  _dateFilter = _HistoryDateFilter.today),
                            ),
                            _FilterPill(
                              label: '本週',
                              on: _dateFilter == _HistoryDateFilter.week,
                              onTap: () => setState(() =>
                                  _dateFilter = _HistoryDateFilter.week),
                            ),
                            _FilterPill(
                              label: '本月',
                              on: _dateFilter == _HistoryDateFilter.month,
                              onTap: () => setState(() =>
                                  _dateFilter = _HistoryDateFilter.month),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // groups
                        if (visible.isEmpty)
                          _EmptyHistory()
                        else
                          ..._groupByDay(visible).entries.expand((g) sync* {
                            yield _DayGroupTitle(label: g.key);
                            yield Column(
                              children: g.value.map((rec) {
                                return _RecRow(
                                  record: rec,
                                  highlight: widget.scrollToRecordId == rec.id,
                                );
                              }).toList(),
                            );
                            yield const SizedBox(height: 22);
                          }),
                      ],
                    ),
                  ),
                ),
              );

    if (widget.embedded) {
      return Container(color: t.bg, child: body);
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: body),
    );
  }
}

// ── Components ──

class _Hero extends StatelessWidget {
  final int totalCount;
  final VoidCallback onExport;
  final VoidCallback? onBack;
  final bool embedded;

  const _Hero({
    required this.totalCount,
    required this.onExport,
    required this.onBack,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canPop = Navigator.canPop(context);
    final showBack = onBack != null || canPop;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showBack) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.bgChip,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.arrow_back_rounded, size: 18, color: t.fg),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            '歷史紀錄',
            style: serifItalic(size: 48, color: t.fg, height: 1.0),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$totalCount', style: serifItalic(size: 34, color: t.fg)),
            Text('筆紀錄', style: TextStyle(fontSize: 12, color: t.fgDim)),
          ],
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('匯出 ZIP'),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: t.bgChip,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: t.fgMute),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜尋標題或全文…',
                hintStyle: TextStyle(color: t.fgMute, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(fontSize: 14, color: t.fg),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _FilterPill({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? t.accent : t.bgChip,
            border: Border.all(
              color: on ? Colors.transparent : t.line,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: on ? t.accentInk : t.fgDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayGroupTitle extends StatelessWidget {
  final String label;
  const _DayGroupTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: serifItalic(size: 28, color: t.fg)),
    );
  }
}

class _RecRow extends StatelessWidget {
  final TranscriptRecord record;
  final bool highlight;

  const _RecRow({required this.record, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = record.createdAt;
    final duration = Duration(seconds: record.durationSeconds);
    final durationStr =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final preview = record.organizedText.isNotEmpty
        ? record.organizedText
        : record.rawText;

    return Material(
      color: highlight ? t.accent.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HistoryDetailScreen(record: record),
          ),
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  time,
                  style: mono(size: 13, color: t.fgDim),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: t.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.fgDim,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Text(
                durationStr,
                style: mono(size: 12, color: t.fgMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: t.fgMute),
          const SizedBox(height: 14),
          Text(
            '沒有符合的紀錄',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.fgDim,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '試試其他篩選或關鍵字。',
            style: TextStyle(fontSize: 13, color: t.fgMute, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: t.danger),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.fg)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}
