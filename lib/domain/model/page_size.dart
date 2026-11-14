// The paper a page-mode notebook is laid out on. Stored by index in
// `Notebook.pageSize`, so values are APPEND ONLY.

import 'dart:ui';

enum PageSizeKind {
  /// The shape of the screen the notebook was first opened on: what every
  /// page-mode notebook was before real sizes existed, and still what those
  /// notebooks keep.
  fitScreen,
  a4Portrait,
  a4Landscape,
  letterPortrait,
  letterLandscape,
  widePortrait,
  wideLandscape;

  /// The default for a notebook created now.
  static const PageSizeKind newNotebookDefault = a4Portrait;

  /// The kind stored at [index], or [fitScreen] for anything unknown (a value
  /// written by a newer build).
  static PageSizeKind fromIndex(int index) =>
      index >= 0 && index < values.length ? values[index] : fitScreen;

  /// The page in scene units (1 unit is a logical pixel at 100% zoom, so a
  /// page is its paper size at 96 dpi), or null for [fitScreen].
  Size? get size => switch (this) {
        fitScreen => null,
        a4Portrait => const Size(794, 1123),
        a4Landscape => const Size(1123, 794),
        letterPortrait => const Size(816, 1056),
        letterLandscape => const Size(1056, 816),
        widePortrait => const Size(800, 1280),
        wideLandscape => const Size(1280, 800),
      };

  String get label => switch (this) {
        fitScreen => 'Fit screen',
        a4Portrait => 'A4',
        a4Landscape => 'A4 landscape',
        letterPortrait => 'Letter',
        letterLandscape => 'Letter landscape',
        widePortrait => '16:10',
        wideLandscape => '16:10 landscape',
      };
}
