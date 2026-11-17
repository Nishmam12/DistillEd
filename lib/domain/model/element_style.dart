// Styling enums shared by scene shapes (and stored by Isar via @enumerated).
// Append-only — never reorder; the index is persisted.

/// How a shape's interior is filled.
enum FillStyle { hachure, crossHatch, solid }

/// How a shape's outline is stroked.
enum StrokeStyle { solid, dashed, dotted }

/// Corner treatment for box-like shapes.
enum EdgeStyle { sharp, round }

/// Arrowhead decoration at a line/arrow endpoint.
enum Arrowhead { none, triangle, dot, bar }

/// Horizontal text alignment.
enum TextAlignKind { left, center, right }

/// Which pen drew a freehand stroke, which decides how it looks. Stored by
/// position like the enums above, so append-only: a stroke saved before this
/// existed reads back as index 0, [ballpoint], which is how it always drew.
enum PenKind {
  /// Smooth ink with moderate pressure response. The original pen.
  ballpoint,

  /// Wide, see-through, constant width: marks over writing without hiding it.
  highlighter,

  /// Strong thick-thin from pressure (or speed, without a pressure pen).
  fountain,

  /// Grainy, slightly lighter line, like graphite on paper.
  pencil,

  /// Flat felt-tip: one width, nearly opaque, for bold headings and boxes.
  marker,

  /// A broad nib held at 45°: thick on the downstroke, thin across it.
  calligraphy,

  /// Wide, light, grainy pencil whose width follows pressure: for shading.
  shading,
}
