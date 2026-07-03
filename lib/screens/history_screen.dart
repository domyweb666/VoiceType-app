import 'dart:async';

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

  /// 已套用的搜尋關鍵字（去頭尾空白並轉小寫）；輸入防抖後才更新。
  String _activeQuery = '';
  Timer? _searchDebounce;

  /// 依 record id 快取的「可搜尋文字」（標題＋原文＋潤飾稿，全部小寫）。
  /// 只在 records 清單本身改變時重建，避免每次按鍵重複 toLowerCase。
  final Map<String, String> _searchIndex = {};
  List<TranscriptRecord>? _indexedRecords;

  /// 使用者已手動關閉的重新載入錯誤橫幅（同一則錯誤只提示一次）。
  String? _dismissedLoadError;

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
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 搜尋框輸入變更：延遲約 250ms 才套用，避免每次按鍵都重掃全清單。
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final q = _searchController.text.trim().toLowerCase();
      if (q == _activeQuery) return;
      setState(() => _activeQuery = q);
    });
  }

  /// 確保 [_searchIndex] 與目前 records 同步（清單身分改變時才重建）。
  void _ensureSearchIndex(List<TranscriptRecord> records) {
    if (identical(_indexedRecords, records)) return;
    _searchIndex.clear();
    for (final r in records) {
      _searchIndex[r.id] =
          '${r.title}\n${r.rawText}\n${r.organizedText}'.toLowerCase();
    }
    _indexedRecords = records;
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
    final q = _activeQuery;
    if (q.isNotEmpty) {
      // 以預先建好的小寫索引比對；語意與原本三欄位 OR 相同。
      list = list.where((r) {
        final indexed = _searchIndex[r.id];
        return indexed != null && indexed.contains(q);
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
    _ensureSearchIndex(history.records);
    final visible = _filtered(history.records);
    _tryScrollToTarget(visible);

    // 是否需顯示「重新載入失敗但仍有舊資料」的橫幅。
    final reloadError =
        (history.loadError != null && history.records.isNotEmpty)
            ? history.loadError
            : null;
    final showReloadBanner =
        reloadError != null && reloadError != _dismissedLoadError;

    // 攤平成一維清單，供 ListView.builder 惰性建立列（不再一次建好整棵 Column）。
    final content = <Widget>[
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
        onChanged: _onSearchChanged,
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
            onTap: () =>
                setState(() => _dateFilter = _HistoryDateFilter.all),
          ),
          _FilterPill(
            label: '今天',
            on: _dateFilter == _HistoryDateFilter.today,
            onTap: () =>
                setState(() => _dateFilter = _HistoryDateFilter.today),
          ),
          _FilterPill(
            label: '本週',
            on: _dateFilter == _HistoryDateFilter.week,
            onTap: () =>
                setState(() => _dateFilter = _HistoryDateFilter.week),
          ),
          _FilterPill(
            label: '本月',
            on: _dateFilter == _HistoryDateFilter.month,
            onTap: () =>
                setState(() => _dateFilter = _HistoryDateFilter.month),
          ),
        ],
      ),
      if (showReloadBanner) ...[
        const SizedBox(height: 14),
        _ReloadErrorBanner(
          message: reloadError,
          onRetry: () => context.read<HistoryProvider>().loadRecords(),
          onDismiss: () =>
              setState(() => _dismissedLoadError = reloadError),
        ),
      ],
      const SizedBox(height: 24),
    ];

    if (visible.isEmpty) {
      content.add(_EmptyHistory());
    } else {
      for (final g in _groupByDay(visible).entries) {
        content.add(_DayGroupTitle(label: g.key));
        for (final rec in g.value) {
          content.add(_RecRow(
            record: rec,
            highlight: widget.scrollToRecordId == rec.id,
          ));
        }
        content.add(const SizedBox(height: 22));
      }
    }

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
            : Center(
                child: ConstrainedBox(
                  // 置中並限制最大寬度，維持原本 960px 的版面。
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      widget.embedded ? 48 : 24,
                      24,
                      widget.embedded ? 48 : 24,
                      120,
                    ),
                    itemCount: content.length,
                    // 惰性建列：ListView 本身寬度已受 960 約束，
                    // 各列在此寬度下自然填滿，等同原本 stretch 版面。
                    itemBuilder: (context, i) => content[i],
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

/// 重新載入失敗、但仍有舊資料時顯示的可關閉橫幅。
/// 讓使用者知道「這次刷新沒成功、看到的是舊清單」，但不擋住既有內容。
class _ReloadErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ReloadErrorBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.10),
        border: Border.all(color: t.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: t.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '重新載入失敗，顯示的是先前的紀錄。',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: t.fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(fontSize: 12.5, color: t.fgDim, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onRetry,
            child: const Text('重試'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: '關閉',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
