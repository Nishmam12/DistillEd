import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/domain/services/z_order_service.dart';

FreehandElement _el(String id, int z) =>
    FreehandElement(id: id, zOrder: z, color: 0, size: 1, points: const []);

Map<String, int> _z(List<SceneElement> els) =>
    {for (final e in els) e.id: e.zOrder};

void main() {
  final base = [_el('a', 0), _el('b', 1), _el('c', 2)];

  test('bringToFront puts the selection on top', () {
    final z = _z(ZOrderService.bringToFront(base, {'a'}));
    expect(z['a'], 2);
    expect(z['b'], 0);
    expect(z['c'], 1);
  });

  test('sendToBack puts the selection at the bottom', () {
    final z = _z(ZOrderService.sendToBack(base, {'c'}));
    expect(z['c'], 0);
    expect(z['a'], 1);
    expect(z['b'], 2);
  });
}
