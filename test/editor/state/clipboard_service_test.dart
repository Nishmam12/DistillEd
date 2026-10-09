import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';
import 'package:distill_ed/editor/state/clipboard_service.dart';

const _els = <SceneElement>[
  SceneShapeElement(
    id: 'a',
    zOrder: 0,
    shapeType: ShapeType.rectangle,
    geometryData: [0, 0, 10, 10],
    color: 0xFF000000,
    strokeWidth: 1,
    groupId: 'g',
  ),
  SceneShapeElement(
    id: 'b',
    zOrder: 1,
    shapeType: ShapeType.circle,
    geometryData: [20, 20, 40, 40],
    color: 0xFF000000,
    strokeWidth: 1,
    groupId: 'g',
  ),
];

void main() {
  test('encode then tryDecode round-trips the elements', () {
    final text = ClipboardService.encode(_els);
    final back = ClipboardService.tryDecode(text);
    expect(back, isNotNull);
    expect(back!.map((e) => e.id), ['a', 'b']);
    expect(back.first, isA<SceneShapeElement>());
  });

  test('tryDecode rejects text that is not our clipboard format', () {
    expect(ClipboardService.tryDecode(null), isNull);
    expect(ClipboardService.tryDecode(''), isNull);
    expect(ClipboardService.tryDecode('just some text'), isNull);
    expect(
      ClipboardService.tryDecode(jsonEncode({'type': 'other', 'elements': []})),
      isNull,
    );
  });

  test('pasteTransform offsets and re-ids while keeping the group together', () {
    var n = 0;
    final pasted = ClipboardService.pasteTransform(
      _els,
      offset: const Offset(5, 7),
      nextId: () => 'p${n++}',
    );

    // New element ids.
    expect(pasted.map((e) => e.id).toSet().intersection({'a', 'b'}), isEmpty);
    // Original group 'g' is remapped to a single new shared group.
    final groups = pasted.map((e) => e.groupId).toSet();
    expect(groups.length, 1);
    expect(groups.first, isNot('g'));
    // Geometry shifted by the offset.
    final a = pasted.first as SceneShapeElement;
    expect(a.geometryData[0], closeTo(5, 1e-6));
    expect(a.geometryData[1], closeTo(7, 1e-6));
  });
}
