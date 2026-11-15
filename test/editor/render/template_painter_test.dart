import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/template_type.dart';
import 'package:margo/editor/render/template_painter.dart';

Picture _paint(TemplateType type, Color background, {double zoom = 1}) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  TemplatePainter.paint(
    canvas,
    const Size(400, 300),
    type,
    background,
    region: const Rect.fromLTWH(0, 0, 400, 300),
    zoom: zoom,
  );
  return recorder.endRecording();
}

void main() {
  for (final type in TemplateType.values) {
    test('${type.name} paints on light and dark paper without error', () {
      for (final background in [Colors.white, const Color(0xFF101010)]) {
        final blank = _paint(TemplateType.blank, background);
        final picture = _paint(type, background);
        // Measured against the blank page, so the size of an empty picture does
        // not matter: a real pattern draws more than nothing.
        if (type == TemplateType.blank) {
          expect(picture.approximateBytesUsed, blank.approximateBytesUsed);
        } else {
          expect(picture.approximateBytesUsed,
              greaterThan(blank.approximateBytesUsed));
        }
        blank.dispose();
        picture.dispose();
      }
    });
  }

  test('the template order is stable: new kinds are only appended', () {
    expect(TemplateType.values.take(5), [
      TemplateType.blank,
      TemplateType.ruled,
      TemplateType.dotted,
      TemplateType.grid,
      TemplateType.engineeringGrid,
    ]);
    expect(TemplateType.values.skip(5), [
      TemplateType.cornell,
      TemplateType.music,
      TemplateType.isometric,
      TemplateType.checklist,
    ]);
  });

  test('cornell on a real page paints its cue column and summary band', () {
    final recorder = PictureRecorder();
    TemplatePainter.paint(
      Canvas(recorder),
      const Size(400, 300),
      TemplateType.cornell,
      Colors.white,
      region: const Rect.fromLTWH(0, 0, 400, 300),
      bounded: true,
    );
    final picture = recorder.endRecording();
    final blank = _paint(TemplateType.blank, Colors.white);
    expect(picture.approximateBytesUsed,
        greaterThan(blank.approximateBytesUsed));
    picture.dispose();
    blank.dispose();
  });

  test('a pattern too dense to read when zoomed far out is skipped', () {
    // Spacing times zoom falls under the on-screen minimum: nothing is drawn.
    final blank = _paint(TemplateType.blank, Colors.white);
    final picture = _paint(TemplateType.ruled, Colors.white, zoom: 0.01);
    expect(picture.approximateBytesUsed, blank.approximateBytesUsed);
    blank.dispose();
    picture.dispose();
  });
}
