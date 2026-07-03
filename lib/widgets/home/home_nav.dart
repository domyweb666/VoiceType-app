import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/history_provider.dart';

/// HomeScreen view modes（在同一個 Scaffold 裡切換，不再 push routes）。
enum NavView { home, history, settings }

// ─────────────────── SIDEBAR (desktop) ───────────────────

class Sidebar extends StatelessWidget {
  final NavView view;
  final ValueChanged<NavView> onSelect;

  const Sidebar({super.key, required this.view, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.bg,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // brand
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: t.accentGlow, blurRadius: 16, spreadRadius: -8),
                    ],
                  ),
                  child: Text(
                    'V',
                    style: mono(size: 14, color: t.accentInk, weight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'VoiceType',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'β',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: t.fgMute,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _NavSectionTitle('工作區'),
          _NavItem(
            icon: Icons.home_outlined,
            label: '錄音',
            kbd: 'Space',
            active: view == NavView.home,
            onTap: () => onSelect(NavView.home),
          ),
          _NavSectionTitle('資料'),
          _NavItem(
            icon: Icons.history_rounded,
            label: '歷史紀錄',
            kbd: '⌘H',
            active: view == NavView.history,
            onTap: () => onSelect(NavView.history),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: '設定',
            kbd: '⌘,',
            active: view == NavView.settings,
            onTap: () => onSelect(NavView.settings),
          ),
          const Spacer(),
          // status card
          Consumer<HistoryProvider>(
            builder: (context, history, _) {
              final mCount = history.records.length;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.bgChip,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: t.ok,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: t.ok.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '共 $mCount 筆',
                          style: TextStyle(fontSize: 12, color: t.fgDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '本地儲存 · OpenAI 雲端轉錄',
                      style: mono(size: 10.5, color: t.fgMute),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavSectionTitle extends StatelessWidget {
  final String label;
  const _NavSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.5,
          color: t.fgMute,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? kbd;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.kbd,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? t.bgChip : Colors.transparent,
              border: Border.all(
                color: active ? t.lineStrong : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? t.accent : t.fgDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: active ? t.fg : t.fgDim,
                    ),
                  ),
                ),
                if (kbd != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.bgChip,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kbd!,
                      style: mono(size: 10.5, color: t.fgMute),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── RIGHT RAIL (desktop) ───────────────────

class RightRail extends StatelessWidget {
  final NavView view;
  const RightRail({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      color: t.bg,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RailTitle(view == NavView.history ? '本月概況' : '最近'),
            const SizedBox(height: 10),
            if (view == NavView.home)
              Consumer<HistoryProvider>(
                builder: (context, history, _) {
                  final recent = history.records.take(5).toList();
                  if (recent.isEmpty) {
                    return Text(
                      '還沒有任何錄音紀錄。',
                      style: TextStyle(fontSize: 12.5, color: t.fgMute, height: 1.6),
                    );
                  }
                  return Column(
                    children: recent.map((r) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: t.line),
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: t.fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.createdAt.year}/${r.createdAt.month}/${r.createdAt.day} · ${r.durationSeconds}s',
                              style: mono(size: 11.5, color: t.fgMute),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              )
            else
              Consumer<HistoryProvider>(
                builder: (context, history, _) {
                  final n = history.records.length;
                  final totalSec = history.records.fold<int>(
                    0,
                    (s, r) => s + r.durationSeconds,
                  );
                  final mins = (totalSec / 60).round();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StreakRow(label: '總筆數', value: '$n'),
                      _StreakRow(label: '總時長', value: '$mins min'),
                      const SizedBox(height: 12),
                      Text(
                        '篩選結果可用上方搜尋與時間 chip。',
                        style: TextStyle(fontSize: 12, color: t.fgMute, height: 1.55),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RailTitle extends StatelessWidget {
  final String label;
  const _RailTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.5,
        color: t.fgMute,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final String label;
  final String value;
  const _StreakRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: serifItalic(size: 30, color: t.fg)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12.5, color: t.fgDim)),
        ],
      ),
    );
  }
}
