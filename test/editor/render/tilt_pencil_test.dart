// The tilt-shaded pencil: a stylus leaning over draws a broader stroke, like
// graphite laid on its side; the lean is kept with the stroke.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/data/persistence/scene_element_codec.dart';
import 'package:margo/data/persistence/scene_element_record_mapper.dart';
import 'package:margo/domain/model/element_style.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/domain/model/stroke_point.dart';
import 'package:margo/editor/render/freehand_path.dart';

List<StrokePoint> _line(double tilt) => [
      for (var i = 0; i <= 20; i++)
        StrokePoint(x: i * 10.0, y: 100, pressure: 0.5, tilt: tilt),
    ];

double _height(List<StrokePoint> pts) {
  final out = FreehandPath.outline(pts, 6, kind: PenKind.shading);
  final ys = out.map((o) => o.dy);
  return ys.reduce(math.max) - ys.reduce(math.min);
}

FreehandElement _stroke(List<StrokePoint> points) => FreehandElement(
    id: 's', zOrder: 0, color: 0xFF000000, size: 6,
    penKind: PenKind.shading, points: points);

void main() {
  test('leaning the pencil over broadens the stroke', () {
    expect(_height(_line(math.pi / 2.2)), greaterThan(_height(_line(0.2)) * 2));
  });

  test('a stroke with no tilt draws as the shading pencil always did', () {
    final upright = _line(0);
    final before = FreehandPath.outline(
        [for (final p in upright) StrokePoint(x: p.x, y: p.y, pressure: 0.5)],
        6,
        kind: PenKind.shading);
    expect(FreehandPath.outline(upright, 6, kind: PenKind.shading), before);
  });

  test('tilt is kept through the database record and the JSON codec', () {
    final pts = [
      const StrokePoint(x: 0, y: 0, tilt: 0.4),
      const StrokePoint(x: 5, y: 5, tilt: 0.9),
    ];
    final viaRecord = SceneElementRecordMapper.fromRecord(
        SceneElementRecordMapper.toRecord(_stroke(pts), pageId: 1, notebookId: 1))
        as FreehandElement;
    expect([for (final p in viaRecord.points) p.tilt], [0.4, 0.9]);
    final viaJson = SceneElementCodec.decode(
        SceneElementCodec.encode(_stroke(pts))) as FreehandElement;
    expect([for (final p in viaJson.points) p.tilt], [0.4, 0.9]);
  });

  test('a stroke without tilt stores none', () {
    final record = SceneElementRecordMapper.toRecord(
        _stroke(const [StrokePoint(x: 0, y: 0)]), pageId: 1, notebookId: 1);
    expect(record.pointTilt, isEmpty);
    expect(SceneElementCodec.encode(_stroke(const [StrokePoint(x: 0, y: 0)])),
        isNot(contains('pointTilt')));
  });
}
