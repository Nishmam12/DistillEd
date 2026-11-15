// Builds a vector PDF from a [PdfExportJob]: ink, shapes and paper as real
// vector paths, typed text as real text, pictures embedded from their files,
// and invisible text over handwriting and page pictures so the PDF can be
// searched.
//
// Pure Dart with no Flutter engine calls, so it runs in a background isolate
// (`Isolate.run`): a long notebook does not freeze the editor while its PDF is
// put together. Text layout happened before, on the UI isolate
// (`pdf_export_plan.dart`).
//
// Drawing happens in scene units: each page sets one transform from the scene
// (y down, logical pixels) to PDF points (y up), and text and pictures flip
// back locally so they are not upside down.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;
import 'package:pdf/pdf.dart';

import '../../domain/geometry/scene_geometry.dart';
import '../../domain/geometry/shape_geometry.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/services/frame_service.dart';
import 'freehand_path.dart';
import 'pdf_export_plan.dart';
import 'template_painter.dart';

/// How far an italic is slanted: about 11 degrees.
const double _kItalicSlant = 0.2;

Future<Uint8List> writeVectorPdf(PdfExportJob job) =>
    _VectorPdfWriter(job).write();

class _VectorPdfWriter {
  _VectorPdfWriter(this.job)
      : doc = PdfDocument(compress: job.compress) {
    regular = PdfTtfFont(doc, ByteData.sublistView(job.regularFont));
    bold = PdfTtfFont(doc, ByteData.sublistView(job.boldFont));
    bengali = PdfTtfFont(doc, ByteData.sublistView(job.bengaliFont));
  }

  final PdfExportJob job;
  final PdfDocument doc;
  late final PdfTtfFont regular;
  late final PdfTtfFont bold;
  late final PdfTtfFont bengali;

  /// Pictures used on more than one page are embedded once.
  final Map<String, PdfImage?> _images = {};

  Future<Uint8List> write() {
    for (final page in job.pages) {
      _page(page);
    }
    return doc.save();
  }

  // ---- page -------------------------------------------------------------------

  void _page(PdfPagePlan plan) {
    final sheet = plan.sheet;
    final w = sheet.width * kPdfPointsPerUnit;
    final h = sheet.height * kPdfPointsPerUnit;
    final page = PdfPage(doc, pageFormat: PdfPageFormat(w, h));
    final g = page.getGraphics();

    const k = kPdfPointsPerUnit;
    g.setTransform(_affine(k, 0, 0, -k, -sheet.left * k, h + sheet.top * k));

    // Paper, then its pattern.
    g.setFillColor(PdfColor.fromInt(plan.background | 0xFF000000));
    g.drawRect(sheet.left, sheet.top, sheet.width, sheet.height);
    g.fillPath();
    TemplatePainter.emit(_PdfTemplateSink(g), plan.template,
        Color(plan.background),
        region: sheet, bounded: plan.bounded);

    final ordered = [...plan.elements]
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    final clips = ordered.any((e) => e is FrameElement)
        ? FrameService.clipBoundsByElement(ordered)
        : const <String, Rect>{};
    for (final e in ordered) {
      final clip = clips[e.id];
      g.saveContext();
      if (clip != null) {
        g.drawRect(clip.left, clip.top, clip.width, clip.height);
        g.clipPath();
      }
      _element(g, plan, e);
      g.restoreContext();
    }

    // Searchable text over handwriting and page pictures, drawn last and
    // never seen.
    for (final t in plan.hidden) {
      _hiddenText(g, t.text, t.rect);
    }
  }

  void _element(PdfGraphics g, PdfPagePlan plan, SceneElement e) {
    switch (e) {
      case FreehandElement():
        _freehand(g, e);
      case SceneShapeElement():
        _shape(g, e);
      case TextElement():
        final raster = plan.rasterTexts[e.id];
        if (raster != null) {
          _rasterText(g, raster, e);
        } else if (plan.texts[e.id] case final block?) {
          _text(g, block);
        }
      case ImageElement():
        _image(g, e);
      case FrameElement():
        _frame(g, e);
      case TapeElement():
        _tape(g, e);
    }
  }

  // ---- ink --------------------------------------------------------------------

