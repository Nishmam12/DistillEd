// Layout metrics for the Notes list screen (UI v3.0).
//
// The browser's *colours* used to live here too, as a separate cool palette
// that could not follow the app theme. They now come from the same navy/gold
// tokens as every other screen, read with `context.colors`. Only the layout
// metrics remain in this file.
//
// Metrics stay here because they do not vary by brightness, and because the
// list's geometry is genuinely its own concern.

import 'package:flutter/material.dart';

class NotesPalette {
  NotesPalette._();

  /// Outer radius of a note card.
  static const cardRadius = 22.0;

  /// Resting card height. Responsive callers clamp within 150–170.
  static const cardHeight = 160.0;
  static const cardHeightMin = 150.0;
  static const cardHeightMax = 170.0;

  /// Share of the card width taken by the frosted overlay (spec: 30–35%).
  static const overlayWidthFactor = 0.34;

  /// Blur applied by the overlay's BackdropFilter.
  static const overlayBlurSigma = 8.0;

  /// Radius of the floating knowledge-graph button.
  static const graphButtonRadius = 26.0;

  static const listPadding = EdgeInsets.fromLTRB(18, 20, 18, 120);
  static const cardGap = 16.0;
  static const searchBarHeight = 52.0;
}
