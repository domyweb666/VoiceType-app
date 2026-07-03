import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 圓形麥克風／停止按鈕。可變尺寸；錄音中會脈動 + 紅色。
class RecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.enabled = true,
    this.size = 72,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRecording) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final iconSize = widget.size * 0.42;

    return Tooltip(
      message: widget.isRecording ? '停止錄音' : '開始錄音',
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.isRecording ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.enabled ? widget.onTap : null,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isRecording ? t.danger : t.accent,
                      boxShadow: [
                        BoxShadow(
                          color: widget.isRecording
                              ? t.dangerGlow
                              : t.accentGlow,
                          blurRadius: widget.isRecording ? 24 : 18,
                          spreadRadius: widget.isRecording ? 4 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: t.lineStrong, width: 1),
                    ),
                    child: Icon(
                      widget.isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: widget.isRecording
                          ? const Color(0xFF2A0808)
                          : t.accentInk,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
