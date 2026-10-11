// Window-size classes — the one place the app decides "phone-like" vs
// "tablet-like", so every screen adapts at the same widths.
//
// Follows Material 3's width breakpoints, measured on the *window* (not the
// device), so it is right for split-screen, foldables unfolding, freeform
// windows and rotation without any per-device logic:
//
//   compact   < 600 dp   most phones in portrait, a foldable's cover screen
//   medium    600–839    small tablets, unfolded foldables, phones in landscape
//   expanded  ≥ 840      tablets, large landscape layouts
//
// Read it with `context.windowSize` (rebuilds on resize via MediaQuery).

import 'package:flutter/widgets.dart';

enum WindowSize {
  compact,
  medium,
  expanded;

  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 840.0;

  static WindowSize ofWidth(double width) {
    if (width < mediumBreakpoint) return WindowSize.compact;
    if (width < expandedBreakpoint) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => this == WindowSize.compact;
  bool get isExpanded => this == WindowSize.expanded;
}

extension WindowSizeContext on BuildContext {
  /// The window's size class. Rebuilds the caller when the window resizes.
  WindowSize get windowSize =>
      WindowSize.ofWidth(MediaQuery.sizeOf(this).width);
}
