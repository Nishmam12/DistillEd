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
  checklist(displayName: 'Checklist');

  const TemplateType({required this.displayName});

  final String displayName;
}