  void _freehand(PdfGraphics g, FreehandElement e) {
    if (e.isEraser || e.points.isEmpty) return;
    final outline = FreehandPath.outline(e.points, e.size, kind: e.penKind);
    if (outline.length < 2) return;
    final alpha = switch (e.penKind) {
      PenKind.highlighter => FreehandPath.highlighterAlpha * e.opacity,
      PenKind.pencil => _alpha(e.color, e.opacity) * FreehandPath.pencilAlpha,
      _ => _alpha(e.color, e.opacity),
    };
    _opacity(g, alpha);
    g.setFillColor(_color(e.color));
    // The same smoothing the canvas uses (FreehandPath._buildPath): a quadratic
    // through each point to the midpoint of the next, as cubic curves.
    var current = outline.first;
    g.moveTo(current.dx, current.dy);
    for (var i = 1; i < outline.length - 1; i++) {
      final q = outline[i];
      final end = Offset((q.dx + outline[i + 1].dx) / 2,
          (q.dy + outline[i + 1].dy) / 2);
      final c1 = current + (q - current) * (2 / 3);
      final c2 = end + (q - end) * (2 / 3);
      g.curveTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      current = end;
    }
    g.lineTo(outline.last.dx, outline.last.dy);
    g.closePath();
    g.fillPath();
  }

  // ---- shapes -----------------------------------------------------------------

  /// Clean geometry rather than the canvas's hand-drawn look, and a hachure
  /// fill as a solid one, as the SVG export does.
  void _shape(PdfGraphics g, SceneShapeElement s) {
    _rotateAbout(g, SceneGeometry.shapeCenter(s), s.rotation);
    final alpha = _alpha(s.color, s.opacity);
    g.setStrokeColor(_color(s.color));
    g.setLineWidth(s.strokeWidth);
    g.setLineCap(PdfLineCap.round);
    g.setLineJoin(PdfLineJoin.round);
    switch (s.strokeStyle) {
      case StrokeStyle.solid:
        break;
      case StrokeStyle.dashed:
        g.setLineDashPattern([
          math.max(8, s.strokeWidth * 3),
          math.max(6, s.strokeWidth * 2),
        ]);
      case StrokeStyle.dotted:
        g.setLineDashPattern([
          math.max(0.5, s.strokeWidth),
          math.max(3, s.strokeWidth * 2),
        ]);
    }

    void outlineAndFill(void Function() path) {
      if (s.hasFill) {
        g.saveContext();
        _opacity(g, _alpha(s.fillColor, s.opacity));
        g.setFillColor(_color(s.fillColor));
        path();
        g.fillPath();
        g.restoreContext();
      }
      _opacity(g, alpha);
      path();
      g.strokePath();
    }

    switch (s.shapeType) {
      case ShapeType.rectangle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        final radius = s.edges == EdgeStyle.round
            ? math.min(16.0, r.shortestSide / 4)
            : 0.0;
        outlineAndFill(() => radius > 0
            ? g.drawRRect(r.left, r.top, r.width, r.height, radius, radius)
            : g.drawRect(r.left, r.top, r.width, r.height));
      case ShapeType.circle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        outlineAndFill(() =>
            g.drawEllipse(r.center.dx, r.center.dy, r.width / 2, r.height / 2));
      case ShapeType.line:
      case ShapeType.arrow:
        final (a, c) = ShapeGeometry.lineFromGeometry(s.geometryData);
        _opacity(g, alpha);
        g.moveTo(a.dx, a.dy);
        if (s.shapeType == ShapeType.arrow && s.elbowed) {
          g.lineTo(c.dx, a.dy);
          g.lineTo(c.dx, c.dy);
        } else {
          g.lineTo(c.dx, c.dy);
        }
        g.strokePath();
        if (s.shapeType == ShapeType.arrow) {
          g.setLineDashPattern();
          final endFrom = s.elbowed ? Offset(c.dx, a.dy) : a;
          final startFrom = s.elbowed ? Offset(c.dx, a.dy) : c;
          _arrowhead(g, s.endArrowhead, c, endFrom, s);
          _arrowhead(g, s.startArrowhead, a, startFrom, s);
        }
      default:
        final verts = ShapeGeometry.verticesFromGeometry(s.geometryData);
        if (verts.isEmpty) return;
        outlineAndFill(() {
          g.moveTo(verts.first.dx, verts.first.dy);
          for (final v in verts.skip(1)) {
            g.lineTo(v.dx, v.dy);
          }
          g.closePath();
        });
    }
  }

  void _arrowhead(PdfGraphics g, Arrowhead kind, Offset tip, Offset from,
      SceneShapeElement s) {
    if (kind == Arrowhead.none) return;
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final size = math.max(10.0, s.strokeWidth * 3.5);
    g.setFillColor(_color(s.color));
    switch (kind) {
      case Arrowhead.none:
        return;
      case Arrowhead.triangle:
        final p1 =
            tip - Offset(math.cos(angle - 0.5), math.sin(angle - 0.5)) * size;
        final p2 =
            tip - Offset(math.cos(angle + 0.5), math.sin(angle + 0.5)) * size;
        g.moveTo(tip.dx, tip.dy);
        g.lineTo(p1.dx, p1.dy);
        g.lineTo(p2.dx, p2.dy);
        g.closePath();
        g.fillPath();
      case Arrowhead.dot:
        g.drawEllipse(tip.dx, tip.dy, size / 3, size / 3);
        g.fillPath();
      case Arrowhead.bar:
        final n = Offset(-math.sin(angle), math.cos(angle)) * (size / 2);
        g.moveTo(tip.dx + n.dx, tip.dy + n.dy);
        g.lineTo(tip.dx - n.dx, tip.dy - n.dy);
        g.strokePath();
    }
  }

