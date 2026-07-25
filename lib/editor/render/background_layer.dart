// Background layer — draws canvas background color and template pattern.

import 'package:flutter/material.dart';

import '../../domain/model/template_type.dart';
import 'template_painter.dart';

class BackgroundLayer extends CustomPainter {
  final Color backgroundColor;
  final TemplateType templateType;

  /// Viewport transform (screen = scroll + zoom * scene). Defaults describe the
  /// identity transform, so callers that paint in plain screen space (legacy
  /// canvas, export, previews) get the original behaviour. When a real viewport
  /// is supplied the template pattern is drawn in scene space so it pans and
  /// zooms together with the drawn content.
  final double scrollX;
  final double scrollY;
  final double zoom;

  /// When non-null the canvas is in single-page mode: the area outside this
  /// scene-space page rect is painted with [deskColor], the page itself gets a
  /// paper fill + soft shadow + border, and the template is clipped to it.
  final Rect? pageRect;
  final Color deskColor;

  const BackgroundLayer({
    this.backgroundColor = Colors.white,
    this.templateType = TemplateType.blank,
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.zoom = 1.0,
    this.pageRect,
    this.deskColor = const Color(0xFFE6E8EC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageRect == null) {
      _paintInfinite(canvas, size);
    } else {
      _paintPage(canvas, size, pageRect!);
    }
  }

  void _paintInfinite(Canvas canvas, Size size) {
    // Solid fill always covers the full screen, regardless of pan/zoom.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor);

    if (templateType == TemplateType.blank) return;

    // Draw the pattern in scene space so it tracks the content. The visible
    // scene rect is the screen viewport mapped back through the transform.
    canvas.save();
    canvas.translate(scrollX, scrollY);
    canvas.scale(zoom);
    final visible = Rect.fromLTRB(
      -scrollX / zoom,
      -scrollY / zoom,
      (size.width - scrollX) / zoom,
      (size.height - scrollY) / zoom,
    );
    TemplatePainter.paint(canvas, size, templateType, backgroundColor,
        region: visible, zoom: zoom);
    canvas.restore();
  }

  void _paintPage(Canvas canvas, Size size, Rect page) {
    // Desk behind the page.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = deskColor);

    // Page bounds in screen space.
    final pageScreen = Rect.fromLTRB(
      page.left * zoom + scrollX,
      page.top * zoom + scrollY,
      page.right * zoom + scrollX,
      page.bottom * zoom + scrollY,
    );

    // Soft drop shadow under the page.
    canvas.drawRect(
      pageScreen.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Paper fill.
    canvas.drawRect(pageScreen, Paint()..color = backgroundColor);

    // Template, clipped to the page and drawn in scene space.
    if (templateType != TemplateType.blank) {
      canvas.save();
      canvas.clipRect(pageScreen);
      canvas.translate(scrollX, scrollY);
      canvas.scale(zoom);
      TemplatePainter.paint(canvas, size, templateType, backgroundColor,
          region: page, zoom: zoom);
      canvas.restore();
    }

    // Thin page border.
    canvas.drawRect(
      pageScreen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0x1F000000),
    );
  }

  @override
  bool shouldRepaint(BackgroundLayer oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor ||
      templateType != oldDelegate.templateType ||
      scrollX != oldDelegate.scrollX ||
      scrollY != oldDelegate.scrollY ||
      zoom != oldDelegate.zoom ||
      pageRect != oldDelegate.pageRect ||
      deskColor != oldDelegate.deskColor;
}
