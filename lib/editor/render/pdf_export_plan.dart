// What a vector PDF export is made from: plain data, so the document itself can
// be built off the UI isolate (`vector_pdf_writer.dart`).
//
// Text layout needs the Flutter engine, which only the UI isolate has, so it is
// done here first: each text box is broken into the lines the canvas breaks it
// into ([planTextBlock]), and the writer only places them.

import 'dart:typed_data';
import 'dart:ui';

import '../../domain/geometry/element_bounds.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/model/template_type.dart';
import 'scene_element_painter.dart';

/// Scene units are logical pixels at 96 dpi; PDF points are 72 to the inch.
const double kPdfPointsPerUnit = 72 / 96;

/// One line of a text box as the canvas lays it out, in scene units.
class PdfTextLine {
  final String text;

  /// Where the line starts and its baseline.
  final double left;
  final double baseline;

  /// How wide the canvas draws it; the PDF stretches its own font to match, so
  /// alignment and wrapping stay where they were.
  final double width;

  const PdfTextLine({
    required this.text,
    required this.left,
    required this.baseline,
    required this.width,
  });
}

/// A text box laid out into lines.
class PdfTextBlock {
  final List<PdfTextLine> lines;
  final double fontSize;
  final int color;
  final double opacity;
  final bool bold;
  final bool italic;
  final double rotation;

  /// What the box turns about.
  final Offset centre;

  const PdfTextBlock({
    required this.lines,
    required this.fontSize,
    required this.color,
    required this.opacity,
    required this.bold,
    required this.italic,
    required this.rotation,
    required this.centre,
  });
}

/// Text placed over a rectangle and never drawn: what makes handwriting and
/// the words of a page picture searchable and selectable in the PDF.
class PdfHiddenText {
  final String text;

  /// Scene units.
  final Rect rect;

  const PdfHiddenText(this.text, this.rect);
}

/// A text box drawn as a picture (text the PDF fonts cannot shape, such as
/// Bangla), with its text laid invisibly over it.
class PdfRasterText {
  final Uint8List png;
  final Rect rect;

  const PdfRasterText(this.png, this.rect);
}

/// One page of the PDF.
class PdfPagePlan {
  /// The part of the scene that becomes the page, in scene units.
  final Rect sheet;

  /// [sheet] is a real paper size (A4, Letter…), not a box round the content.
  final bool bounded;

  final int background;
  final TemplateType template;

  /// In paint order is not required: the writer sorts by z-order.
  final List<SceneElement> elements;

  /// Laid-out text, by element id.
  final Map<String, PdfTextBlock> texts;

  /// Text boxes drawn as pictures instead, by element id.
  final Map<String, PdfRasterText> rasterTexts;

  final List<PdfHiddenText> hidden;

  const PdfPagePlan({
    required this.sheet,
    required this.bounded,
    required this.background,
    required this.template,
    required this.elements,
    this.texts = const {},
    this.rasterTexts = const {},
    this.hidden = const [],
  });
}

/// Everything the writer needs.
class PdfExportJob {
  final List<PdfPagePlan> pages;

  /// Picture bytes, by relative image path.
  final Map<String, Uint8List> images;

  final Uint8List regularFont;
  final Uint8List boldFont;
  final Uint8List bengaliFont;

  /// False in tests, so the content can be read back.
  final bool compress;

  const PdfExportJob({
    required this.pages,
    required this.images,
    required this.regularFont,
    required this.boldFont,
    required this.bengaliFont,
    this.compress = true,
  });
}

/// Whether [text] has Bangla in it, which the PDF fonts cannot shape.
bool needsShaping(String text) =>
    text.runes.any((r) => r >= 0x0980 && r <= 0x09FF);

/// Lays [t] out as the canvas does (same wrapping, same alignment), resolving
/// a text bound inside a shape through [byId]. Null for empty text. Needs the
/// UI isolate.
PdfTextBlock? planTextBlock(TextElement t, Map<String, SceneElement> byId) {
  if (t.text.isEmpty) return null;
  var rect = _rect(t.geometryData);
  final container = t.containerId.isEmpty ? null : byId[t.containerId];
  final bound = container is SceneShapeElement;
  if (bound) rect = ElementBounds.of(container);

  final para = SceneElementPainter.layOutText(t, rect.width);
  final dy = bound ? rect.top + (rect.height - para.height) / 2 : rect.top;
  final lines = <PdfTextLine>[];
  for (final m in para.computeLineMetrics()) {
    final pos = para.getPositionForOffset(Offset(m.left + 1, m.baseline - 1));
    final range = para.getLineBoundary(pos);
    final text = t.text.substring(range.start, range.end).trimRight();
    if (text.isEmpty) continue;
    lines.add(PdfTextLine(
      text: text,
      left: rect.left + m.left,
      baseline: dy + m.baseline,
      width: m.width,
    ));
  }
  para.dispose();
  return PdfTextBlock(
    lines: lines,
    fontSize: t.fontSize,
    color: t.color,
    opacity: t.opacity,
    bold: t.isBold,
    italic: t.isItalic,
    rotation: t.rotation,
    centre: rect.center,
  );
}

Rect _rect(List<double> g) => g.length < 4
    ? Rect.zero
    : Rect.fromLTRB(
        g[0] < g[2] ? g[0] : g[2],
        g[1] < g[3] ? g[1] : g[3],
        g[0] < g[2] ? g[2] : g[0],
        g[1] < g[3] ? g[3] : g[1],
      );
