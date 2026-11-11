import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:margo/features/notebook/presentation/notebook_editor_screen.dart';

void main() {
  const visible = Rect.fromLTWH(0, 0, 1000, 800);
  const photo = Size(800, 600);

  group('placeImageInView', () {
    test('an empty view puts the picture in the middle', () {
      final box = placeImageInView(
          source: photo, visible: visible, existing: const []);
      expect(box.center, visible.center);
      expect(box.width, 500, reason: 'half the view, aspect kept');
      expect(box.height, 375);
    });

    test('writing in the middle sends it to a clear spot instead', () {
      // Across the middle, leaving room above it.
      const writing = Rect.fromLTWH(250, 420, 500, 200);
      final box = placeImageInView(
          source: photo, visible: visible, existing: const [writing]);
      expect(box.overlaps(writing), isFalse);
      expect(visible.contains(box.topLeft), isTrue);
      expect(visible.contains(box.bottomRight), isTrue);
    });

    test('a full view still places it, in the middle', () {
      const everything = Rect.fromLTWH(0, 0, 1000, 800);
      final box = placeImageInView(
          source: photo, visible: visible, existing: const [everything]);
      expect(box.center, visible.center);
    });

    test('in page mode it stays on the paper', () {
      const page = Rect.fromLTWH(0, 0, 600, 800);
      final box = placeImageInView(
          source: photo, visible: visible, page: page, existing: const []);
      expect(page.contains(box.topLeft), isTrue);
      expect(page.contains(box.bottomRight), isTrue);
    });

    test('an unmeasurable picture gives an empty rect', () {
      final box = placeImageInView(
          source: Size.zero, visible: visible, existing: const []);
      expect(box.isEmpty, isTrue);
    });
  });
}
