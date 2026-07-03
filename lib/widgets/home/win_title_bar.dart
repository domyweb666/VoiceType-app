import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart' show windowManager, DragToMoveArea;

import '../../config/app_theme.dart';

// ── Windows 自訂標題列（拖移 + 最小化/最大化/關閉）──
class WinTitleBar extends StatelessWidget {
  final Color bg;
  final Color iconColor;
  const WinTitleBar({super.key, required this.bg, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          Positioned.fill(child: DragToMoveArea(child: Container(color: bg))),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleBtn(
                  icon: Icons.remove,
                  color: iconColor,
                  onTap: () => windowManager.minimize(),
                ),
                _TitleBtn(
                  icon: Icons.crop_square_outlined,
                  color: iconColor,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                _TitleBtn(
                  icon: Icons.close,
                  color: iconColor,
                  hoverDanger: true,
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool hoverDanger;
  final VoidCallback onTap;
  const _TitleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.hoverDanger = false,
  });

  @override
  State<_TitleBtn> createState() => _TitleBtnState();
}

class _TitleBtnState extends State<_TitleBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dangerBg = t.danger.withAlpha(200);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 46,
          height: 32,
          color: _hovering
              ? (widget.hoverDanger ? dangerBg : t.line)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: (_hovering && widget.hoverDanger) ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}
