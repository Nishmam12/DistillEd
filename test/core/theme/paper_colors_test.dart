// Paper and pen ink are content, not chrome. They are plain constants that no
// app theme may remap: a page set to Cream stays Cream with the lights off, and
// a stroke keeps the colour it was drawn in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distill_ed/core/theme/paper_colors.dart';

void main() {
  group('paper and pen ink are content, not chrome', () {
    test('paper colours are fixed values with no dark counterpart', () {
      expect(PaperColors.paperWhite, const Color(0xFFFFFFFF));
      expect(PaperColors.paperCream, const Color(0xFFFAF4EA));
      expect(PaperColors.paperBlush, const Color(0xFFFBEFEA));
    });

    test('the canonical pen palette is pinned', () {
      expect(PaperColors.penPalette, hasLength(10));
      expect(PaperColors.penPalette.first, const Color(0xFF33302E)); // ink
      expect(PaperColors.penPalette.last, const Color(0xFFFFFFFF)); // white
    });
  });
}
