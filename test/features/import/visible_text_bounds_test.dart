import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/import/pdf_text_layer.dart';

bool visible(double l, double b, double r, double t) => isVisibleTextBounds(
    left: l, bottom: b, right: r, top: t, pageWidth: 600, pageHeight: 800);

void main() {
  test('ordinary text on the page is visible', () {
    expect(visible(50, 700, 60, 712), isTrue);
  });

  test('zero-size text is not', () {
    expect(visible(50, 700, 50, 700), isFalse);
    expect(visible(50, 700, 60, 701), isFalse);
  });

  test('text off the page is not', () {
    expect(visible(-300, 700, -290, 712), isFalse);
    expect(visible(50, 5000, 60, 5012), isFalse);
  });

  test('a combining mark with no width still counts', () {
    expect(visible(50, 700, 50, 712), isTrue);
  });
}
