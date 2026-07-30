// The token layer's plumbing: carries an [InkPalette] on the ThemeData so that
// every widget resolves its colours from the theme rather than from a `const`.
//
// This is what makes dark mode possible at all. A `static const Color` cannot
// vary by [Brightness], so widgets that read one bypass the theme entirely and
// stay light no matter what ThemeData is supplied. Reading through
// `context.ink` puts them back under the theme's control.
//
// Usage:
//   context.ink.accent          — brand + surface + status roles
//   context.notes.card          — the notes browser's own cool group
//   Theme.of(context).colorScheme.primary — standard M3 roles, also available
//
// The extension is a thin wrapper around the palette rather than a flat copy of
// its forty-odd fields, so adding a role means editing one file, not three.

import 'package:flutter/material.dart';

import 'ink_palette.dart';

// Re-exported so a widget that needs to name the type — a CustomPainter taking
// an [InkPalette] parameter, say — needs only this one import.
export 'ink_palette.dart';

@immutable
class InkColors extends ThemeExtension<InkColors> {
  final InkPalette palette;

  const InkColors(this.palette);

  static const InkColors light = InkColors(InkPalette.light);
  static const InkColors dark = InkColors(InkPalette.dark);

  @override
  InkColors copyWith({InkPalette? palette}) => InkColors(palette ?? this.palette);

  @override
  InkColors lerp(ThemeExtension<InkColors>? other, double t) {
    if (other is! InkColors) return this;
    return InkColors(InkPalette.lerp(palette, other.palette, t));
  }
}

extension ThemeContext on BuildContext {
  /// The app's chrome colours for the current brightness.
  ///
  /// Falls back to the light palette if the extension is somehow absent, so a
  /// call site never crashes on a half-configured theme (a bare `MaterialApp`
  /// in a widget test, for instance).
  InkPalette get ink => Theme.of(this).extension<InkColors>()?.palette ?? InkPalette.light;

  /// The notes browser's colour group — shorthand for `context.ink.notes`.
  NotesInk get notes => ink.notes;
}
