// The search field: bare text inside the frosted search popover.

import 'package:flutter/material.dart';
import 'package:margo/core/icons/phosphor_icons_regular.dart';

import '../../../../core/theme/app_colors.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search..',
    this.autofocus = false,
  });

  /// Optional external controller. When omitted the widget owns one.
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;

  static const height = 32.0;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  TextEditingController? _owned;
  late bool _hasText;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final hasText = value.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    widget.onChanged?.call(value);
  }

  void _clear() {
    _controller.clear();
    _handleChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const none = InputBorder.none;
    final text = TextStyle(
      fontFamily: 'ModulusPro',
      fontSize: 18,
      color: c.textPrimary,
    );

    // Bare text on the popover's glass (design: no fill, 18px, hint @ 50%).
    // The field grows with the system font size so large text is not clipped.
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(SearchBarWidget.height),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: _handleChanged,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        cursorColor: c.textPrimary,
        style: text,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: widget.hintText,
          hintStyle: text.copyWith(color: c.textPrimary.withValues(alpha: 0.5)),
          contentPadding: EdgeInsets.zero,
          suffixIconConstraints: const BoxConstraints(minWidth: 32),
          suffixIcon: ExcludeSemantics(
            excluding: !_hasText,
            child: IgnorePointer(
              ignoring: !_hasText,
              child: AnimatedOpacity(
                opacity: _hasText ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                  color: c.textPrimary,
                  tooltip: 'Clear search',
                  onPressed: _clear,
                ),
              ),
            ),
          ),
          border: none,
          enabledBorder: none,
          focusedBorder: none,
        ),
      ),
    );
  }
}
