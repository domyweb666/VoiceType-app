import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 文字稿（潤飾後）。可編輯；首字加 Instrument Serif italic accent drop cap。
class OrganizedView extends StatefulWidget {
  final String text;
  final int textVersion;
  final bool isOrganizing;
  final String organizingMessage;
  final String? organizingDetail;
  final String emptyMessage;
  final ValueChanged<String>? onTextChanged;

  const OrganizedView({
    super.key,
    required this.text,
    required this.textVersion,
    this.isOrganizing = false,
    this.organizingMessage = '整理文字中...',
    this.organizingDetail,
    this.emptyMessage = '錄完音後 App 會自動潤飾並儲存到歷史。',
    this.onTextChanged,
  });

  @override
  State<OrganizedView> createState() => _OrganizedViewState();
}

class _OrganizedViewState extends State<OrganizedView> {
  late TextEditingController _controller;
  late FocusNode _focus;
  late int _appliedVersion;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focus = FocusNode();
    _appliedVersion = widget.textVersion;
    _controller.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    widget.onTextChanged?.call(_controller.text);
  }

  @override
  void didUpdateWidget(covariant OrganizedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textVersion != _appliedVersion) {
      _appliedVersion = widget.textVersion;
      if (_controller.text != widget.text) {
        _controller.removeListener(_onFieldChanged);
        _controller.value = TextEditingValue(
          text: widget.text,
          selection: TextSelection.collapsed(offset: widget.text.length),
        );
        _controller.addListener(_onFieldChanged);
      }
      return;
    }
    if (!widget.isOrganizing &&
        oldWidget.isOrganizing &&
        _controller.text != widget.text) {
      _controller.removeListener(_onFieldChanged);
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
      _controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onFieldChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (widget.isOrganizing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.organizingMessage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: t.fg,
                  ),
                ),
              ],
            ),
            if (widget.organizingDetail?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                widget.organizingDetail!,
                style: TextStyle(fontSize: 12, height: 1.45, color: t.fgDim),
              ),
            ],
          ],
        ),
      );
    }

    if (widget.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.article_outlined, size: 28, color: t.fgMute),
            const SizedBox(height: 12),
            Text(
              '尚無文字稿',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: t.fgDim,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage,
              style: TextStyle(fontSize: 13, color: t.fgMute, height: 1.5),
            ),
          ],
        ),
      );
    }

    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      minLines: 8,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      style: TextStyle(fontSize: 16, height: 1.85, color: t.fg),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: '潤飾完成後可在此修改用字與段落…',
        hintStyle: TextStyle(color: t.fgMute),
      ),
    );
  }
}
