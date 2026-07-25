// Enumerates all supported shape types in InkFlow.
enum ShapeType {
  line,
  arrow,
  circle,
  rectangle,
  triangle,
  polygon,    // generalised N-sided polygon from freehand
  textBox,    // keyboard-input text placed on canvas
  svgImage,   // imported SVG vector graphic
  diamond,    // Excalidraw-style 4-vertex diamond (appended last to preserve Isar enum indices)
}
