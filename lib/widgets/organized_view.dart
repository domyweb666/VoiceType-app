import 'package:flutter/material.dart';

class OrganizedView extends StatefulWidget {
  final String text;
  /// 由 [TranscriptionProvider] 在 API 產出／清除時遞增；與 [text] 一併用於同步編輯框。
  final int textVersion;
  final bool isOrganizing;
  final String organizingMessage;
  /// 潤飾中額外說明（例如步驟 2/2）。
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
    this.emptyMessage = '錄完音後按「整理」按鈕',
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.isOrganizing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.organizingMessage,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.organizingDetail != null &&
                  widget.organizingDetail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.organizingDetail!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final showEmptyHint = widget.text.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showEmptyHint) ...[
            Icon(
              Icons.article_outlined,
              size: 40,
              color: scheme.primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 8),
            Text(
              '尚無文字稿',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                minLines: showEmptyHint ? 8 : 10,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.85,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '潤飾完成後可在此修改用字與段落…',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
