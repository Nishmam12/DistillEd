// Round-trips the Phase 3 style fields through the Isar record mapper.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/data/persistence/scene_element_record_mapper.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

void main() {
  test('shape style fields survive the round-trip', () {
    const s = SceneShapeElement(
      id: 's',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 10, 10],
      color: 0xFF000000,
      strokeWidth: 2,
      fillStyle: FillStyle.crossHatch,
      strokeStyle: StrokeStyle.dotted,
      edges: EdgeStyle.round,
      startArrowhead: Arrowhead.dot,
      endArrowhead: Arrowhead.bar,
      elbowed: true,
    );
    final back = SceneElementRecordMapper.fromRecord(
        SceneElementRecordMapper.toRecord(s, notebookId: 1, pageId: 1))
        as SceneShapeElement;

    expect(back.fillStyle, FillStyle.crossHatch);
    expect(back.strokeStyle, StrokeStyle.dotted);
    expect(back.edges, EdgeStyle.round);
    expect(back.startArrowhead, Arrowhead.dot);
    expect(back.endArrowhead, Arrowhead.bar);
    expect(back.elbowed, true);
  });

  test('text align + containerId survive the round-trip', () {
    const t = TextElement(
      id: 't',
      zOrder: 0,
      geometryData: [0, 0, 100, 30],
      text: 'hi',
      color: 0xFF000000,
      align: TextAlignKind.center,
      containerId: 'box',
    );
    final back = SceneElementRecordMapper.fromRecord(
        SceneElementRecordMapper.toRecord(t, notebookId: 1, pageId: 1))
        as TextElement;

    expect(back.align, TextAlignKind.center);
    expect(back.containerId, 'box');
  });
}
