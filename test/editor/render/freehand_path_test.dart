import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/render/freehand_path.dart';
import 'package:inkflow/domain/model/stroke_point.dart';

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
}
