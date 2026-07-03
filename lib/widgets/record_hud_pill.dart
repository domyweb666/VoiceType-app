import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'record_button.dart';

/// 浮動膠囊式錄音 HUD（Variant A）。
/// idle：純圓鈕；recording：展開為膠囊（脈動 stop + 計時器 + 波形 + 停止字按鈕）。
class RecordHUDPill extends StatelessWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onToggle;

  /// 計時格式化字串，例如 "00:42"。
  final String elapsed;

  /// 即時波形樣本（0..1）。
  final List<double> waveformSamples;

  const RecordHUDPill({
    super.key,
    required this.isRecording,
    required this.enabled,
    required this.onToggle,
    required this.elapsed,
    required this.waveformSamples,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (!isRecording) {
      // Idle: 只露出 mic FAB（56px）。
      return RecordButton(
        isRecording: false,
        enabled: enabled,
        onTap: onToggle,
        size: 56,
      );
    }

    final samples = _padSamples(waveformSamples, 34);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.bgElev.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.lineStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: -20,
          ),
          BoxShadow(
            color: t.accent.withValues(alpha: 0.12),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 紅色脈動 stop 鈕 (40)
          _StopMicDot(onTap: onToggle),
          const SizedBox(width: 10),
          // 計時器（mono tabular）
          Text(
            elapsed,
            style: mono(size: 15, color: t.fg, weight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          // 波形
          SizedBox(
            width: 180,
            height: 28,
            child: _LiveWaveform(samples: samples, color: t.accent),
          ),
          const SizedBox(width: 10),
          // 文字停止按鈕
          OutlinedButton(
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const StadiumBorder(),
              side: BorderSide(color: t.lineStrong),
              foregroundColor: t.fg,
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 12.5),
            ),
            child: const Text('停止'),
          ),
        ],
      ),
    );
  }

  static List<double> _padSamples(List<double> src, int n) {
    if (src.length >= n) {
      return src.sublist(src.length - n);
    }
    return [
      ...List<double>.filled(n - src.length, 0.12),
      ...src,
    ];
  }
}

class _StopMicDot extends StatefulWidget {
  final VoidCallback onTap;
  const _StopMicDot({required this.onTap});

  @override
  State<_StopMicDot> createState() => _StopMicDotState();
}

class _StopMicDotState extends State<_StopMicDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final spread = 4 + 8 * _ctrl.value;
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.danger,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: t.dangerGlow.withValues(alpha: 0.6 - 0.4 * _ctrl.value),
                  blurRadius: 0,
                  spreadRadius: spread,
                ),
              ],
            ),
            child: const Icon(
              Icons.stop_rounded,
              color: Color(0xFF2A0808),
              size: 18,
            ),
          );
        },
      ),
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  final List<double> samples;
  final Color color;
  const _LiveWaveform({required this.samples, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: samples.map((v) {
            final clamped = v.clamp(0.08, 1.0);
            return Container(
              width: 3,
              height: h * clamped,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
