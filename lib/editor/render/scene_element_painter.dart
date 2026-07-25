// Paints a single unified [SceneElement] (freehand, shape, text, image) onto a
// canvas in scene coordinates, honouring rotation, opacity and the full style
// set (fill style, stroke style, roughness, rounded edges, arrowheads, elbow
// arrows). Used by both the static content layer and the live shape preview.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/geometry/element_bounds.dart';
import '../../domain/geometry/scene_geometry.dart';
import '../../domain/model/scene_element.dart';
import '../../features/editor/domain/services/shape_geometry.dart';
import 'dash_path.dart';
import 'freehand_path.dart';
import 'rough_renderer.dart';

final Expando<Path> _freehandCache = Expando<Path>();
final Expando<Path> _roughOutlineCache = Expando<Path>();

class SceneElementPainter {
  SceneElementPainter._();

  /// Paints [element]. [byId] resolves a bound text's container; [imageResolver]
  /// (when given) supplies decoded bitmaps for [ImageElement]s.
  static void paint(
    Canvas canvas,
    SceneElement element, {
    Map<String, SceneElement> byId = const {},
    ui.Image? Function(String relativePath)? imageResolver,
  }) {
    switch (element) {
      case FreehandElement():
        _freehand(canvas, element);
      case SceneShapeElement():
        _shape(canvas, element);
      case TextElement():
        _text(canvas, element, byId);
      case ImageElement():
        _image(canvas, element, imageResolver?.call(element.relativeImagePath));
      case FrameElement():
        _frame(canvas, element);
    }
  }

  // ---- frame ----------------------------------------------------------------