  // ---- text -------------------------------------------------------------------

  void _text(PdfGraphics g, PdfTextBlock block) {
    _rotateAbout(g, block.centre, block.rotation);
    _opacity(g, _alpha(block.color, block.opacity));
    g.setFillColor(_color(block.color));
    final latin = block.bold ? bold : regular;
    for (final line in block.lines) {
      final runs = _runs(line.text, latin);
      final natural = _width(runs) * block.fontSize;
      // Stretch the PDF font to the width the canvas drew the line at, so
      // wrapping and alignment match; a little either way, never a lot.
      final scale =
          natural <= 0 ? 1.0 : (line.width / natural).clamp(0.8, 1.25);
      g.saveContext();
      g.setTransform(_affine(1, 0, block.italic ? _kItalicSlant : 0, -1,
          line.left, line.baseline));
      var x = 0.0;
      for (final run in runs) {
        g.drawString(run.font, block.fontSize, run.text, x, 0, scale: scale);
        x += _runWidth(run) * block.fontSize * scale;
      }
      g.restoreContext();
    }
  }

  /// A text box the fonts here cannot shape (Bangla), as the canvas drew it,
  /// with its text laid invisibly over it so it can still be found.
  void _rasterText(PdfGraphics g, PdfRasterText raster, TextElement e) {
    final img = _decode('text:${e.id}', raster.png);
    if (img == null) return;
    final r = raster.rect;
    g.saveContext();
    g.setTransform(_affine(1, 0, 0, -1, r.left, r.bottom));
    g.drawImage(img, 0, 0, r.width, r.height);
    g.restoreContext();
    _hiddenText(g, e.text.replaceAll('\n', ' '), r);
  }

