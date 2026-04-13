import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transcript_record.dart';
import '../providers/history_provider.dart';
import 'history_detail_screen.dart';

/// 以 [TranscriptRecord.createdAt] 的「本地日期」為準。
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 活動熱圖「有紀錄」格固定用綠色（不依 primary 色）。
Color _heatmapHasRecordColor(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? const Color(0xFF81C784) : const Color(0xFF388E3C);
}

Map<DateTime, int> _countsByDay(List<TranscriptRecord> records) {
  final map = <DateTime, int>{};
  for (final r in records) {
    final k = _dateOnly(r.createdAt);
    map[k] = (map[k] ?? 0) + 1;
  }
  return map;
}

/// 連續有紀錄天數：自今天起算，今天無則自昨天起算。
bool _dayHasRecord(DateTime day, DateTime today, Map<DateTime, int> counts) {
  final d = _dateOnly(day);
  if (d.isAfter(today)) return false;
  return (counts[d] ?? 0) > 0;
}

int _consecutiveStreak(Map<DateTime, int> counts, DateTime now) {
  final today = _dateOnly(now);
  var d = today;
  if ((counts[d] ?? 0) == 0) {
    d = today.subtract(const Duration(days: 1));
  }
  if ((counts[d] ?? 0) == 0) return 0;
  var n = 0;
  while ((counts[d] ?? 0) > 0) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

class RecordCalendarScreen extends StatefulWidget {
  const RecordCalendarScreen({super.key});

  @override
  State<RecordCalendarScreen> createState() => _RecordCalendarScreenState();
}

class _RecordCalendarScreenState extends State<RecordCalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _focusedMonth = DateTime(n.year, n.month);
    _selectedDay = _dateOnly(n);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HistoryProvider>().loadRecords();
    });
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() => _focusedMonth = next);
  }

  List<TranscriptRecord> _recordsForDay(
    List<TranscriptRecord> all,
    DateTime day,
  ) {
    final k = _dateOnly(day);
    return all.where((r) => _dateOnly(r.createdAt) == k).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _shareSummary({
    required int totalNotes,
    required int activeDays,
    required int streak,
  }) async {
    final text =
        'VoiceType 紀錄總覽\n全部筆數：$totalNotes\n累計天數：$activeDays\n連續天數：$streak';
    await Share.share(text);
  }

  void _openDayRecords(List<TranscriptRecord> dayRecords) {
    if (dayRecords.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '當日紀錄（${dayRecords.length} 筆）',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ),
              ...dayRecords.map(
                (r) => ListTile(
                  title: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${r.createdAt.hour.toString().padLeft(2, '0')}:'
                    '${r.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(record: r),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = context.watch<HistoryProvider>();
    final records = history.records;
    final counts = _countsByDay(records);
    final now = DateTime.now();
    final totalNotes = records.length;
    final activeDays = counts.keys.length;
    final streak = _consecutiveStreak(counts, now);

    final monthCount = records
        .where((r) =>
            r.createdAt.year == _focusedMonth.year &&
            r.createdAt.month == _focusedMonth.month)
        .length;
    final monthActiveDays = counts.keys
        .where((d) => d.year == _focusedMonth.year && d.month == _focusedMonth.month)
        .length;

    final sel = _selectedDay ?? _dateOnly(now);
    final selCount = counts[sel] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('紀錄日曆'),
      ),
      body: history.isLoading && records.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (!history.isLoading &&
                  records.isEmpty &&
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
              : RefreshIndicator(
              onRefresh: () => context.read<HistoryProvider>().loadRecords(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCell(
                                value: '$totalNotes',
                                label: '全部筆數',
                                scheme: scheme,
                              ),
                            ),
                            Expanded(
                              child: _StatCell(
                                value: '$activeDays',
                                label: '累計天數',
                                scheme: scheme,
                              ),
                            ),
                            Expanded(
                              child: _StatCell(
                                value: streak > 0 ? '$streak' : '—',
                                label: '連續天數',
                                scheme: scheme,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '活動熱圖',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: totalNotes == 0
                                      ? null
                                      : () => _shareSummary(
                                            totalNotes: totalNotes,
                                            activeDays: activeDays,
                                            streak: streak,
                                          ),
                                  icon: const Icon(Icons.ios_share_outlined,
                                      size: 18),
                                  label: const Text('分享'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '約近半年；綠色格表示當日至少有一筆紀錄',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: _HeatMapGrid.gridHeight,
                              child: _HeatMapGrid(
                                countsByDay: counts,
                                today: _dateOnly(now),
                                scheme: scheme,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _HeatMapLegend(scheme: scheme),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_focusedMonth.year} 年 ${_focusedMonth.month} 月',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _prevMonth,
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  tooltip: '上個月',
                                ),
                                IconButton(
                                  onPressed: _nextMonth,
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  tooltip: '下個月',
                                ),
                              ],
                            ),
                            Text(
                              '累計 $monthActiveDays 天  ·  $monthCount 筆',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _MonthCalendar(
                              focusedMonth: _focusedMonth,
                              selectedDay: sel,
                              countsByDay: counts,
                              today: _dateOnly(now),
                              scheme: scheme,
                              onSelectDay: (d) => setState(() => _selectedDay = d),
                            ),
                            const SizedBox(height: 12),
                            Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              '${sel.month.toString().padLeft(2, '0')} 月 '
                              '${sel.day.toString().padLeft(2, '0')} 日  ·  '
                              '$selCount 筆',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (selCount > 0) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => _openDayRecords(
                                    _recordsForDay(records, sel),
                                  ),
                                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                                  label: const Text('查看當日紀錄'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.scheme,
  });

  final String value;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _HeatMapGrid extends StatelessWidget {
  const _HeatMapGrid({
    required this.countsByDay,
    required this.today,
    required this.scheme,
  });

  static const double _cell = 12.0;
  static const double _gap = 2.0;

  /// 7 列格子 + 間距總高（與外層 SizedBox 一致，避免版面算錯）。
  static double get gridHeight => 7 * _cell + 6 * _gap;

  final Map<DateTime, int> countsByDay;
  final DateTime today;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const weeksBack = 26;
    final end = today;
    var start = end.subtract(Duration(days: weeksBack * 7 - 1));
    while (start.weekday != DateTime.monday) {
      start = start.subtract(const Duration(days: 1));
    }

    final weeks = <List<DateTime>>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final week = <DateTime>[];
      for (var i = 0; i < 7; i++) {
        week.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    // 固定每格寬高，不依 LayoutBuilder（避免寬度未受限時算出 NaN／整條不畫）。
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var wi = 0; wi < weeks.length; wi++) ...[
              if (wi > 0) SizedBox(width: _gap),
              SizedBox(
                width: _cell,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var di = 0; di < 7; di++) ...[
                      if (di > 0) SizedBox(height: _gap),
                      SizedBox(
                        width: _cell,
                        height: _cell,
                        child: _HeatCell(
                          day: weeks[wi][di],
                          today: today,
                          hasActivity: _dayHasRecord(
                            weeks[wi][di],
                            today,
                            countsByDay,
                          ),
                          scheme: scheme,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.today,
    required this.hasActivity,
    required this.scheme,
  });

  final DateTime day;
  final DateTime today;
  final bool hasActivity;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final d = _dateOnly(day);
    final Color bg;
    if (d.isAfter(today)) {
      bg = scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    } else if (!hasActivity) {
      bg = scheme.surfaceContainerHighest.withValues(alpha: 0.92);
    } else {
      bg = _heatmapHasRecordColor(context);
    }
    final isToday = d == today;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: isToday
            ? Border.all(color: scheme.outline, width: 1.4)
            : Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
                width: 0.5,
              ),
      ),
    );
  }
}

class _HeatMapLegend extends StatelessWidget {
  const _HeatMapLegend({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
    return Row(
      children: [
        Text('無紀錄', style: labelStyle),
        const SizedBox(width: 6),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('有紀錄', style: labelStyle),
        const SizedBox(width: 6),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: _heatmapHasRecordColor(context),
          ),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.countsByDay,
    required this.today,
    required this.scheme,
    required this.onSelectDay,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<DateTime, int> countsByDay;
  final DateTime today;
  final ColorScheme scheme;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedMonth.year, focusedMonth.month);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final lead = first.weekday - 1;

    final cells = <Widget>[];

    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, d);
      final key = _dateOnly(date);
      final n = countsByDay[key] ?? 0;
      final isSel = _dateOnly(selectedDay) == key;
      final isToday = key == today;

      cells.add(
        InkWell(
          onTap: () => onSelectDay(key),
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSel
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: scheme.primary.withValues(alpha: 0.5))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                if (n > 0)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.05,
          children: cells,
        ),
      ],
    );
  }
}
