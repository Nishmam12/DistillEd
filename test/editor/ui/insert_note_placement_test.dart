import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/editor/ui/notebook_editor_screen.dart';

void main() {
  // The slice of scene currently on screen. Placement must stay inside it —
  // a note dropped below the fold is one the user has to zoom out to find.
  const bounds = Rect.fromLTWH(0, 0, 800, 1000);
  const w = 360.0;
  const h = 80.0;
  const gap = 16.0;

  // Where an unobstructed note lands: inset from the viewport's top-left.
  const firstSlot = Rect.fromLTWH(gap, gap, w, h);

  group('placeNoteSlot', () {
    test('empty page places the note at the top-left of the visible area', () {
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: []);
      expect(box, firstSlot);
    });

    test('an overlapping element pushes the note below it', () {
      // A block sitting right where the note would start.
      const block = Rect.fromLTWH(0, 0, 400, 120); // bottom = 120
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: [block]);
      expect(box!.top, block.bottom + gap);
      expect(box.left, bounds.left + gap);
    });

    test('repeated content stacks the note below the lowest, never overlapping',
        () {
      const a = Rect.fromLTWH(0, 0, 400, 60); // bottom = 60
      const b = Rect.fromLTWH(0, 80, 400, 60); // bottom = 140
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: [a, b]);
      expect(box!.top, b.bottom + gap);
      expect(box.overlaps(a), isFalse);
      expect(box.overlaps(b), isFalse);
    });

    test('content to the side (no horizontal overlap) does not move the note',
        () {
      // Handwriting far to the right of the note's x-range (16..376).
      const sideContent = Rect.fromLTWH(600, 0, 200, 400);
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: [sideContent]);
      expect(box, firstSlot,
          reason: 'a note need not slide past content it never overlaps');
    });

    test('the note is always placed inside the visible bounds', () {
      const block = Rect.fromLTWH(0, 0, 400, 300);
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: [block]);
      expect(bounds.contains(box!.topLeft), isTrue);
      expect(box.bottom, lessThanOrEqualTo(bounds.bottom));
    });

    test('returns null when the visible area is full', () {
      // Wall-to-wall content down the whole viewport: nothing can fit.
      final blocks = [
        for (var i = 0; i < 40; i++) Rect.fromLTWH(0, i * 30.0, 800, 28),
      ];
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: blocks);
      expect(box, isNull,
          reason: 'the caller prompts "no space" rather than dropping the '
              'note off-screen');
    });

    test('returns null when the note is taller than the visible area', () {
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: bounds.height + 1, existing: []);
      expect(box, isNull);
    });

    test('a clear gap between blocks is used rather than reporting no space',
        () {
      // Two bands with a comfortable hole between them.
      const top = Rect.fromLTWH(0, 0, 800, 100);
      const lower = Rect.fromLTWH(0, 400, 800, 500);
      final box = placeNoteSlot(
          bounds: bounds, width: w, height: h, existing: [top, lower]);
      expect(box, isNotNull);
      expect(box!.overlaps(top), isFalse);
      expect(box.overlaps(lower), isFalse);
    });
  });
}
