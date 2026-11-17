// A stroke's age is measured within the pointer clock only; mixing that clock
// with another made every recorded stroke seek to 0:00.
import 'package:flutter_test/flutter_test.dart';
import 'package:margo/domain/model/stroke_point.dart';

StrokePoint _p(int? t) => StrokePoint(x: 0, y: 0, pressure: 0.5, t: t);

void main() {
  test('age is pen-up time less the first point', () {
    expect(strokeAgeMs([_p(5000), _p(5200)], 5400), 400);
  });

  test('without a pen-up time the last point stands in', () {
    expect(strokeAgeMs([_p(5000), _p(5250)], null), 250);
  });

  test('missing or backwards times give 0, never a negative age', () {
    expect(strokeAgeMs([], 10), 0);
    expect(strokeAgeMs([_p(null)], 10), 0);
    expect(strokeAgeMs([_p(900)], 100), 0);
  });
}
