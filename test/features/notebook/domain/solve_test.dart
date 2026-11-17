import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/notebook/domain/solve.dart';

void main() {
  test('handwriting symbols become a sum; an old answer is dropped', () {
    expect(sumIn('12 × 4 ='), '12*4');
    expect(sumIn('12x4=48'), '12*4');
    expect(sumIn('15 ÷ 3'), '15/3');
    expect(sumIn('7 − 2'), '7-2');
    expect(sumIn('3² + 1'), '3^2+1');
    expect(sumIn('1,000 + 5'), '1000+5');
    expect(sumIn('(2+3)*4'), '(2+3)*4');
  });

  test('words, a lone number or nothing are not sums', () {
    expect(sumIn('mitosis'), isNull);
    expect(sumIn('42'), isNull);
    expect(sumIn(''), isNull);
    expect(sumIn('2 apples + 3'), isNull);
  });

  test('worked out, with the two errors', () async {
    final s = await solveWritten('12 × 4 =');
    expect(s, isA<Solved>());
    expect((s as Solved).answer, '48');
    expect(((await solveWritten('7 ÷ 2')) as Solved).answer, '3.5');
    expect(await solveWritten('5 / 0'), isA<OutOfRange>());
    expect(await solveWritten('hello'), isA<NoSum>());
    expect(await solveWritten('2 + * 3'), isA<NoSum>());
  });
}
