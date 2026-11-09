import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/l10n/fr.dart';

/// Checks the French translations against the text the code translates:
/// every `'…'.tr` / `'…'.trParams(…)` has an entry, entries keep their
/// @placeholders, and no entry is left over from text that changed.
void main() {
  final literals = [
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File &&
          file.path.endsWith('.dart') &&
          !file.path.contains(
              '${Platform.pathSeparator}l10n${Platform.pathSeparator}'))
        ..._DartStrings(file.path, file.readAsStringSync()).literals(),
  ];
  final translated = literals.where((l) => l.translated).toList();

  test('translated text is a plain literal', () {
    final problems = [
      for (final l in translated)
        if (l.interpolated)
          '${l.where}: use @placeholders with trParams, not \$: "${l.value}"',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every translated text has a French translation', () {
    final missing = <String>{
      for (final l in translated)
        if (!l.interpolated && !fr.containsKey(l.value))
          '${l.where}: "${_show(l.value)}"',
    };
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('French translations keep the placeholders', () {
    final placeholder = RegExp(r'@\w+');
    Set<String> names(String s) =>
        placeholder.allMatches(s).map((m) => m[0]!).toSet();
    final problems = [
      for (final e in fr.entries)
        if (e.value.trim().isEmpty)
          'empty translation for "${_show(e.key)}"'
        else if (!_sameSet(names(e.key), names(e.value)))
          '"${_show(e.key)}" → "${_show(e.value)}"',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  // trParams replaces '@m' inside '@minutes' too.
  test('no placeholder is the start of another in the same text', () {
    final placeholder = RegExp(r'@(\w+)');
    final problems = [
      for (final key in fr.keys)
        for (final a in placeholder.allMatches(key).map((m) => m[1]!).toSet())
          for (final b in placeholder.allMatches(key).map((m) => m[1]!).toSet())
            if (a != b && b.startsWith(a)) '"${_show(key)}": @$a and @$b',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no French translation is left unused', () {
    final inCode = literals.map((l) => l.value).toSet();
    final unused = [
      for (final key in fr.keys)
        if (!inCode.contains(key)) '"${_show(key)}"',
    ];
    expect(unused, isEmpty, reason: unused.join('\n'));
  });
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

String _show(String s) => s.replaceAll('\n', r'\n');

/// A string literal in Dart source, adjacent pieces joined.
class _Literal {
  final String where;
  final String value;
  final bool interpolated;

  /// Followed by `.tr` or `.trParams(`.
  final bool translated;
  const _Literal(this.where, this.value, this.interpolated, this.translated);
}

/// Just enough of a Dart lexer to find string literals: skips comments,
/// decodes escapes, joins adjacent literals and also finds the literals
/// inside `${…}`.
class _DartStrings {
  final String path;
  final String src;
  int i = 0;
  final _found = <_Literal>[];
  _DartStrings(this.path, this.src);

  static final _identChar = RegExp(r'[\w$]');
  static final _trSuffix = RegExp(r'^\s*\.(tr|trParams)\b');

  List<_Literal> literals() {
    while (i < src.length) {
      if (_skipComment()) continue;
      if (!_atString()) {
        i++;
        continue;
      }
      _readLiteral();
    }
    return _found;
  }

  /// Reads the literal at [i], with any adjacent pieces, into [_found].
  void _readLiteral() {
    final start = i;
    final text = StringBuffer();
    var interpolated = false;
    while (true) {
      final (value, interp) = _readString();
      text.write(value);
      interpolated |= interp;
      final end = i;
      while (i < src.length) {
        if (src[i].trim().isEmpty) {
          i++;
        } else if (!_skipComment()) {
          break;
        }
      }
      if (i < src.length && _atString()) continue;
      i = end;
      break;
    }
    final after = src.substring(i, math.min(i + 40, src.length));
    _found.add(_Literal('$path:${_lineOf(start)}', text.toString(),
        interpolated, _trSuffix.hasMatch(after)));
  }

  int _lineOf(int offset) =>
      '\n'.allMatches(src.substring(0, offset)).length + 1;

  bool _skipComment() {
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      return true;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      return true;
    }
    return false;
  }

  bool _atString() {
    final c = src[i];
    if (c == "'" || c == '"') return true;
    return c == 'r' &&
        i + 1 < src.length &&
        (src[i + 1] == "'" || src[i + 1] == '"') &&
        (i == 0 || !_identChar.hasMatch(src[i - 1]));
  }

  /// Reads one literal at [i]; returns its text (with U+0000 where it
  /// interpolates) and whether it interpolates.
  (String, bool) _readString() {
    final raw = src[i] == 'r';
    if (raw) i++;
    final q = src[i];
    final delimiter = src.startsWith(q * 3, i) ? q * 3 : q;
    i += delimiter.length;
    final out = StringBuffer();
    var interpolated = false;
    while (i < src.length) {
      if (src.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      final c = src[i];
      if (!raw && c == r'\') {
        out.write(_escape());
      } else if (!raw && c == r'$') {
        interpolated = true;
        out.write('\u0000');
        if (src.startsWith(r'${', i)) {
          i += 2;
          _skipExpression();
        } else {
          i++;
          while (
              i < src.length && _identChar.hasMatch(src[i]) && src[i] != r'$') {
            i++;
          }
        }
      } else {
        out.write(c);
        i++;
      }
    }
    return (out.toString(), interpolated);
  }

  void _skipExpression() {
    var depth = 1;
    while (i < src.length) {
      if (_skipComment()) continue;
      if (_atString()) {
        _readLiteral();
        continue;
      }
      final c = src[i++];
      if (c == '{') depth++;
      if (c == '}' && --depth == 0) return;
    }
  }

  String _escape() {
    final c = src[i + 1];
    i += 2;
    String hex(int length) {
      final value = int.parse(src.substring(i, i + length), radix: 16);
      i += length;
      return String.fromCharCode(value);
    }

    switch (c) {
      case 'n':
        return '\n';
      case 't':
        return '\t';
      case 'r':
        return '\r';
      case 'b':
        return '\b';
      case 'f':
        return '\f';
      case 'v':
        return '\v';
      case 'x':
        return hex(2);
      case 'u':
        if (src[i] == '{') {
          final end = src.indexOf('}', i);
          final value = int.parse(src.substring(i + 1, end), radix: 16);
          i = end + 1;
          return String.fromCharCode(value);
        }
        return hex(4);
      default:
        return c;
    }
  }
}
