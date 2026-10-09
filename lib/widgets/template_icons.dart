// The icon each background template is shown with. Kept out of the domain enum,
// which holds only data, so the domain layer does not depend on Flutter.

import 'package:flutter/material.dart';

import '../domain/model/template_type.dart';

extension TemplateTypeIcon on TemplateType {
  IconData get iconData => switch (this) {
        TemplateType.blank => Icons.crop_square,
        TemplateType.ruled => Icons.format_align_left,
        TemplateType.dotted => Icons.more_horiz,
        TemplateType.grid => Icons.grid_on,
        TemplateType.engineeringGrid => Icons.grid_4x4,
      };
}
