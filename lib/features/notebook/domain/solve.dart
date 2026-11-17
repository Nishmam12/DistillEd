// Solve (Samsung Notes' "formula calculation"): a handwritten sum, as ML Kit
// read it, worked out with the tutor's calculator. Pure.

import '../../ai/domain/tools/calculator_tool.dart';

sealed class SolveOutcome {
  const SolveOutcome();
}

final class Solved extends SolveOutcome {
  /// What was worked out, in the calculator's symbols ("12*4").
  final String expression;
  final String answer;
  const Solved(this.expression, this.answer);
}

/// Nothing in the selection reads as a sum.
final class NoSum extends SolveOutcome {
  const NoSum();
}

/// It is a sum, but the answer is not a finite number (a division by zero,
/// or too big).
final class OutOfRange extends SolveOutcome {
  const OutOfRange();
}

/// The sum in [text] as the calculator writes it, or null when there is none:
/// handwriting's ×, x, ÷, : and dashes become * / -, ² and ³ become powers,
/// and anything from an "=" on is dropped (the question, not an old answer).
String? sumIn(String text) {
  var s = text.split('=').first.toLowerCase();
  s = s
      .replaceAll(RegExp(r'[×x·•]'), '*')
      .replaceAll(RegExp(r'[÷:]'), '/')
      .replaceAll(RegExp(r'[−–—]'), '-')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll(RegExp(r'(?<=\d),(?=\d{3}\b)'), '') // 1,000
      .replaceAll(RegExp(r'\s+'), '');
  if (!RegExp(r'^[\d.+\-*/^()]+$').hasMatch(s)) return null;
  // A number alone is not a sum.
  if (!RegExp(r'\d').hasMatch(s) || !RegExp(r'\d[+\-*/^]').hasMatch(s)) {
    return null;
  }
  return s;
}

Future<SolveOutcome> solveWritten(String text) async {
  final sum = sumIn(text);
  if (sum == null) return const NoSum();
  final r = await const CalculatorTool().execute({'expression': sum});
  if (r.success) return Solved(sum, r.content);
  return r.content.startsWith('Result is not a finite number') ||
          r.content.startsWith('Division by zero')
      ? const OutOfRange()
      : const NoSum();
}
