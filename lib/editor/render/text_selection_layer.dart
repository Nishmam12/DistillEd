// Paints a text selection on a page picture: a translucent band over each line
// of selected words, in scene space, turned with the picture.

import 'package:flutter/rendering.dart';

import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/scene_element.dart';
import '../state/page_text_selection.dart';

class TextSelectionLayer extends CustomPainter {
  final PageTextSelection? selection;
  final ImageElement? image;
  final Color color;

  TextSelectionLayer({
    required this.selection,
    required this.image,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = selection, img = image;
    if (s == null || img == null || s.indexes.isEmpty) return;
    final paint = Paint()..color = color.withValues(alpha: 0.28);
    for (final run in lineRuns(s.words, s.indexes)) {
      final c = cornersOnPage(run, img);
      canvas.drawPath(Path()..addPolygon(c, true), paint);
    }
  }

  @override
  bool shouldRepaint(TextSelectionLayer old) =>
      !identical(old.selection, selection) ||
      !identical(old.image, image) ||
      old.color != color;
}
