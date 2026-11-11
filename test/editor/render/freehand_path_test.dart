import 'package:flutter_test/flutter_test.dart';
import 'package:margo/editor/render/freehand_path.dart';
import 'package:margo/domain/model/scene_element.dart';

void main() {
  test('build returns null for an empty stroke', () {
    expect(FreehandPath.build(const [], 4, isComplete: true), isNull);
  });

  test('build produces a non-empty path for a real stroke', () {
    final path = FreehandPath.build(
      const [
        StrokePoint(x: 0, y: 0),
        StrokePoint(x: 10, y: 0),
        StrokePoint(x: 10, y: 10),
      ],
      4,
      isComplete: true,
    );
    expect(path, isNotNull);
    expect(path!.getBounds().isEmpty, isFalse);
  });

  group('pen types', () {
    // A straight horizontal line pressed lightly then hard.
    List<StrokePoint> line() => [
          for (var i = 0; i <= 40; i++)
            StrokePoint(x: i * 5.0, y: 100, pressure: i < 20 ? 0.15 : 0.95),
        ];

    double height(PenKind kind) => FreehandPath.build(line(), 10,
            isComplete: true, kind: kind)!
        .getBounds()
        .height;

    test('a highlighter keeps one width whatever the pressure', () {
      final light = FreehandPath.build(line().sublist(0, 15), 10,
          isComplete: true, kind: PenKind.highlighter)!;
      final hard = FreehandPath.build(line().sublist(25), 10,
          isComplete: true, kind: PenKind.highlighter)!;
      expect(light.getBounds().height,
          closeTo(hard.getBounds().height, 0.5));
    });

    test('a fountain pen varies more with pressure than a ballpoint', () {
      double spread(PenKind kind) {
        final light = FreehandPath.build(line().sublist(0, 15), 10,
            isComplete: true, kind: kind)!;
        final hard = FreehandPath.build(line().sublist(25), 10,
            isComplete: true, kind: kind)!;
        return hard.getBounds().height - light.getBounds().height;
      }

      expect(spread(PenKind.fountain), greaterThan(spread(PenKind.ballpoint)));
    });

    test('every pen type draws something', () {
      for (final kind in PenKind.values) {
        expect(height(kind), greaterThan(0), reason: kind.name);
      }
    });

    test('a highlighter is see-through and ink is not', () {
      expect(FreehandPath.paintFor(PenKind.highlighter, 0xFFFFE066, 1.0)
          .color.a, lessThan(0.6));
      expect(FreehandPath.paintFor(PenKind.ballpoint, 0xFF000000, 1.0)
          .color.a, 1.0);
    });
  });
}
