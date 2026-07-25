// Renders a list of [SceneElement]s to shareable formats: PNG (raster, via the
// real scene painter so it matches the canvas exactly), PDF (the PNG embedded
// on a page sized to the content), and SVG (vector, built directly from element
// geometry). Callers pass either the whole page or just the selection.
//
// The byte/string producers here are pure and deterministic; sharing/saving the
// result is a thin platform concern handled by `features/export`.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/geometry/selection_bounds.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/geometry/shape_geometry.dart';
import 'scene_static_layer.dart';

class SceneExporter {
  SceneExporter._();

  static const double defaultPadding = 24;

  /// Tight content box (union of world bounds) grown by [padding]. Returns null
  /// when there is nothing to export.
  static Rect? contentBounds(List<SceneElement> els,
      {double padding = defaultPadding}) {
    final box = SelectionBounds.union(els);
    if (box == null || box.isEmpty) return null;
    return box.inflate(padding);
  }

  // ---- PNG ------------------------------------------------------------------

  /// Rasterises [els] to PNG bytes at [scale]× over a [background] fill.
  /// [imageResolver] supplies decoded bitmaps for [ImageElement]s (callers pass
  /// the shared image cache, after ensuring the paths are loaded). Returns null
  /// when there is nothing to export.
  static Future<Uint8List?> toPng(
    List<SceneElement> els, {
    Color background = Colors.white,
    double scale = 2.0,
    double padding = defaultPadding,
    ui.Image? Function(String relativePath)? imageResolver,
  }) async {
    final bounds = contentBounds(els, padding: padding);
    if (bounds == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    if (background.a > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          Paint()..color = background);
    }
    canvas.translate(-bounds.left, -bounds.top);
    SceneStaticLayer(elements: els, imageResolver: imageResolver)
        .paint(canvas, bounds.size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (bounds.width * scale).ceil().clamp(1, 16384),
      (bounds.height * scale).ceil().clamp(1, 16384),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  // ---- PDF ------------------------------------------------------------------

  /// A single-page PDF containing the rasterised scene.
  static Future<Uint8List?> toPdf(
    List<SceneElement> els, {
    Color background = Colors.white,
    double scale = 2.0,
    double padding = defaultPadding,
    ui.Image? Function(String relativePath)? imageResolver,
  }) async {
    final png = await toPng(els,
        background: background,
        scale: scale,
        padding: padding,
        imageResolver: imageResolver);
    if (png == null) return null;
    final bounds = contentBounds(els, padding: padding)!;

    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    final format = PdfPageFormat(bounds.width, bounds.height);
    doc.addPage(pw.Page(
      pageFormat: format,
      build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
    ));
    return doc.save();
  }

  // ---- SVG ------------------------------------------------------------------

  /// Vector SVG of the scene. Freehand ink is approximated as a stroked
  /// polyline and hachure fills as solid fills — faithful enough for re-use in
  /// other vector tools without a path-introspection dependency.
  static String toSvg(
    List<SceneElement> els, {
    Color? background,
    double padding = defaultPadding,
  }) {
    final bounds = contentBounds(els, padding: padding) ??
        const Rect.fromLTWH(0, 0, 1, 1);
    final w = bounds.width, h = bounds.height;
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" '
          'width="${_n(w)}" height="${_n(h)}" '
          'viewBox="${_n(bounds.left)} ${_n(bounds.top)} ${_n(w)} ${_n(h)}">');
    if (background != null) {
      b.writeln('<rect x="${_n(bounds.left)}" y="${_n(bounds.top)}" '
          'width="${_n(w)}" height="${_n(h)}" fill="${_hex(background.toARGB32())}"/>');
    }
    final ordered = [...els]..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    for (final e in ordered) {
      _svgElement(b, e);
    }
    b.writeln('</svg>');
    return b.toString();
  }

  static void _svgElement(StringBuffer b, SceneElement e) {
    final g = _rotateAttr(e);
    if (g != null) b.writeln('<g transform="$g">');
    switch (e) {
      case FreehandElement():
        if (!e.isEraser && e.points.length >= 2) {
          final pts =
              e.points.map((p) => '${_n(p.x)},${_n(p.y)}').join(' ');
          b.writeln('<polyline points="$pts" fill="none" '
              'stroke="${_hex(e.color)}" stroke-opacity="${_n(_alpha(e.color, e.opacity))}" '
              'stroke-width="${_n(e.size)}" stroke-linecap="round" stroke-linejoin="round"/>');
        }
      case SceneShapeElement():
        _svgShape(b, e);
      case TextElement():
        if (e.text.isNotEmpty) {
          final r = _rect(e.geometryData);
          b.writeln('<text x="${_n(r.left)}" y="${_n(r.top + e.fontSize)}" '
              'font-size="${_n(e.fontSize)}" font-family="${_esc(e.fontFamily)}" '
              '${e.isBold ? 'font-weight="bold" ' : ''}${e.isItalic ? 'font-style="italic" ' : ''}'
              'fill="${_hex(e.color)}" fill-opacity="${_n(_alpha(e.color, e.opacity))}">'
              '${_esc(e.text)}</text>');
        }
      case ImageElement():
        final r = _rect(e.geometryData);
        if (e.relativeImagePath.isNotEmpty) {
          b.writeln('<image href="${_esc(e.relativeImagePath)}" '
              'x="${_n(r.left)}" y="${_n(r.top)}" '
              'width="${_n(r.width)}" height="${_n(r.height)}" opacity="${_n(e.opacity)}"/>');
        } else {
          b.writeln('<rect x="${_n(r.left)}" y="${_n(r.top)}" '
              'width="${_n(r.width)}" height="${_n(r.height)}" '
              'fill="none" stroke="#8A93A6"/>');
        }
      case FrameElement():
        final r = _rect(e.geometryData);
        b.writeln('<rect x="${_n(r.left)}" y="${_n(r.top)}" '
            'width="${_n(r.width)}" height="${_n(r.height)}" rx="6" '
            'fill="none" stroke="#8A93A6"/>');
        b.writeln('<text x="${_n(r.left)}" y="${_n(r.top - 4)}" '
            'font-size="12" fill="#5A6472">${_esc(e.name)}</text>');
    }
    if (g != null) b.writeln('</g>');
  }

  static void _svgShape(StringBuffer b, SceneShapeElement s) {
    final stroke = 'stroke="${_hex(s.color)}" '
        'stroke-opacity="${_n(_alpha(s.color, s.opacity))}" '
        'stroke-width="${_n(s.strokeWidth)}" stroke-linecap="round" stroke-linejoin="round"';
    final fill = s.hasFill
        ? 'fill="${_hex(s.fillColor)}" fill-opacity="${_n(_alpha(s.fillColor, s.opacity))}"'
        : 'fill="none"';
    final dash = switch (s.strokeStyle) {
      StrokeStyle.solid => '',
      StrokeStyle.dashed =>
        ' stroke-dasharray="${_n(math.max(8, s.strokeWidth * 3))},${_n(math.max(6, s.strokeWidth * 2))}"',
      StrokeStyle.dotted =>
        ' stroke-dasharray="${_n(math.max(0.5, s.strokeWidth))},${_n(math.max(3, s.strokeWidth * 2))}"',
    };
    switch (s.shapeType) {
      case ShapeType.rectangle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        final rx = s.edges == EdgeStyle.round
            ? ' rx="${_n(math.min(16, r.shortestSide / 4))}"'
            : '';
        b.writeln('<rect x="${_n(r.left)}" y="${_n(r.top)}" '
            'width="${_n(r.width)}" height="${_n(r.height)}"$rx $fill $stroke$dash/>');
      case ShapeType.circle:
        final r = ShapeGeometry.rectFromGeometry(s.geometryData);
        b.writeln('<ellipse cx="${_n(r.center.dx)}" cy="${_n(r.center.dy)}" '
            'rx="${_n(r.width / 2)}" ry="${_n(r.height / 2)}" $fill $stroke$dash/>');
      case ShapeType.line:
      case ShapeType.arrow:
        final (a, c) = ShapeGeometry.lineFromGeometry(s.geometryData);
        final pts = (s.shapeType == ShapeType.arrow && s.elbowed)
            ? '${_n(a.dx)},${_n(a.dy)} ${_n(c.dx)},${_n(a.dy)} ${_n(c.dx)},${_n(c.dy)}'
            : '${_n(a.dx)},${_n(a.dy)} ${_n(c.dx)},${_n(c.dy)}';
        b.writeln('<polyline points="$pts" fill="none" $stroke$dash/>');
        if (s.shapeType == ShapeType.arrow && s.endArrowhead != Arrowhead.none) {
          _svgArrowhead(b, c, a, s.color, s.strokeWidth, _alpha(s.color, s.opacity));
        }
      default:
        final verts = ShapeGeometry.verticesFromGeometry(s.geometryData);
        if (verts.isEmpty) return;
        final pts = verts.map((p) => '${_n(p.dx)},${_n(p.dy)}').join(' ');
        b.writeln('<polygon points="$pts" $fill $stroke$dash/>');
    }
  }

  static void _svgArrowhead(StringBuffer b, Offset tip, Offset from, int color,
      double w, double opacity) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final size = math.max(10.0, w * 3.5);
    final p1 = tip - Offset(math.cos(angle - 0.5), math.sin(angle - 0.5)) * size;
    final p2 = tip - Offset(math.cos(angle + 0.5), math.sin(angle + 0.5)) * size;
    b.writeln('<polygon points="${_n(tip.dx)},${_n(tip.dy)} '
        '${_n(p1.dx)},${_n(p1.dy)} ${_n(p2.dx)},${_n(p2.dy)}" '
        'fill="${_hex(color)}" fill-opacity="${_n(opacity)}"/>');
  }

  static String? _rotateAttr(SceneElement e) {
    if (e.rotation == 0) return null;
    final c = SelectionBounds.union([e])?.center ?? Offset.zero;
    final deg = e.rotation * 180 / math.pi;
    return 'rotate(${_n(deg)} ${_n(c.dx)} ${_n(c.dy)})';
  }

  // ---- helpers --------------------------------------------------------------

  static Rect _rect(List<double> g) => g.length < 4
      ? Rect.zero
      : Rect.fromLTRB(
          math.min(g[0], g[2]),
          math.min(g[1], g[3]),
          math.max(g[0], g[2]),
          math.max(g[1], g[3]),
        );

  static String _hex(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final bl = argb & 0xFF;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${h(r)}${h(g)}${h(bl)}';
  }

  static double _alpha(int argb, double opacity) =>
      ((argb >> 24) & 0xFF) / 255.0 * opacity;

  static String _n(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
