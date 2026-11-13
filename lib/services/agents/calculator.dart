import 'dart:math' as math;

/// Evaluates arithmetic for the agents' calculator tool: small models get
/// sums wrong, a calculator doesn't.
///
/// Supports + - * / % ^, parentheses, decimals (with a point or a French
/// comma), pi and e, and the functions sqrt, abs, round, floor, ceil, ln,
/// log (base 10), exp, sin, cos, tan (radians). Anything else is refused:
/// nothing is ever run as code.
class Calculator {
  final String _s;
  int _i = 0;

  Calculator._(this._s);

  /// The value of [expression]. Throws a [FormatException] saying what is
  /// wrong with it.
  static double evaluate(String expression) {
    final text = expression
        .trim()
        // A comma between digits is a decimal comma ("2,5").
        .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('**', '^');
    if (text.isEmpty) throw const FormatException('Empty expression');
    final parser = Calculator._(text);
    final value = parser._sum();
    parser._space();
    if (parser._i < text.length) {
      throw FormatException('Unexpected "${text[parser._i]}"');
    }
    if (value.isNaN || value.isInfinite) {
      throw const FormatException('The result is not a number');
    }
    return value;
  }

  /// [value] written for the model: whole numbers without ".0", others
  /// with at most 10 decimals.
  static String format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(10);
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  void _space() {
    while (_i < _s.length && _s[_i].trim().isEmpty) {
      _i++;
    }
  }

  bool _eat(String c) {
    _space();
    if (_i < _s.length && _s[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }

  double _sum() {
    var value = _product();
    while (true) {
      if (_eat('+')) {
        value += _product();
      } else if (_eat('-')) {
        value -= _product();
      } else {
        return value;
      }
    }
  }

  double _product() {
    var value = _unary();
    while (true) {
      if (_eat('*')) {
        value *= _unary();
      } else if (_eat('/')) {
        final divisor = _unary();
        if (divisor == 0) throw const FormatException('Division by zero');
        value /= divisor;
      } else if (_eat('%')) {
        value %= _unary();
      } else {
        return value;
      }
    }
  }

  // A sign applies after the power: -3^2 = -(3^2).
  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _power();
  }

  double _power() {
    final base = _atom();
    // Right-associative (2^3^2 = 2^9), and the exponent may be signed.
    if (_eat('^')) return math.pow(base, _unary()).toDouble();
    return base;
  }

  static final _functions = <String, double Function(double)>{
    'sqrt': math.sqrt,
    'abs': (x) => x.abs(),
    'round': (x) => x.roundToDouble(),
    'floor': (x) => x.floorToDouble(),
    'ceil': (x) => x.ceilToDouble(),
    'ln': math.log,
    'log': (x) => math.log(x) / math.ln10,
    'exp': math.exp,
    'sin': math.sin,
    'cos': math.cos,
    'tan': math.tan,
  };

  double _atom() {
    _space();
    if (_eat('(')) {
      final value = _sum();
      if (!_eat(')')) throw const FormatException('Missing ")"');
      return value;
    }
    final start = _i;
    while (_i < _s.length && RegExp(r'[0-9.]').hasMatch(_s[_i])) {
      _i++;
    }
    if (_i > start) {
      final number = double.tryParse(_s.substring(start, _i));
      if (number == null) {
        throw FormatException('Bad number "${_s.substring(start, _i)}"');
      }
      return number;
    }
    while (_i < _s.length && RegExp(r'[a-zA-Z]').hasMatch(_s[_i])) {
      _i++;
    }
    final name = _s.substring(start, _i).toLowerCase();
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;
    final function = _functions[name];
    if (function == null) {
      throw FormatException(name.isEmpty
          ? 'Expected a number'
          : 'Unknown function "$name"');
    }
    if (!_eat('(')) throw FormatException('"$name" needs parentheses');
    final argument = _sum();
    if (!_eat(')')) throw const FormatException('Missing ")"');
    return function(argument);
  }
}
