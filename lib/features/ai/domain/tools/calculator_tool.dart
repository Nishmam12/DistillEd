// Pure Dart arithmetic — the only Loop 3.4 tool that never touches the
// network. A hand-written recursive-descent parser rather than an `eval`
// package: no injection surface, no dependency, and the grammar is small
// enough (six productions) that hand-rolling it is less code than wiring a
// general-purpose expression library for a `+ - * / ^ ()` subset.

import 'dart:math' as math;

import 'tool.dart';

class CalculatorTool implements Tool {
  /// Defensive bound against pathological input (e.g. deeply nested
  /// parens driving unbounded recursion) — no legitimate arithmetic
  /// expression a model would generate needs to be this long.
  static const int _maxExpressionLength = 200;

  const CalculatorTool();

  @override
  String get name => 'calculator';

  @override
  String get description =>
      'Evaluates an arithmetic expression and returns the numeric result. '
      'Supports +, -, *, /, ^ (power), parentheses, and decimals — e.g. '
      '"340 * 0.15" or "(12 + 8) / 4". Always use this for arithmetic '
      'instead of computing it yourself.';

  @override
  Map<String, dynamic> get parameterSchema => const {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description': 'A numeric expression using +, -, *, /, ^ and '
                'parentheses only — no words or units (write "340 * 0.15", '
                'not "15% of 340").',
          },
        },
        'required': ['expression'],
      };

  @override
  Future<ToolExecutionResult> execute(Map<String, dynamic> arguments) async {
    final expression = arguments['expression'];
    if (expression is! String || expression.trim().isEmpty) {
      return const ToolExecutionResult.error(
          'Missing or empty "expression" argument.');
    }
    if (expression.length > _maxExpressionLength) {
      return const ToolExecutionResult.error('Expression is too long.');
    }
    try {
      final value = _CalculatorParser(expression).parse();
      if (value.isNaN || value.isInfinite) {
        return const ToolExecutionResult.error(
            'Result is not a finite number (e.g. division by zero).');
      }
      return ToolExecutionResult.ok(_format(value));
    } on _CalculatorError catch (e) {
      return ToolExecutionResult.error(e.message);
    }
  }

  /// Whole numbers print without a trailing ".0" — a cleaner value for the
  /// model to relay to the user ("51", not "51.0").
  static String _format(double value) =>
      value == value.roundToDouble() && value.abs() < 1e15
          ? value.toInt().toString()
          : value.toString();
}

class _CalculatorError implements Exception {
  final String message;
  const _CalculatorError(this.message);
}

/// Grammar (unary sits ABOVE power so `-2^2` parses as `-(2^2) == -4`, not
/// `(-2)^2 == 4`, matching conventional math notation; power's exponent
/// recurses into `_unary` rather than `_power` so `2^-2` and `2^3^2`
/// right-associate correctly):
/// ```
/// expression := term (('+'|'-') term)*
/// term       := unary (('*'|'/') unary)*
/// unary      := ('-'|'+') unary | power
/// power      := primary ('^' unary)?
/// primary    := NUMBER | '(' expression ')'
/// ```
class _CalculatorParser {
  final String _source;
  int _pos = 0;

  _CalculatorParser(this._source);

  double parse() {
    _skipWhitespace();
    final value = _expression();
    _skipWhitespace();
    if (_pos != _source.length) {
      throw _CalculatorError(
          'Unexpected character at position $_pos: "${_source[_pos]}".');
    }
    return value;
  }

  double _expression() {
    var value = _term();
    _skipWhitespace();
    while (_pos < _source.length &&
        (_source[_pos] == '+' || _source[_pos] == '-')) {
      final op = _source[_pos++];
      _skipWhitespace();
      final rhs = _term();
      value = op == '+' ? value + rhs : value - rhs;
      _skipWhitespace();
    }
    return value;
  }

  double _term() {
    var value = _unary();
    _skipWhitespace();
    while (_pos < _source.length &&
        (_source[_pos] == '*' || _source[_pos] == '/')) {
      final op = _source[_pos++];
      _skipWhitespace();
      final rhs = _unary();
      if (op == '/' && rhs == 0) {
        throw const _CalculatorError('Division by zero.');
      }
      value = op == '*' ? value * rhs : value / rhs;
      _skipWhitespace();
    }
    return value;
  }

  double _unary() {
    _skipWhitespace();
    if (_pos < _source.length && _source[_pos] == '-') {
      _pos++;
      return -_unary();
    }
    if (_pos < _source.length && _source[_pos] == '+') {
      _pos++;
      return _unary();
    }
    return _power();
  }

  double _power() {
    final base = _primary();
    _skipWhitespace();
    if (_pos < _source.length && _source[_pos] == '^') {
      _pos++;
      _skipWhitespace();
      final exponent = _unary();
      return math.pow(base, exponent).toDouble();
    }
    return base;
  }

  double _primary() {
    _skipWhitespace();
    if (_pos >= _source.length) {
      throw const _CalculatorError('Unexpected end of expression.');
    }
    if (_source[_pos] == '(') {
      _pos++;
      final value = _expression();
      _skipWhitespace();
      if (_pos >= _source.length || _source[_pos] != ')') {
        throw const _CalculatorError('Missing closing ")".');
      }
      _pos++;
      return value;
    }
    final start = _pos;
    if (_source[_pos] == '.' || _isDigit(_source[_pos])) {
      var sawDot = false;
      while (_pos < _source.length &&
          (_isDigit(_source[_pos]) || (_source[_pos] == '.' && !sawDot))) {
        if (_source[_pos] == '.') sawDot = true;
        _pos++;
      }
      final text = _source.substring(start, _pos);
      final value = double.tryParse(text);
      if (value == null) {
        throw _CalculatorError('Not a valid number: "$text".');
      }
      return value;
    }
    throw _CalculatorError(
        'Unexpected character at position $_pos: "${_source[_pos]}".');
  }

  bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  void _skipWhitespace() {
    while (_pos < _source.length && _source[_pos].trim().isEmpty) {
      _pos++;
    }
  }
}