  /// [text] over [rect], invisible: there to be searched and selected.
  void _hiddenText(PdfGraphics g, String text, Rect rect) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty || rect.width <= 0 || rect.height <= 0) return;
    final runs = _runs(clean, regular);
    if (runs.isEmpty) return;
    final size = rect.height * 0.8;
    final natural = _width(runs) * size;
    if (natural <= 0) return;
    final scale = rect.width / natural;
    g.saveContext();
    g.setTransform(
        _affine(1, 0, 0, -1, rect.left, rect.bottom - rect.height * 0.2));
    var x = 0.0;
    for (final run in runs) {
      g.drawString(run.font, size, run.text, x, 0,
          scale: scale, mode: PdfTextRenderingMode.invisible);
      x += _runWidth(run) * size * scale;
    }
    g.restoreContext();
  }

  /// [text] split into runs of one font: [latin] where it has the glyph, the
  /// Bangla font where that has it. A character neither has is left out.
  List<({String text, PdfTtfFont font})> _runs(String text, PdfTtfFont latin) {
    final out = <({String text, PdfTtfFont font})>[];
    final buf = StringBuffer();
    PdfTtfFont? font;
    for (final r in text.runes) {
      final f = latin.isRuneSupported(r)
          ? latin
          : bengali.isRuneSupported(r)
              ? bengali
              : null;
      if (f == null) continue;
      if (f != font && buf.isNotEmpty) {
        out.add((text: buf.toString(), font: font!));
        buf.clear();
      }
      font = f;
      buf.writeCharCode(r);
    }
    if (buf.isNotEmpty) out.add((text: buf.toString(), font: font!));
    return out;
  }

  /// Width of [run] in ems. Measured glyph by glyph: the font's own string
  /// measure only takes Latin-1.
  double _runWidth(({String text, PdfTtfFont font}) run) {
    var w = 0.0;
    for (final r in run.text.runes) {
      w += run.font.glyphMetrics(r).advanceWidth;
    }
    return w;
  }

  double _width(List<({String text, PdfTtfFont font})> runs) =>
      runs.fold(0.0, (sum, r) => sum + _runWidth(r));

  // ---- pictures, frames, tape -----------------------------------------------

  void _image(PdfGraphics g, ImageElement e) {
    final r = e.boundsRect;
    if (r.isEmpty) return;
    _rotateAbout(g, r.center, e.rotation);
    final bytes = job.images[e.relativeImagePath];
    final img = bytes == null ? null : _decode(e.relativeImagePath, bytes);
    if (img == null) {
      // The canvas's placeholder, rather than nothing.
      g.setStrokeColor(_color(0xFF8A93A6));
      g.setLineWidth(1.5);
      g.drawRRect(r.left, r.top, r.width, r.height, 8, 8);
      g.strokePath();
      return;
    }
    _opacity(g, e.opacity);
    g.setTransform(_affine(1, 0, 0, -1, r.left, r.bottom));
    g.drawImage(img, 0, 0, r.width, r.height);
  }

  PdfImage? _decode(String key, Uint8List bytes) =>
      _images.putIfAbsent(key, () {
        try {
          return PdfImage.file(doc, bytes: bytes);
        } catch (_) {
          return null;
        }
      });

  void _frame(PdfGraphics g, FrameElement f) {
    final r = _rect(f.geometryData);
    if (r.isEmpty) return;
    _opacity(g, 0.9 * f.opacity);
    g.setStrokeColor(_color(0xFF8A93A6));
    g.setLineWidth(1.5);
    g.drawRRect(r.left, r.top, r.width, r.height, 6, 6);
    g.strokePath();
    if (f.name.isEmpty) return;
    g.setFillColor(_color(0xFF5A6472));
    g.saveContext();
    g.setTransform(_affine(1, 0, 0, -1, r.left, r.top - 4));
    var x = 0.0;
    for (final run in _runs(f.name, regular)) {
      g.drawString(run.font, 12, run.text, x, 0);
      x += _runWidth(run) * 12;
    }
    g.restoreContext();
  }

  /// As on the page: laid down it hides what is under it; lifted it is a tint
  /// with a dashed edge.
  void _tape(PdfGraphics g, TapeElement t) {
    final r = _rect(t.geometryData);
    if (r.isEmpty) return;
    g.setFillColor(_color(t.color));
    if (!t.revealed) {
      _opacity(g, t.opacity);
      g.drawRRect(r.left, r.top, r.width, r.height, 3, 3);
      g.fillPath();
      return;
    }
    g.saveContext();
    _opacity(g, 0.14 * t.opacity);
    g.drawRRect(r.left, r.top, r.width, r.height, 3, 3);
    g.fillPath();
    g.restoreContext();
    _opacity(g, 0.9 * t.opacity);
    g.setStrokeColor(_color(t.color));
    g.setLineWidth(1.5);
    g.setLineDashPattern([5, 5]);
    g.drawRRect(r.left, r.top, r.width, r.height, 3, 3);
    g.strokePath();
  }

  // ---- helpers ----------------------------------------------------------------

  void _rotateAbout(PdfGraphics g, Offset c, double angle) {
    if (angle == 0) return;
    final cos = math.cos(angle), sin = math.sin(angle);
    g.setTransform(_affine(cos, sin, -sin, cos, c.dx - cos * c.dx + sin * c.dy,
        c.dy - sin * c.dx - cos * c.dy));
  }

  void _opacity(PdfGraphics g, double a) {
    if (a >= 1) return;
    g.setGraphicState(PdfGraphicState(opacity: a.clamp(0.0, 1.0)));
  }
}

/// Draws a template's lines, dots and boxes into a PDF page.
class _PdfTemplateSink implements TemplateSink {
  _PdfTemplateSink(this.g);
  final PdfGraphics g;

  @override
  void line(Offset a, Offset b, Color color, double width) {
    g.setStrokeColor(_color(color.toARGB32()));
    g.setLineWidth(width);
    g.moveTo(a.dx, a.dy);
    g.lineTo(b.dx, b.dy);
    g.strokePath();
  }

  @override
  void dots(List<Offset> centres, Color color, double radius) {
    if (centres.isEmpty) return;
    g.setFillColor(_color(color.toARGB32()));
    for (final c in centres) {
      g.drawEllipse(c.dx, c.dy, radius, radius);
    }
    g.fillPath();
  }

  @override
  void roundRect(Rect rect, double radius, Color color, double width) {
    g.setStrokeColor(_color(color.toARGB32()));
    g.setLineWidth(width);
    g.drawRRect(rect.left, rect.top, rect.width, rect.height, radius, radius);
    g.strokePath();
  }
}

/// The affine map x' = a·x + c·y + e, y' = b·x + d·y + f.
Matrix4 _affine(double a, double b, double c, double d, double e, double f) =>
    Matrix4(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1);

PdfColor _color(int argb) => PdfColor.fromInt(argb | 0xFF000000);

double _alpha(int argb, double opacity) =>
    ((argb >> 24) & 0xFF) / 255.0 * opacity;

Rect _rect(List<double> g) => g.length < 4
    ? Rect.zero
    : Rect.fromLTRB(math.min(g[0], g[2]), math.min(g[1], g[3]),
        math.max(g[0], g[2]), math.max(g[1], g[3]));
