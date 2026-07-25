// The Notes list's search field.
//
// Styled from NotesPalette rather than the app-wide InputDecorationTheme: the
// browser is a cool, paper-white screen and would otherwise inherit the warm
// cream field used everywhere else.

import 'package:flutter/material.dart';

import '../notes_palette.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search',
  });

  /// Optional external controller. When omitted the widget owns one.
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String hintText;

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
    const radius = BorderRadius.all(Radius.circular(16));
    const border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );

    return SizedBox(
      height: NotesPalette.searchBarHeight,
      child: TextField(
        controller: _controller,
        onChanged: _handleChanged,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        cursorColor: NotesPalette.accent,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          color: NotesPalette.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: NotesPalette.field,
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            color: NotesPalette.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 22,
            color: NotesPalette.textSecondary,
          ),
          suffixIcon: IgnorePointer(
            ignoring: !_hasText,
            child: AnimatedOpacity(
              opacity: _hasText ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: NotesPalette.textSecondary,
                tooltip: 'Clear search',
                onPressed: _clear,
              ),
            ),
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: NotesPalette.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}
