import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/ai/domain/tools/calculator_tool.dart';
import 'package:inkflow/features/ai/domain/tools/tool.dart';

void main() {
  const tool = CalculatorTool();

  Future<ToolExecutionResult> run(String expression) =>
      tool.execute({'expression': expression});

  group('CalculatorTool', () {
    test('adds, subtracts, multiplies, divides', () async {
      expect((await run('2 + 3')).content, '5');
      expect((await run('10 - 4')).content, '6');
      expect((await run('6 * 7')).content, '42');
      expect((await run('9 / 2')).content, '4.5');
    });

    test('respects operator precedence and parentheses', () async {
      expect((await run('2 + 3 * 4')).content, '14');
      expect((await run('(2 + 3) * 4')).content, '20');
    });

    test('handles decimals', () async {
      expect((await run('340 * 0.15')).content, '51');
    });

    test('unary minus binds looser than power (-2^2 == -4)', () async {
      expect((await run('-2^2')).content, '-4');
    });

    test('power is right-associative (2^3^2 == 2^9)', () async {
      expect((await run('2^3^2')).content, '512');
    });

    test('a negative exponent works (2^-2 == 0.25)', () async {
      expect((await run('2^-2')).content, '0.25');
    });

    test('unary minus binds tighter than multiplication (-2 * 3 == -6)',
        () async {
      expect((await run('-2 * 3')).content, '-6');
    });

    test('whole-number results print without a trailing .0', () async {
      final result = await run('4 / 2');
      expect(result.content, '2');
      expect(result.content, isNot(contains('.')));
    });

    test('division by zero is a clear error, not NaN/Infinity', () async {
      final result = await run('1 / 0');
      expect(result.success, isFalse);
      expect(result.content, contains('zero'));
    });

    test('a malformed expression is a clear error', () async {
      final result = await run('2 +');
      expect(result.success, isFalse);
    });

    test('an unbalanced parenthesis is a clear error', () async {
      final result = await run('(2 + 3');
      expect(result.success, isFalse);
    });

    test('a missing expression argument is a clear error', () async {
      final result = await tool.execute({});
      expect(result.success, isFalse);
    });

    test('name and schema are stable for the gateway contract', () {
      expect(tool.name, 'calculator');
      expect(tool.parameterSchema['type'], 'object');
      expect(
        (tool.parameterSchema['required'] as List).contains('expression'),
        isTrue,
      );
    });
  });
}
