// Content colours — ink and paper.
//
// This file used to hold the whole app's design tokens as `static const Color`.
// Those were chrome, and a `const` cannot vary by [Brightness], so every widget
// that read one bypassed the theme and stayed light no matter what ThemeData
// was supplied. They now live in `core/theme/ink_palette.dart` and are reached
// through `context.ink`.
//
// What remains is deliberately still `const`, because it is *not* chrome:
//
//   Pen ink and paper are content, chosen by the user, and are never remapped
//   by the app theme. A stroke drawn in #33302E stays #33302E in dark mode; a
//   page set to Cream stays Cream. Only the app shell — bars, sheets, dialogs,
//   the notes library — follows the theme.
//
// Two consequences worth keeping in mind before "fixing" this:
//
//   * An exported PNG/SVG/PDF is deterministic. What you drew is what you
//     export, in any theme. Theme-mapping the canvas would make a document's
//     colours depend on the viewer's settings.
//   * A user who draws light ink on light paper has made a choice the app does
//     not silently override. They fix it by changing ink or paper.
//
// The user controls the canvas's own brightness by choosing a dark paper, which
// is a first-class option in the Background sheet — not by flipping the app
// theme.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// The canonical ink set: identical in both brightnesses, by design.
  ///
  /// Not currently read anywhere — the editor's swatch picker carries its own
  /// list in `core/constants/editor_constants.dart`. Kept as the documented
  /// reference for what "ink" means here.
  static const penPalette = <Color>[
    Color(0xFF33302E), // ink
    Color(0xFFD9654E), // coral
    Color(0xFFF2802E), // sunny
    Color(0xFFE3A53D), // honey
    Color(0xFF5BA672), // leaf
    Color(0xFF3FA6A0), // teal
    Color(0xFF8B8BD8), // periwinkle
    Color(0xFFC0497E), // berry
    Color(0xFF5B9BD5), // sky
    Color(0xFFFFFFFF), // white
  ];

  // ── Paper (canvas backgrounds) ─────────────────────────────
  static const paperWhite = Color(0xFFFFFFFF);
  static const paperCream = Color(0xFFFAF4EA);
  static const paperBlush = Color(0xFFFBEFEA);
}
