import 'package:flutter/material.dart';

class RecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final bool enabled;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.enabled = true,
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
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
    final scheme = Theme.of(context).colorScheme;
    final recordColor = scheme.error;
    final idleColor = scheme.primary;

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
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isRecording ? recordColor : idleColor,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isRecording ? recordColor : idleColor)
                              .withValues(alpha: 0.45),
                          blurRadius: widget.isRecording ? 22 : 14,
                          spreadRadius: widget.isRecording ? 4 : 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: widget.isRecording
                          ? scheme.onError
                          : scheme.onPrimary,
                      size: 40,
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
