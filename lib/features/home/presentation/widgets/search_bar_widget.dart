// The Notes list's search field.
//
// Styled from NotesPalette rather than the app-wide InputDecorationTheme: the
// browser is a cool, paper-white screen and would otherwise inherit the warm
// cream field used everywhere else.

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
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
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // HOME-04. Fully rounded pill. The radius is half the bar's height rather
    // than a magic number, so the ends stay perfectly semicircular if the
    // height ever changes.
    const radius =
        BorderRadius.all(Radius.circular(NotesPalette.searchBarHeight / 2));

    // The one asymmetry: NO outline in light, a 1px `border` hairline in dark.
    // On the light canvas the fill alone is a strong enough edge; on near-black
    // a `surfaceSubtle` fill against `bgPrimary` is only a few percent apart and
    // the field would have no discernible boundary at all.
    final resting = OutlineInputBorder(
      borderRadius: radius,
      borderSide: isDark ? BorderSide(color: c.border) : BorderSide.none,
    );

    return SizedBox(
      height: NotesPalette.searchBarHeight,
      child: TextField(
        controller: _controller,
        onChanged: _handleChanged,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        cursorColor: c.accent,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          color: c.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.surfaceSubtle,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            color: c.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          // Single-instance chrome glyph — accent, unlike the clear button,
          // which is a transient control and stays secondary.
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 22,
            color: c.accent,
          ),
          suffixIcon: IgnorePointer(
            ignoring: !_hasText,
            child: AnimatedOpacity(
              opacity: _hasText ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: IconButton(
                icon: const Icon(PhosphorIconsRegular.x, size: 18),
                color: c.textSecondary,
                tooltip: 'Clear search',
                onPressed: _clear,
              ),
            ),
          ),
          border: resting,
          enabledBorder: resting,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: c.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}
