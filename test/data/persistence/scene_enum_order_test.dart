// SceneElementRecord stores these enums by position (`@enumerated`), so
// reordering or inserting a value in the middle silently changes what every
// saved element means. New values go at the END; this test fails if one doesn't.

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/scene_element.dart';

List<String> _names(List<Enum> values) => [for (final v in values) v.name];

void main() {
  test('stored enums keep their order', () {
    expect(_names(SceneElementKind.values),
        ['freehand', 'shape', 'text', 'image', 'frame']);
    expect(_names(ShapeType.values), [
      'line', 'arrow', 'circle', 'rectangle', 'triangle', 'polygon', 'textBox',
      'svgImage', 'diamond', //
    ]);
    expect(_names(FillStyle.values), ['hachure', 'crossHatch', 'solid']);
    expect(_names(StrokeStyle.values), ['solid', 'dashed', 'dotted']);
    expect(_names(EdgeStyle.values), ['sharp', 'round']);
    expect(_names(Arrowhead.values), ['none', 'triangle', 'dot', 'bar']);
    expect(_names(TextAlignKind.values), ['left', 'center', 'right']);
  });
}
