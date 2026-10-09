import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/domain/services/alignment_service.dart';

SceneShapeElement _rect(String id, List<double> g) => SceneShapeElement(
      id: id,
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 1,
    );

void main() {
  test('align left moves all elements to the leftmost edge', () {
    final out = AlignmentService.align([
      _rect('a', [0, 0, 10, 10]),
      _rect('b', [20, 0, 30, 10]),
    ], AlignEdge.left);
    final b = out.firstWhere((e) => e.id == 'b') as SceneShapeElement;
    expect(b.geometryData[0], 0); // moved from x=20 to x=0
  });

  test('align top moves all elements to the topmost edge', () {
    final out = AlignmentService.align([
      _rect('a', [0, 5, 10, 15]),
      _rect('b', [0, 30, 10, 40]),
    ], AlignEdge.top);
    final b = out.firstWhere((e) => e.id == 'b') as SceneShapeElement;
    expect(b.geometryData[1], 5);
  });

  test('distribute spaces the middle element evenly', () {
    final out = AlignmentService.distribute([
      _rect('a', [0, 0, 10, 10]), // centre x = 5
      _rect('b', [40, 0, 50, 10]), // centre x = 45
      _rect('c', [100, 0, 110, 10]), // centre x = 105
    ], SceneAxis.horizontal);
    final b = out.firstWhere((e) => e.id == 'b') as SceneShapeElement;
    // even spacing → middle centre at (5 + 105) / 2 = 55 → left = 50
    expect(b.geometryData[0], closeTo(50, 1e-9));
  });

  test('align skips locked elements and returns only what moved', () {
    final locked = _rect('l', [50, 0, 60, 10]).copyWith(isLocked: true);
    final out = AlignmentService.align([
      _rect('a', [0, 0, 10, 10]),
      _rect('b', [20, 0, 30, 10]),
      locked,
    ], AlignEdge.left);
    expect(out.map((e) => e.id), ['b']);
  });

  test('align with fewer than two unlocked elements is a no-op', () {
    final out = AlignmentService.align([
      _rect('a', [0, 0, 10, 10]),
      _rect('l', [50, 0, 60, 10]).copyWith(isLocked: true),
    ], AlignEdge.left);
    expect(out, isEmpty);
  });
}
