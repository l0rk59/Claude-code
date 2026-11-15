import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A function the model may ask to call (OpenAI "tools").
class ChatToolSpec {
  final String name;
  final String description;

  /// JSON schema of the arguments.
  final Map<String, dynamic> parameters;

  const ChatToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

/// A call the model asked for.
class ChatToolCall {
  final String id;
  final String name;

  /// The arguments as the model wrote them (JSON text).
  final String rawArguments;

  const ChatToolCall(
      {required this.id, required this.name, required this.rawArguments});

  /// The arguments, or an empty map when the model wrote invalid JSON.
  Map<String, dynamic> get arguments {
    if (rawArguments.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawArguments);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': rawArguments},
      };
}

/// What one request produced.
class ChatReply {
  final String text;

  /// The model's thinking, when the server sends it apart.
  final String reasoning;
  final List<ChatToolCall> toolCalls;

  /// 'stop', 'length', 'tool_calls', or '' when the stream was cut.
  final String finishReason;
  final int promptTokens;
  final int completionTokens;

  /// Why the request failed; null when it worked.
  final String? error;

  const ChatReply({
    this.text = '',
    this.reasoning = '',
    this.toolCalls = const [],
    this.finishReason = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.error,
  });

  bool get ok => error == null;
}

/// Streams chat completions from an OpenAI-compatible server: llama.cpp's
/// llama-server, LM Studio, Ollama, or a cloud provider.
class OpenAiChatClient {
  /// Ends with /v1 (or the provider's equivalent), without a trailing slash.
  final String baseUrl;
  final String apiKey;
  final String model;
  final Map<String, String> headers;

  /// Longest wait for the first byte, and between two chunks.
  final Duration connectTimeout;
  final Duration idleTimeout;

  final http.Client Function() _newClient;
  http.Client? _active;

  OpenAiChatClient({
    required String baseUrl,
    this.apiKey = '',
    this.model = '',
    this.headers = const {},
    this.connectTimeout = const Duration(seconds: 60),
    this.idleTimeout = const Duration(seconds: 120),
    http.Client Function()? clientFactory,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _newClient = clientFactory ?? http.Client.new;

  /// Stops the request in progress: the connection closes, so the server
  /// stops generating.
  void cancel() {
    final c = _active;
    _active = null;
    c?.close();
  }

  /// Sends [messages] (OpenAI format: role, content, tool_calls…) and
  /// streams the answer: [onText] gets the visible text as it arrives,
  /// [onReasoning] the thinking the server sends apart. [tools] lets the
  /// model ask for calls, returned in [ChatReply.toolCalls].
  Future<ChatReply> complete({
    required List<Map<String, dynamic>> messages,
    List<ChatToolSpec> tools = const [],
    double? temperature,
    int? maxTokens,
    Map<String, dynamic> extra = const {},
    void Function(String text)? onText,
    void Function(String text)? onReasoning,
  }) async {
    final request =
        http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
    request.headers.addAll({
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      ...headers,
    });
    request.body = jsonEncode({
      if (model.isNotEmpty) 'model': model,
      'messages': messages,
      if (tools.isNotEmpty) 'tools': [for (final t in tools) t.toJson()],
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null && maxTokens > 0) 'max_tokens': maxTokens,
      'stream': true,
      'stream_options': {'include_usage': true},
      ...extra,
    });

    final client = _newClient();
    _active = client;
    final text = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <int, _CallBuilder>{};
    var finish = '';
    var promptTokens = 0;
    var completionTokens = 0;
    String? error;
    try {
      final response = await client.send(request).timeout(connectTimeout);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        return ChatReply(error: 'HTTP ${response.statusCode}: ${_errorText(body)}');
      }
      final lines = response.stream
          .timeout(idleTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        // Stopped: what is already received is not shown either.
        if (!identical(_active, client)) break;
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') break;
        Map? data;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) data = decoded;
        } catch (_) {
          continue;
        }
        if (data == null) continue;
        if (data['error'] != null) {
          final e = data['error'];
          error = e is Map ? '${e['message'] ?? e}' : '$e';
          break;
        }
        final usage = data['usage'];
        if (usage is Map) {
          promptTokens = (usage['prompt_tokens'] as num?)?.toInt() ?? promptTokens;
          completionTokens =
              (usage['completion_tokens'] as num?)?.toInt() ?? completionTokens;
        }
        final choices = data['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map) continue;
        final reason = choice['finish_reason'];
        if (reason is String && reason.isNotEmpty) finish = reason;
        final delta = choice['delta'];
        if (delta is! Map) continue;
        final thought = delta['reasoning_content'] ?? delta['reasoning'];
        if (thought is String && thought.isNotEmpty) {
          reasoning.write(thought);
          onReasoning?.call(thought);
        }
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          text.write(content);
          onText?.call(content);
        }
        final toolCalls = delta['tool_calls'];
        if (toolCalls is List) {
          for (final raw in toolCalls) {
            if (raw is! Map) continue;
            final index = (raw['index'] as num?)?.toInt() ?? calls.length;
            final builder = calls.putIfAbsent(index, _CallBuilder.new);
            if (raw['id'] is String) builder.id = raw['id'] as String;
            final fn = raw['function'];
            if (fn is Map) {
              if (fn['name'] is String) builder.name += fn['name'] as String;
              final args = fn['arguments'];
              if (args is String) {
                builder.arguments.write(args);
              } else if (args is Map) {
                builder.arguments.write(jsonEncode(args));
              }
            }
          }
        }
      }
    } on TimeoutException {
      error = 'The server did not answer in time';
    } on http.ClientException catch (e) {
      // Closed by cancel(): what arrived so far is the answer.
      if (identical(_active, client)) error = e.message;
    } catch (e) {
      if (identical(_active, client)) error = '$e';
    } finally {
      if (identical(_active, client)) _active = null;
      client.close();
    }
    final orderedCalls = [
      for (final key in calls.keys.toList()..sort())
        if (calls[key]!.name.isNotEmpty)
          ChatToolCall(
            id: calls[key]!.id.isEmpty ? 'call_$key' : calls[key]!.id,
            name: calls[key]!.name,
            rawArguments: calls[key]!.arguments.toString(),
          ),
    ];
    return ChatReply(
      text: text.toString(),
      reasoning: reasoning.toString(),
      toolCalls: orderedCalls,
      finishReason: finish,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      error: error,
    );
  }

  static String _errorText(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        final e = decoded['error'];
        return e is Map ? '${e['message'] ?? e}' : '$e';
      }
    } catch (_) {}
    return body.length > 300 ? '${body.substring(0, 300)}…' : body;
  }
}

class _CallBuilder {
  String id = '';
  String name = '';
  final arguments = StringBuffer();
}
