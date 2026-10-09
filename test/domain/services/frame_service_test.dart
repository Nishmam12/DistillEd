import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/domain/services/frame_service.dart';

FrameElement _frame(String id, List<double> g, {int z = 0}) =>
    FrameElement(id: id, zOrder: z, geometryData: g);

SceneShapeElement _rect(String id, List<double> g, {int z = 1}) =>
    SceneShapeElement(
      id: id,
      zOrder: z,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 1,
    );

void main() {
  final frame = _frame('f', [0, 0, 100, 100]);
  final inside = _rect('in', [40, 40, 60, 60]); // centre (50,50)
  final outside = _rect('out', [200, 200, 220, 220]); // centre (210,210)
  final all = [frame, inside, outside];

  test('membersOf captures only elements centred inside the frame', () {
    final members = FrameService.membersOf(frame, all);
    expect(members.map((e) => e.id), ['in']);
  });

  test('expandWithMembers pulls a frame\'s contents into the move set', () {
    final expanded = FrameService.expandWithMembers({'f'}, all);
    expect(expanded, {'f', 'in'});
  });

  test('expandWithMembers leaves a non-frame selection unchanged', () {
    expect(FrameService.expandWithMembers({'in'}, all), {'in'});
  });

  test('clipBoundsByElement maps each member to its frame bounds', () {
    final clip = FrameService.clipBoundsByElement(all);
    expect(clip.keys, ['in']);
    expect(clip['in'], const Rect.fromLTRB(0, 0, 100, 100));
  });
}
