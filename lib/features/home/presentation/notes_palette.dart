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

  /// Thumbnail height as a fraction of card width (198 / 252).
  static const thumbnailAspect = 198.0 / 252.0;

  /// Narrowest a card may get before the grid drops a column.
  static const cardMinWidth = 176.0;

  /// Design gutters: 47 between columns, 32 between rows.
  static const gridColumnGap = 47.0;
  static const gridRowGap = 32.0;

  /// Gutter on compact windows (phones), tighter than the design's.
  static const compactGap = 20.0;

  /// Radius of the floating knowledge-graph button.
  static const graphButtonRadius = 26.0;

  /// Sidebar width bounds. The design's 350 of 1280 is ~27% of the window;
  /// clamped so it never crowds the grid on a 840 dp window or sprawls on a
  /// 1480 dp one. Below the expanded window size it is a drawer instead.
  static const sidebarMinWidth = 264.0;
  static const sidebarMaxWidth = 350.0;
  static const sidebarFraction = 350.0 / 1280.0;

  static double sidebarWidthFor(double windowWidth) =>
      (windowWidth * sidebarFraction).clamp(sidebarMinWidth, sidebarMaxWidth);

  /// Width of a selected sidebar pill (232 in the design).
  static const sidebarPillWidth = 232.0;

  /// Content sits 35 in from the sidebar and 45 in from the right edge.
  static const contentPadding = EdgeInsets.fromLTRB(35, 0, 45, 120);
  static const compactContentPadding = EdgeInsets.fromLTRB(20, 0, 20, 120);
  static const searchPopoverWidth = 250.0;

  /// The design's soft black lift (cards, sidebar, glass surfaces).
  static const shadowColor = Color(0x40000000);
}
