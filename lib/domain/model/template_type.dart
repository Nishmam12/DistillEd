// The canvas background templates a notebook can use. Persisted by position
// (Notebook.templateIndex), so values are only ever appended.

enum TemplateType {
  blank(displayName: 'Blank'),
  ruled(displayName: 'Ruled'),
  dotted(displayName: 'Dotted'),
  grid(displayName: 'Grid'),
  engineeringGrid(displayName: 'Engineering'),
  cornell(displayName: 'Cornell'),
  music(displayName: 'Music'),
  isometric(displayName: 'Isometric'),
  checklist(displayName: 'Checklist'),
  // Phase 8: ruled, grid and dotted in a narrow and a wide spacing (the ones
  // above are medium), and two planners. Pickers show the spacings as a
  // choice under their pattern, not as patterns of their own.
  ruledNarrow(displayName: 'Ruled'),
  ruledWide(displayName: 'Ruled'),
  gridSmall(displayName: 'Grid'),
  gridLarge(displayName: 'Grid'),
  dottedSmall(displayName: 'Dotted'),
  dottedLarge(displayName: 'Dotted'),
  weeklyPlanner(displayName: 'Week'),
  monthlyPlanner(displayName: 'Month');

  const TemplateType({required this.displayName});

  final String displayName;

  /// The pattern this is a spacing of (ruledNarrow → ruled); itself otherwise.
  TemplateType get family => switch (this) {
        ruledNarrow || ruledWide => ruled,
        gridSmall || gridLarge => grid,
        dottedSmall || dottedLarge => dotted,
        _ => this,
      };

  /// Whether the pattern comes in spacings (ruled, grid, dotted).
  bool get hasSpacings => const {ruled, grid, dotted}.contains(family);

  TemplateSpacing get spacing => switch (this) {
        ruledNarrow || gridSmall || dottedSmall => TemplateSpacing.narrow,
        ruledWide || gridLarge || dottedLarge => TemplateSpacing.wide,
        _ => TemplateSpacing.medium,
      };

  /// This pattern in [spacing]; unchanged for one without spacings.
  TemplateType withSpacing(TemplateSpacing spacing) =>
      switch ((family, spacing)) {
        (ruled, TemplateSpacing.narrow) => ruledNarrow,
        (ruled, TemplateSpacing.wide) => ruledWide,
        (grid, TemplateSpacing.narrow) => gridSmall,
        (grid, TemplateSpacing.wide) => gridLarge,
        (dotted, TemplateSpacing.narrow) => dottedSmall,
        (dotted, TemplateSpacing.wide) => dottedLarge,
        _ => family,
      };

  /// The patterns a picker lists: one per family.
  static List<TemplateType> get pickable =>
      [for (final t in values) if (t.family == t) t];
}

enum TemplateSpacing {
  narrow('Narrow', 0.75),
  medium('Medium', 1.0),
  wide('Wide', 1.5);

  const TemplateSpacing(this.label, this.scale);

  final String label;

  /// Line or dot spacing against the medium one.
  final double scale;
}