  /// Draws the frame's border + name label. Member elements are clipped to the
  /// frame by [SceneStaticLayer]; the frame itself draws no content.
  static void _frame(Canvas canvas, FrameElement f) {
    final rect = _rectFromLTRB(f.geometryData);
    if (rect.isEmpty) return;

    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF8A93A6).withValues(alpha: 0.9 * f.opacity)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 12))
      ..pushStyle(ui.TextStyle(
          color: const Color(0xFF5A6472).withValues(alpha: f.opacity)))
      ..addText(f.name);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 400));
    canvas.drawParagraph(
        paragraph, Offset(rect.left, rect.top - paragraph.height - 2));
  }

  // ---- freehand -------------------------------------------------------------

  static void _freehand(Canvas canvas, FreehandElement e) {
    if (e.points.isEmpty || e.isEraser) return;
    var path = _freehandCache[e];
    if (path == null) {
      path = FreehandPath.build(e.points, e.size, isComplete: true);
      if (path == null) return;
      _freehandCache[e] = path;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(e.color).withValues(alpha: e.opacity)
        ..style = PaintingStyle.fill,
    );
  }

  // ---- shapes ---------------------------------------------------------------

  static bool _roughable(ShapeType t) =>
      t == ShapeType.line ||
      t == ShapeType.arrow ||
      t == ShapeType.circle ||
      t == ShapeType.rectangle ||
      t == ShapeType.triangle ||
      t == ShapeType.polygon ||
      t == ShapeType.diamond;

  static void _shape(Canvas canvas, SceneShapeElement s) {
    canvas.save();
    final c = SceneGeometry.shapeCenter(s);
    canvas
      ..translate(c.dx, c.dy)
      ..rotate(s.rotation)
      ..translate(-c.dx, -c.dy);

    final strokePaint = Paint()
      ..color = Color(s.color).withValues(alpha: s.opacity)
      ..strokeWidth = s.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Color(s.fillColor).withValues(alpha: s.hasFill ? s.opacity : 0)
      ..style = PaintingStyle.fill;

    if (s.shapeType == ShapeType.line || s.shapeType == ShapeType.arrow) {
      _lineOrArrow(canvas, s, strokePaint);
      canvas.restore();
      return;
    }

    if (s.roughness > 0 && _roughable(s.shapeType)) {
      _roughClosed(canvas, s, strokePaint, fillPaint);
      canvas.restore();
      return;
    }

    final (outline, bounds) = _closedPath(s);
    if (s.hasFill) _fill(canvas, s, outline, bounds, fillPaint);
    canvas.drawPath(_dash(outline, s.strokeStyle, s.strokeWidth), strokePaint);
    canvas.restore();
  }

  static (Path, Rect) _closedPath(SceneShapeElement s) {
    switch (s.shapeType) {
      case ShapeType.circle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        return (Path()..addOval(r), r);
      case ShapeType.rectangle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        if (s.edges == EdgeStyle.round) {
          final radius = math.min(16.0, r.shortestSide / 4);
          return (
            Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
            r
          );
        }
        return (Path()..addRect(r), r);
      default:
        final verts = ShapeGeometry.verticesFromGeometry(s.geometryData);
        final path = Path()..addPolygon(verts, true);
        return (path, ShapeGeometry.boundingRect(verts));
    }
  }

  static void _fill(
      Canvas canvas, SceneShapeElement s, Path fillPath, Rect bounds, Paint fillPaint) {
    switch (s.fillStyle) {
      case FillStyle.solid:
        canvas.drawPath(fillPath, fillPaint);
      case FillStyle.hachure:
        RoughRenderer.hachure(canvas, fillPath, bounds, s.seed, _hachurePaint(s),
            gap: _hachureGap(s));
      case FillStyle.crossHatch:
        RoughRenderer.crossHatch(
            canvas, fillPath, bounds, s.seed, _hachurePaint(s),
            gap: _hachureGap(s));
    }
  }

  static Paint _hachurePaint(SceneShapeElement s) => Paint()
    ..color = Color(s.fillColor).withValues(alpha: s.opacity)
    ..strokeWidth = (s.strokeWidth * 0.5).clamp(0.6, 2.5)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static double _hachureGap(SceneShapeElement s) =>
      (s.strokeWidth * 3).clamp(7.0, 16.0);

  static void _roughClosed(
      Canvas canvas, SceneShapeElement s, Paint strokePaint, Paint fillPaint) {
    final List<Offset> pts;
    final Path fillPath;
    final Rect bounds;
    if (s.shapeType == ShapeType.circle) {
      final r = ShapeGeometry.rectFromGeometry(s.geometryData);
      pts = RoughRenderer.ellipsePolygon(r);
      fillPath = Path()..addOval(r);
      bounds = r;
    } else if (s.shapeType == ShapeType.rectangle) {
      final r = ShapeGeometry.rectFromGeometry(s.geometryData);
      pts = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      fillPath = Path()..addRect(r);
      bounds = r;
    } else {
      pts = ShapeGeometry.verticesFromGeometry(s.geometryData);
      fillPath = Path()..addPolygon(pts, true);
      bounds = ShapeGeometry.boundingRect(pts);
    }
    if (pts.isEmpty) return;

    if (s.hasFill) _fill(canvas, s, fillPath, bounds, fillPaint);
    canvas.drawPath(_roughOutline(s, pts, true), strokePaint);
  }

  static Path _roughOutline(SceneShapeElement s, List<Offset> pts, bool closed) {
    final cached = _roughOutlineCache[s];
    if (cached != null) return cached;
    final p = RoughRenderer.outline(pts, closed, s.seed, s.roughness);
    _roughOutlineCache[s] = p;
    return p;
  }

  static void _lineOrArrow(
      Canvas canvas, SceneShapeElement s, Paint strokePaint) {
    final pts = _shaftPoints(s);
    if (pts.length < 2) return;

    final isArrow = s.shapeType == ShapeType.arrow;
    // The shaft stops at the back of each head, so the head's point is the end
    // of the arrow. Drawn to full length it runs past the tip by half a stroke
    // width — more once roughness jitters the endpoint — and that overshoot
    // reads as the head sitting short of where the line ends.
    final shaftPts = isArrow
        ? _trimShaft(pts, s.startArrowhead, s.endArrowhead, s.strokeWidth)
        : pts;

    final Path shaft;
    if (s.roughness > 0) {
      shaft = _roughOutline(s, shaftPts, false);
    } else {
      shaft = Path()..moveTo(shaftPts.first.dx, shaftPts.first.dy);
      for (int i = 1; i < shaftPts.length; i++) {
        shaft.lineTo(shaftPts[i].dx, shaftPts[i].dy);
      }
    }
    canvas.drawPath(_dash(shaft, s.strokeStyle, s.strokeWidth), strokePaint);

    if (isArrow) {
      // Angles come from the untrimmed points, so trimming can never turn a
      // head away from the direction the user drew.
      _arrowhead(canvas, pts.last, pts[pts.length - 2], s.endArrowhead,
          strokePaint.color, s.strokeWidth);
      _arrowhead(canvas, pts.first, pts[1], s.startArrowhead, strokePaint.color,
          s.strokeWidth);
    }
  }

  /// [pts] with each end pulled back by however far its arrowhead reaches along
  /// the shaft, so the shaft finishes inside the head rather than through it.
  @visibleForTesting
  static List<Offset> trimShaftForHeads(
          List<Offset> pts, Arrowhead start, Arrowhead end, double w) =>
      _trimShaft(pts, start, end, w);

  static List<Offset> _trimShaft(
      List<Offset> pts, Arrowhead start, Arrowhead end, double w) {
    final out = [...pts];
    final last = out.length - 1;
    out[0] = _pullBack(out[0], out[1], _headInset(start, w));
    out[last] = _pullBack(out[last], out[last - 1], _headInset(end, w));
    return out;
  }

  /// [tip] moved [inset] towards [towards], never past it — a stub of an arrow
  /// shorter than its own head collapses instead of doubling back.
  static Offset _pullBack(Offset tip, Offset towards, double inset) {
    if (inset <= 0) return tip;
    final d = towards - tip;
    final len = d.distance;
    if (len == 0) return tip;
    return tip + d * (math.min(inset, len) / len);
  }

  /// How far back from the tip an [Arrowhead] already covers the shaft. Only
  /// heads that would leave the shaft's round cap showing need one: a dot is
  /// centred on the tip and always wider than the cap, so it hides it already.
  static double _headInset(Arrowhead type, double w) {
    switch (type) {
      case Arrowhead.none:
      case Arrowhead.dot:
        return 0;
      case Arrowhead.triangle:
        // Where the barbs meet the shaft, kept half a stroke shallower so the
        // trim can never open a gap between shaft and head.
        return math.max(
            0, _arrowheadSize(w) * math.cos(_kArrowSpread) - w * 0.5);
      case Arrowhead.bar:
        return w * 0.5;
    }
  }

  static List<Offset> _shaftPoints(SceneShapeElement s) {
    final (start, end) = ShapeGeometry.lineFromGeometry(s.geometryData);
    if (s.shapeType == ShapeType.arrow && s.elbowed) {
      // Horizontal-first right-angle route.
      return [start, Offset(end.dx, start.dy), end];
    }
    return [start, end];
  }

  /// Angle between the shaft and each barb of a triangular arrowhead. Shared
  /// with [_headInset], which needs the same geometry to know how far the head
  /// reaches back down the shaft.
  static const double _kArrowSpread = 0.5;

  static double _arrowheadSize(double w) => math.max(10.0, w * 3.5);

  static void _arrowhead(Canvas canvas, Offset tip, Offset from, Arrowhead type,
      Color color, double w) {
    if (type == Arrowhead.none) return;
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final size = _arrowheadSize(w);
    switch (type) {
      case Arrowhead.none:
        return;
      case Arrowhead.triangle:
        final p1 = tip -
            Offset(math.cos(angle - _kArrowSpread),
                    math.sin(angle - _kArrowSpread)) *
                size;
        final p2 = tip -
            Offset(math.cos(angle + _kArrowSpread),
                    math.sin(angle + _kArrowSpread)) *
                size;
        final path = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill);
      case Arrowhead.dot:
        canvas.drawCircle(
            tip,
            size * 0.35,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill);
      case Arrowhead.bar:
        final perp = Offset(-math.sin(angle), math.cos(angle)) * (size * 0.6);
        canvas.drawLine(
            tip - perp,
            tip + perp,
            Paint()
              ..color = color
              ..strokeWidth = w
              ..strokeCap = StrokeCap.round);
    }
  }

  static Path _dash(Path source, StrokeStyle style, double w) {
    switch (style) {
      case StrokeStyle.solid:
        return source;
      case StrokeStyle.dashed:
        return DashPath.dashed(source,
            dash: math.max(8, w * 3), gap: math.max(6, w * 2));
      case StrokeStyle.dotted:
        return DashPath.dashed(source,
            dash: math.max(0.5, w), gap: math.max(3, w * 2));
    }
  }

  // ---- text -----------------------------------------------------------------

  static void _text(
      Canvas canvas, TextElement t, Map<String, SceneElement> byId) {
    if (t.text.isEmpty) return;

    Rect rect = _rectFromLTRB(t.geometryData);
    final container = t.containerId.isEmpty ? null : byId[t.containerId];
    final bound = container is SceneShapeElement;
    if (bound) rect = ElementBounds.of(container);

    final centre = rect.center;

    canvas.save();
    canvas
      ..translate(centre.dx, centre.dy)
      ..rotate(t.rotation)
      ..translate(-centre.dx, -centre.dy);

    final paragraph = layOutText(t, rect.width);

    final dy = bound ? rect.top + (rect.height - paragraph.height) / 2 : rect.top;
    canvas.drawParagraph(paragraph, Offset(rect.left, dy));
    canvas.restore();
  }

  /// Lays [t] out exactly as [_text] draws it, wrapped to [width].
  ///
  /// Public so callers that need to know how tall the text will actually be —
  /// editing it, or extracting it from OCR — measure the same paragraph the
  /// painter draws, rather than estimating and drifting out of step. A width at
  /// or below 1 means the element has no meaningful box yet, so it falls back to
  /// the same 200 the painter has always used.
  static ui.Paragraph layOutText(TextElement t, double width) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: t.fontSize,
      fontFamily: t.fontFamily,
      fontWeight: t.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: t.isItalic ? FontStyle.italic : FontStyle.normal,
      textAlign: _align(t.align),
    ))
      ..pushStyle(
          ui.TextStyle(color: Color(t.color).withValues(alpha: t.opacity)))
      ..addText(t.text);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: width <= 1 ? 200.0 : width));
  }

  static TextAlign _align(TextAlignKind a) {
    switch (a) {
      case TextAlignKind.left:
        return TextAlign.left;
      case TextAlignKind.center:
        return TextAlign.center;
      case TextAlignKind.right:
        return TextAlign.right;
    }
  }

  // ---- image (placeholder; real bitmap loading lands with the image
  //      lifecycle in a later phase) -------------------------------------------

  static void _image(Canvas canvas, ImageElement im, ui.Image? bitmap) {
    final rect = _rectFromLTRB(im.geometryData);
    if (rect.isEmpty) return; // e.g. a 0-sized PDF background

    final centre = rect.center;
    canvas.save();
    canvas
      ..translate(centre.dx, centre.dy)
      ..rotate(im.rotation)
      ..translate(-centre.dx, -centre.dy);

    if (bitmap != null) {
      canvas.drawImageRect(
        bitmap,
        Rect.fromLTWH(
            0, 0, bitmap.width.toDouble(), bitmap.height.toDouble()),
        rect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = const Color(0xFFFFFFFF).withValues(alpha: im.opacity),
      );
      canvas.restore();
      return;
    }

    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFB0B7C3).withValues(alpha: 0.30 * im.opacity)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFF8A93A6).withValues(alpha: im.opacity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);

    final label = im.sourceDescription.isNotEmpty ? im.sourceDescription : 'image';
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: 12,
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(color: const Color(0xFF5A6472)))
      ..addText(label);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));
    canvas.drawParagraph(
        paragraph, Offset(rect.left, rect.center.dy - paragraph.height / 2));
    canvas.restore();
  }

  static Rect _rectFromLTRB(List<double> g) {
    if (g.length < 4) return Rect.zero;
    return Rect.fromLTRB(g[0], g[1], g[2], g[3]).normalized();
  }
}

extension on Rect {
  Rect normalized() => Rect.fromLTRB(
        left < right ? left : right,
        top < bottom ? top : bottom,
        left < right ? right : left,
        top < bottom ? bottom : top,
      );
}
