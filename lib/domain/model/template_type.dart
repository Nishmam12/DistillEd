// Enum defining available canvas background template types.

import 'package:flutter/material.dart';

enum TemplateType {
  blank(displayName: 'Blank', iconData: Icons.crop_square),
  ruled(displayName: 'Ruled', iconData: Icons.format_align_left),
  dotted(displayName: 'Dotted', iconData: Icons.more_horiz),
  grid(displayName: 'Grid', iconData: Icons.grid_on),
  engineeringGrid(displayName: 'Engineering', iconData: Icons.grid_4x4);

  const TemplateType({
    required this.displayName,
    required this.iconData,
  });

  final String displayName;
  final IconData iconData;
}
