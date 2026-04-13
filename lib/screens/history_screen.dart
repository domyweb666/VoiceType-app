import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transcript_record.dart';
import '../providers/history_provider.dart';
import '../services/export_service.dart';
import 'history_detail_screen.dart';
import 'record_calendar_screen.dart';

enum _HistoryDateFilter { all, today, week, month }

class HistoryScreen extends StatefulWidget {
  /// 開啟後捲動並微幅標示該筆（例如從首頁「查看歷史」）。
  final String? scrollToRecordId;

  const HistoryScreen({super.key, this.scrollToRecordId});

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

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final visible = _filtered(history.records);
    _tryScrollToTarget(visible);

    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史紀錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: '紀錄日曆',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordCalendarScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '匯出',
            onSelected: (v) async {
              if (v == 'zip') await _exportFilteredZip(visible);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'zip',
                child: Text('匯出目前清單為 ZIP（各筆 .md）'),
              ),
            ],
          ),
        ],
      ),
      body: history.isLoading && history.records.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (!history.isLoading &&
                  history.records.isEmpty &&
                  history.loadError != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          history.loadError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              context.read<HistoryProvider>().loadRecords(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重試'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜尋標題或全文…',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('全部'),
                        selected: _dateFilter == _HistoryDateFilter.all,
                        onSelected: (_) =>
                            setState(() => _dateFilter = _HistoryDateFilter.all),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('今天'),
                        selected: _dateFilter == _HistoryDateFilter.today,
                        onSelected: (_) => setState(
                            () => _dateFilter = _HistoryDateFilter.today),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('本週'),
                        selected: _dateFilter == _HistoryDateFilter.week,
                        onSelected: (_) => setState(
                            () => _dateFilter = _HistoryDateFilter.week),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('本月'),
                        selected: _dateFilter == _HistoryDateFilter.month,
                        onSelected: (_) => setState(
                            () => _dateFilter = _HistoryDateFilter.month),
                        showCheckmark: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 56,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.75),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '沒有符合的紀錄',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '試試其他日期篩選，或調整搜尋關鍵字。',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        height: 1.45,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final record = visible[index];
                            final date = record.createdAt;
                            final duration =
                                Duration(seconds: record.durationSeconds);
                            final durationStr =
                                '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
                            final highlight =
                                widget.scrollToRecordId == record.id;

                            return ListTile(
                                tileColor: highlight
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.45)
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                title: Text(
                                  record.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  '${date.year}/${date.month}/${date.day} '
                                  '${date.hour}:${date.minute.toString().padLeft(2, '0')}  ·  $durationStr',
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        HistoryDetailScreen(record: record),
                                  ),
                                ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
