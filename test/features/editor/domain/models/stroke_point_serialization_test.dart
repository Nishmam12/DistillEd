import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';

void main() {
  group('StrokePoint timestamp serialization', () {
    test('toMap omits t when null (legacy-compatible output)', () {
      const p = StrokePoint(x: 1, y: 2, pressure: 0.7);
      final map = p.toMap();
      expect(map.containsKey('t'), isFalse,
          reason: 'null t must not be written, so old readers see no new key');
    });

    test('toMap includes t when set', () {
      const p = StrokePoint(x: 1, y: 2, pressure: 0.7, t: 1234);
      expect(p.toMap()['t'], 1234);
    });

    test('round-trip preserves t', () {
      const p = StrokePoint(
          x: 1.5, y: -2.25, pressure: 0.9, simulatePressure: true, t: 987654);
      final restored = StrokePoint.fromMap(p.toMap());
      expect(restored.x, p.x);
      expect(restored.y, p.y);
      expect(restored.pressure, p.pressure);
      expect(restored.simulatePressure, p.simulatePressure);
      expect(restored.t, 987654);
    });

    test('fromMap on a legacy map without t yields t == null', () {
      final restored = StrokePoint.fromMap({'x': 3.0, 'y': 4.0, 'p': 0.5});
      expect(restored.t, isNull);
      expect(restored.x, 3.0);
      expect(restored.pressure, 0.5);
    });

    test('fromMap accepts t as num (JSON may decode int or double)', () {
      final restored =
          StrokePoint.fromMap({'x': 0.0, 'y': 0.0, 'p': 0.5, 't': 42.0});
      expect(restored.t, 42);
    });

    test('copyWith preserves t by default and can override it', () {
      const p = StrokePoint(x: 1, y: 2, t: 100);
      expect(p.copyWith(x: 9).t, 100);
      expect(p.copyWith(t: 200).t, 200);
    });
  });

  group('Stroke JSON round-trip (the .ink file path)', () {
    test('mixed timestamped and legacy points survive encode/decode', () {
      const stroke = Stroke(
        id: '1',
        color: 0xFF000000,
        size: 4,
        points: [
          StrokePoint(x: 0, y: 0, pressure: 0.5, t: 10),
          StrokePoint(x: 1, y: 1, pressure: 0.6), // no timestamp
          StrokePoint(x: 2, y: 2, pressure: 0.7, t: 30),
        ],
      );

      // Same encode→decode path InkFileStorage uses.
      final json = jsonEncode([stroke.toMap()]);
      final decoded = (jsonDecode(json) as List<dynamic>)
          .map((m) => Stroke.fromMap(m as Map<String, dynamic>))
          .toList();

      expect(decoded.single.points[0].t, 10);
      expect(decoded.single.points[1].t, isNull);
      expect(decoded.single.points[2].t, 30);
    });

    test('a legacy .ink payload (no t anywhere) still parses', () {
      const legacyJson =
          '[{"id":"7","color":4278190080,"size":4.0,"opacity":1.0,'
          '"isEraser":false,"points":[{"x":0.0,"y":0.0,"p":0.5},'
          '{"x":5.0,"y":5.0,"p":0.5,"sim":true}]}]';

      final decoded = (jsonDecode(legacyJson) as List<dynamic>)
          .map((m) => Stroke.fromMap(m as Map<String, dynamic>))
          .toList();

      final points = decoded.single.points;
      expect(points, hasLength(2));
      expect(points.every((p) => p.t == null), isTrue);
      expect(points[1].simulatePressure, isTrue);
    });
  });
}
