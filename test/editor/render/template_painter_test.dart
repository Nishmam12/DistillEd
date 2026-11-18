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
  _phase8();
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
      // Phase 8.
      TemplateType.ruledNarrow,
      TemplateType.ruledWide,
      TemplateType.gridSmall,
      TemplateType.gridLarge,
      TemplateType.dottedSmall,
      TemplateType.dottedLarge,
      TemplateType.weeklyPlanner,
      TemplateType.monthlyPlanner,
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

class _Sink implements TemplateSink {
  final lines = <(Offset, Offset)>[];
  final points = <Offset>[];
  final boxes = <Rect>[];
  @override
  void line(Offset a, Offset b, Color color, double width) => lines.add((a, b));
  @override
  void dots(List<Offset> centres, Color color, double radius) =>
      points.addAll(centres);
  @override
  void roundRect(Rect rect, double radius, Color color, double width) =>
      boxes.add(rect);
}

_Sink _emit(TemplateType type, {bool bounded = true}) {
  final sink = _Sink();
  TemplatePainter.emit(sink, type, Colors.white,
      region: const Rect.fromLTWH(0, 0, 600, 800), bounded: bounded);
  return sink;
}

// Phase 8: spacings and planners.
void _phase8() {
  test('a spacing is its pattern, further apart or closer', () {
    expect(TemplateType.ruledWide.family, TemplateType.ruled);
    expect(TemplateType.grid.withSpacing(TemplateSpacing.narrow),
        TemplateType.gridSmall);
    expect(TemplateType.cornell.withSpacing(TemplateSpacing.wide),
        TemplateType.cornell, reason: 'no spacings');
    expect(TemplateType.pickable, isNot(contains(TemplateType.dottedLarge)));
    final medium = _emit(TemplateType.ruled).lines.length;
    expect(_emit(TemplateType.ruledNarrow).lines.length, greaterThan(medium));
    expect(_emit(TemplateType.ruledWide).lines.length, lessThan(medium));
  });

  test('planners draw their boxes on a page, ruled lines on an endless one',
      () {
    expect(_emit(TemplateType.weeklyPlanner).boxes, hasLength(8));
    final month = _emit(TemplateType.monthlyPlanner);
    expect(month.boxes, hasLength(1));
    expect(month.lines.length, 2 + 6 + 5); // band, weekday row, 6 cols, 5 rows
    expect(_emit(TemplateType.weeklyPlanner, bounded: false).boxes, isEmpty);
  });
}
