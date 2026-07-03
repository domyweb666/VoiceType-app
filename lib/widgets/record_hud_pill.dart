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
      // 左內距 10（原 14）補償 stop 鈕 48 觸控框左側多出的 4px，維持圓點視覺位置。
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
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
          // 紅色脈動 stop 鈕 (40 視覺 / 48 觸控框)
          _StopMicDot(onTap: onToggle),
          // 6（原 10）補償 stop 鈕觸控框右側多出的 4px。
          const SizedBox(width: 6),
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
    // Semantics 標記為按鈕，並用 48x48 的透明點擊區包住 40 的視覺圓點，
    // 滿足最小觸控目標，但不改變圓點本身的視覺大小。
    return Semantics(
      button: true,
      label: '停止錄音',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
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
                        color: t.dangerGlow
                            .withValues(alpha: 0.6 - 0.4 * _ctrl.value),
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
          ),
        ),
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
    // 用單一 CustomPaint 一次畫完所有 bar，避免每個動畫 tick 重建 34 個 Container。
    return CustomPaint(
      size: Size.infinite,
      painter: _LiveWaveformPainter(samples: samples, color: color),
    );
  }
}

/// 一次 paint 畫完所有波形 bar，視覺結果與原本的 Row-of-Containers 相同
/// （同樣寬 3、圓角 2、spaceBetween 排列、高度由 sample 值驅動）。
class _LiveWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _LiveWaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    const barW = 3.0;
    final n = samples.length;
    final h = size.height;

    // 對應原本 Row 的 spaceBetween：頭尾各一根 bar 貼齊左右緣，中間均分間距。
    final step = n > 1 ? (size.width - barW) / (n - 1) : 0.0;

    final paint = Paint()..color = color.withValues(alpha: 0.85);

    for (var i = 0; i < n; i++) {
      final clamped = samples[i].clamp(0.08, 1.0);
      final barH = h * clamped;
      final left = n > 1 ? i * step : (size.width - barW) / 2;
      final top = (h - barH) / 2; // crossAxisAlignment.center：垂直置中
      final rect = Rect.fromLTWH(left, top, barW, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.samples.length != samples.length) return true;
    if (identical(oldDelegate.samples, samples)) return false;
    for (var i = 0; i < samples.length; i++) {
      if (oldDelegate.samples[i] != samples[i]) return true;
    }
    return false;
  }
}
