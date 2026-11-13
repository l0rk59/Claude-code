import 'dart:convert';

/// A tool the model asked to use.
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  /// What the model wrote before the call (its reasoning), without its
  /// thinking tags.
  final String before;

  const ToolCall(this.name, this.arguments, {this.before = ''});
}

/// Finds a tool call in a model's reply. Models are trained on different
/// formats, so several are read:
///
/// - `<tool_call>{"name": …, "arguments": {…}}</tool_call>` (Qwen, and
///   what the agents ask for);
/// - a JSON object with "name" and "arguments" (or "parameters"), bare or
///   in a ```json block;
/// - `<|tool_call_start|>[name(arg="value")]<|tool_call_end|>` (Liquid's
///   LFM models).
///
/// Only names in [known] count, so JSON in an ordinary answer isn't taken
/// for a call.
class ToolCallParser {
  static const openTag = '<tool_call>';
  static const closeTag = '</tool_call>';
  static const _lfmOpen = '<|tool_call_start|>';
  static const _lfmClose = '<|tool_call_end|>';

  /// Strings at which generation can stop: the call is complete there.
  static const stopSequences = [closeTag, _lfmClose];

  static ToolCall? parse(String reply, Set<String> known) {
    final text = withoutThinking(reply);

    // <tool_call>{…}</tool_call>, the closing tag possibly cut by a stop.
    final tagged = text.indexOf(openTag);
    if (tagged >= 0) {
      final call = _fromJson(
          _firstObject(text.substring(tagged + openTag.length)), known);
      if (call != null) {
        return ToolCall(call.name, call.arguments,
            before: text.substring(0, tagged).trim());
      }
    }

    // <|tool_call_start|>[name(arg="value", n=3)]
    final lfm = text.indexOf(_lfmOpen);
    if (lfm >= 0) {
      final call = _fromPython(text.substring(lfm + _lfmOpen.length), known);
      if (call != null) {
        return ToolCall(call.name, call.arguments,
            before: text.substring(0, lfm).trim());
      }
    }

    // A bare or fenced JSON object.
    for (var start = text.indexOf('{');
        start >= 0;
        start = text.indexOf('{', start + 1)) {
      final object = _firstObject(text.substring(start));
      final call = _fromJson(object, known);
      if (call != null) {
        var before = text.substring(0, start).trim();
        before = before.replaceFirst(RegExp(r'```(?:json)?\s*$'), '').trim();
        return ToolCall(call.name, call.arguments, before: before);
      }
    }
    return null;
  }

  /// [text] without `<think>…</think>` blocks (an unclosed one runs to the
  /// end).
  static String withoutThinking(String text) => text
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
      .replaceAll(RegExp(r'<think>[\s\S]*$'), '')
      .trim();

  /// The first balanced `{…}` at the start of [text] (after spaces), or
  /// null.
  static String? _firstObject(String text) {
    final start = text.indexOf('{');
    if (start < 0 || text.substring(0, start).trim().isNotEmpty) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  static ToolCall? _fromJson(String? object, Set<String> known) {
    if (object == null) return null;
    Object? data;
    try {
      data = jsonDecode(object);
    } catch (_) {
      return null;
    }
    if (data is! Map) return null;
    final name = data['name'] ?? (data['function'] is Map ? data['function']['name'] : null);
    if (name is! String || !known.contains(name)) return null;
    var args = data['arguments'] ??
        data['parameters'] ??
        data['args'] ??
        (data['function'] is Map ? data['function']['arguments'] : null);
    // Some models send the arguments as a JSON string.
    if (args is String) {
      try {
        args = jsonDecode(args);
      } catch (_) {
        args = <String, dynamic>{};
      }
    }
    return ToolCall(
        name, args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{});
  }

  /// `[name(a="x", b=3)]`, as LFM models write calls.
  static ToolCall? _fromPython(String text, Set<String> known) {
    final match = RegExp(r'^\s*\[?\s*([A-Za-z_]\w*)\s*\(([\s\S]*?)\)\s*\]?')
        .firstMatch(text);
    if (match == null || !known.contains(match[1])) return null;
    final args = <String, dynamic>{};
    final pair = RegExp(
        r'''(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^,]+)''');
    for (final m in pair.allMatches(match[2]!)) {
      var value = m[2]!.trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        args[m[1]!] = value.substring(1, value.length - 1);
      } else {
        args[m[1]!] = num.tryParse(value) ?? value;
      }
    }
    return ToolCall(match[1]!, args);
  }
}
