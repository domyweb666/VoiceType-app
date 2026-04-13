import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 依錄音 RMS 取樣繪製的橫向波形條（錄音中由 [RecordingProvider.waveformSamples] 驅動）。
class RecordingWaveformBar extends StatelessWidget {
  final List<double> samples;
  final double height;

  const RecordingWaveformBar({
    super.key,
    required this.samples,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        return Container(
          width: w,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLow,
                Color.lerp(
                  scheme.surfaceContainerHighest,
                  scheme.primaryContainer,
                  0.22,
                )!,
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.07),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _WaveformPainter(
                  samples: samples,
                  scheme: scheme,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.scheme,
  });

  final List<double> samples;
  final ColorScheme scheme;

  static const int _targetBars = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final softBg = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.5),
        size.shortestSide * 0.85,
        [
          scheme.primary.withValues(alpha: 0.03),
          Colors.transparent,
        ],
      );
    canvas.drawRect(Offset.zero & size, softBg);

    final midY = size.height / 2;
    final dashPaint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.07)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dashLen = 3.0;
    const gapLen = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, midY), Offset(x + dashLen, midY), dashPaint);
      x += dashLen + gapLen;
    }

    final n = _targetBars;
    const gap = 2.0;
    final barW = (size.width - (n - 1) * gap) / n;
    if (barW <= 0) return;

    final hi = Color.lerp(scheme.primary, scheme.tertiary, 0.35)!;
    final lo = scheme.primary.withValues(alpha: 0.88);

    for (var i = 0; i < n; i++) {
      double v = 0;
      if (samples.isNotEmpty) {
        final t = i / (n - 1).clamp(1, 9999);
        final idx =
            (t * (samples.length - 1)).round().clamp(0, samples.length - 1);
        v = samples[idx].clamp(0.0, 1.0);
      }
      final shaped = math.pow(v, 0.62).toDouble();
      final h = (size.height * 0.14) + shaped * (size.height * 0.72);
      final bx = i * (barW + gap);
      final by = (size.height - h) / 2;
      final rect = Rect.fromLTWH(bx, by, barW, h);
      final r = RRect.fromRectAndRadius(
        rect,
        Radius.circular(barW / 2),
      );

      final barPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(bx, by),
          Offset(bx, by + h),
          [
            Color.lerp(
              scheme.surfaceContainerHighest,
              hi,
              0.35 + shaped * 0.65,
            )!,
            Color.lerp(lo, hi, 0.25 + shaped * 0.55)!,
          ],
        );
      canvas.drawRRect(r, barPaint);

      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.22 + shaped * 0.28);
      canvas.drawRRect(r.deflate(0.4), rim);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    if (oldDelegate.scheme.primary != scheme.primary ||
        oldDelegate.scheme.tertiary != scheme.tertiary ||
        oldDelegate.scheme.surfaceContainerHighest !=
            scheme.surfaceContainerHighest) {
      return true;
    }
    if (oldDelegate.samples.length != samples.length) return true;
    if (identical(oldDelegate.samples, samples)) return false;
    for (var i = 0; i < samples.length; i++) {
      if ((oldDelegate.samples[i] - samples[i]).abs() > 0.02) return true;
    }
    return false;
  }
}
