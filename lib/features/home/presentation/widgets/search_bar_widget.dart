// The search field: a green pill (`fieldFill`) used inside the search popover.

import 'package:flutter/material.dart';
import 'package:distill_ed/core/icons/phosphor_icons_regular.dart';

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

  static const height = 40.0;

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
    const radius = BorderRadius.all(
      Radius.circular(SearchBarWidget.height / 2),
    );
    const none = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    final text = TextStyle(
      fontFamily: 'ModulusPro',
      fontSize: 16,
      color: c.textPrimary,
    );

    return SizedBox(
      height: SearchBarWidget.height,
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
          filled: true,
          fillColor: c.fieldFill,
          hintText: widget.hintText,
          // Ink at 60%: the design's white hint on this green is only 2.1:1.
          hintStyle: text.copyWith(color: c.textPrimary.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          suffixIcon: IgnorePointer(
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
          border: none,
          enabledBorder: none,
          focusedBorder: none,
        ),
      ),
    );
  }
}
