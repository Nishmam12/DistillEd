import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/domain/model/template_type.dart';
import 'package:distill_ed/widgets/template_icons.dart';

void main() {
  test('every template has an icon, and the picker shows the right one', () {
    expect(TemplateType.blank.iconData, Icons.crop_square);
    expect(TemplateType.ruled.iconData, Icons.format_align_left);
    expect(TemplateType.dotted.iconData, Icons.more_horiz);
    expect(TemplateType.grid.iconData, Icons.grid_on);
    expect(TemplateType.engineeringGrid.iconData, Icons.grid_4x4);
  });

  test('the stored template order is unchanged (it is persisted by position)',
      () {
    expect(TemplateType.values.map((t) => t.name).toList(), [
      'blank',
      'ruled',
      'dotted',
      'grid',
      'engineeringGrid',
    ]);
  });
}
