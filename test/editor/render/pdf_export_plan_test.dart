import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/scene_element.dart';
import 'package:margo/editor/render/pdf_export_plan.dart';

void main() {
  testWidgets('a text box is broken into the lines the canvas draws',
      (tester) async {
    const t = TextElement(
      id: 't',
      zOrder: 0,
      geometryData: [10, 20, 130, 200],
      text: 'Mitosis has four phases and ends in two cells',
      color: 0xFF000000,
      fontSize: 16,
    );
    final block = planTextBlock(t, const {})!;
    expect(block.lines.length, greaterThan(1), reason: 'it wraps at 120 wide');
    expect(block.lines.map((l) => l.text).join(' '), t.text);
    for (final l in block.lines) {
      expect(l.left, greaterThanOrEqualTo(10));
      expect(l.width, lessThanOrEqualTo(120.5));
    }
    // Baselines go down the box, one line after another.
    for (var i = 1; i < block.lines.length; i++) {
      expect(block.lines[i].baseline, greaterThan(block.lines[i - 1].baseline));
    }
    expect(block.centre, const Rect.fromLTRB(10, 20, 130, 200).center);
  });

  testWidgets('empty text has nothing to lay out', (tester) async {
    expect(
        planTextBlock(
            const TextElement(
                id: 't',
                zOrder: 0,
                geometryData: [0, 0, 10, 10],
                text: '',
                color: 0xFF000000),
            const {}),
        isNull);
  });

  test('Bangla is the text the PDF fonts cannot shape', () {
    expect(needsShaping('কোষ বিভাজন'), isTrue);
    expect(needsShaping('Cell division'), isFalse);
  });
}
