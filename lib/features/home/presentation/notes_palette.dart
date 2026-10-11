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
  static const gridGap = 32.0;

  /// Gutter on compact windows (phones), tighter than [gridGap].
  static const compactGap = 20.0;

  /// Radius of the floating knowledge-graph button.
  static const graphButtonRadius = 26.0;

  /// Sidebar width bounds. The design's 350 of 1280 is ~27% of the window;
  /// clamped so it never crowds the grid on a 840 dp window or sprawls on a
  /// 1480 dp one. Below the expanded window size it is a drawer instead.
  static const sidebarMinWidth = 264.0;
  static const sidebarMaxWidth = 340.0;
  static const sidebarFraction = 0.27;

  static double sidebarWidthFor(double windowWidth) =>
      (windowWidth * sidebarFraction).clamp(sidebarMinWidth, sidebarMaxWidth);

  static const contentPadding = EdgeInsets.fromLTRB(32, 0, 32, 120);
  static const compactContentPadding = EdgeInsets.fromLTRB(20, 0, 20, 120);
  static const searchPopoverWidth = 300.0;
}
