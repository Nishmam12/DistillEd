// Layout metrics for the Notes screen (margo redesign).
//
// The browser's *colours* come from the sage tokens, read with `context.colors`.
// Only layout metrics live here: they do not vary by brightness, and the grid's
// geometry is genuinely this screen's own concern. Values are the Figma
// frame's, at 1280×800.

import 'package:flutter/material.dart';

class NotesPalette {
  NotesPalette._();

  /// Outer radius of a note card.
  static const cardRadius = 20.0;

  /// Card proportions: 252×198 thumbnail over a 98px footer.
  static const cardWidth = 252.0;
  static const cardHeight = 296.0;
  static const cardAspect = cardWidth / cardHeight;

  /// Narrowest a card may get before the grid drops a column.
  static const cardMinWidth = 176.0;
  static const gridGap = 32.0;

  /// Below this width the grid tightens its gutters (phones).
  static const compactWidth = 600.0;
  static const compactGap = 20.0;

  /// Radius of the floating knowledge-graph button.
  static const graphButtonRadius = 26.0;

  /// Sidebar width on a tablet-class screen (design: 350 of 1280).
  static const sidebarWidth = 320.0;

  /// Width at and above which the sidebar is pinned beside the grid; below it
  /// the sidebar opens as a drawer.
  static const sidebarBreakpoint = 900.0;

  static const contentPadding = EdgeInsets.fromLTRB(32, 0, 32, 120);
  static const compactContentPadding = EdgeInsets.fromLTRB(20, 0, 20, 120);
  static const searchPopoverWidth = 300.0;
}
