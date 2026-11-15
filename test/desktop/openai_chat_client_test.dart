import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/openai_chat_client.dart';

/// Serves one streamed answer made of [events] (each sent as an SSE line).
Future<(HttpServer, List<Map<String, dynamic>>)> _serve(
  List<Object> events, {
  int status = 200,
  Duration gap = Duration.zero,
}) async {
  final requests = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    requests.add({
      'auth': req.headers.value('authorization'),
      'body': jsonDecode(body),
    });
    req.response.statusCode = status;
    if (status != 200) {
      req.response.write(jsonEncode({
        'error': {'message': 'Invalid API Key'}
      }));
      await req.response.close();
      return;
    }
    req.response.headers.contentType =
        ContentType('text', 'event-stream', charset: 'utf-8');
    for (final e in events) {
      req.response.write('data: ${e is String ? e : jsonEncode(e)}\n\n');
      await req.response.flush();
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    await req.response.close();
  });
  return (server, requests);
}

Map<String, dynamic> _delta(Map<String, dynamic> delta, {String? finish}) => {
      'choices': [
        {'index': 0, 'delta': delta, 'finish_reason': finish}
      ]
    };

void main() {
  test('streams text and thinking apart, and reads the usage', () async {
    final (server, requests) = await _serve([
      _delta({'reasoning_content': 'Let me think. '}),
      _delta({'content': 'Hello '}),
      _delta({'content': 'there.'}, finish: 'stop'),
      {'choices': [], 'usage': {'prompt_tokens': 12, 'completion_tokens': 3}},
      '[DONE]',
    ]);
    addTearDown(() => server.close(force: true));
    final client = OpenAiChatClient(
        baseUrl: 'http://127.0.0.1:${server.port}/v1/', apiKey: 'k', model: 'm');
    final texts = <String>[];
    final thoughts = <String>[];
    final reply = await client.complete(
      messages: [
        {'role': 'user', 'content': 'hi'}
      ],
      temperature: 0.2,
      maxTokens: 50,
      onText: texts.add,
      onReasoning: thoughts.add,
    );
    expect(reply.ok, isTrue);
    expect(reply.text, 'Hello there.');
    expect(texts, ['Hello ', 'there.']);
    expect(thoughts.join(), 'Let me think. ');
    expect(reply.finishReason, 'stop');
    expect(reply.promptTokens, 12);
    expect(reply.completionTokens, 3);
    expect(requests.single['auth'], 'Bearer k');
    final body = requests.single['body'] as Map;
    expect(body['model'], 'm');
    expect(body['stream'], isTrue);
    expect(body['max_tokens'], 50);
    expect(body.containsKey('tools'), isFalse);
  });

  test('assembles tool calls split across chunks, several at once', () async {
    final (server, requests) = await _serve([
      _delta({
        'tool_calls': [
          {
            'index': 0,
            'id': 'call_a',
            'type': 'function',
            'function': {'name': 'web_search', 'arguments': '{"que'}
          }
        ]
      }),
      _delta({
        'tool_calls': [
          {
            'index': 0,
            'function': {'arguments': 'ry": "prix gazole"}'}
          },
          {
            'index': 1,
            'id': 'call_b',
            'function': {'name': 'calculator', 'arguments': '{"expression":"2+2"}'}
          }
        ]
      }, finish: 'tool_calls'),
      '[DONE]',
    ]);
    addTearDown(() => server.close(force: true));
    final client =
        OpenAiChatClient(baseUrl: 'http://127.0.0.1:${server.port}/v1');
    final reply = await client.complete(
      messages: [
        {'role': 'user', 'content': 'q'}
      ],
      tools: const [
        ChatToolSpec(
            name: 'web_search',
            description: 'Search',
            parameters: {'type': 'object', 'properties': {}}),
      ],
    );
    expect(reply.toolCalls, hasLength(2));
    expect(reply.toolCalls[0].id, 'call_a');
    expect(reply.toolCalls[0].name, 'web_search');
    expect(reply.toolCalls[0].arguments, {'query': 'prix gazole'});
    expect(reply.toolCalls[1].arguments, {'expression': '2+2'});
    expect(reply.finishReason, 'tool_calls');
    expect(requests.single['auth'], isNull);
    final tools = (requests.single['body'] as Map)['tools'] as List;
    expect(tools.single['function']['name'], 'web_search');
  });

  test('reports an HTTP error with the server message', () async {
    final (server, _) = await _serve(const [], status: 401);
    addTearDown(() => server.close(force: true));
    final client =
        OpenAiChatClient(baseUrl: 'http://127.0.0.1:${server.port}/v1');
    final reply = await client.complete(messages: const []);
    expect(reply.ok, isFalse);
    expect(reply.error, contains('401'));
    expect(reply.error, contains('Invalid API Key'));
  });

  test('an error event after some text is reported, the text kept', () async {
    final (server, _) = await _serve([
      _delta({'content': 'Partial'}),
      {
        'error': {'message': 'context full'}
      },
    ]);
    addTearDown(() => server.close(force: true));
    final reply = await OpenAiChatClient(
            baseUrl: 'http://127.0.0.1:${server.port}/v1')
        .complete(messages: const []);
    expect(reply.text, 'Partial');
    expect(reply.error, 'context full');
  });

  test('cancel stops the stream and keeps what arrived, without error',
      () async {
    final (server, _) = await _serve([
      for (var i = 0; i < 50; i++) _delta({'content': 'w$i '}),
      '[DONE]',
    ], gap: const Duration(milliseconds: 20));
    addTearDown(() => server.close(force: true));
    final client =
        OpenAiChatClient(baseUrl: 'http://127.0.0.1:${server.port}/v1');
    var seen = 0;
    final reply = await client.complete(
      messages: const [],
      onText: (_) {
        if (++seen == 3) client.cancel();
      },
    );
    expect(reply.ok, isTrue);
    expect(reply.text.split(' ').where((w) => w.isNotEmpty).length,
        lessThan(10));
  });

  test('tool call arguments that are not JSON give an empty map', () {
    const call = ChatToolCall(id: 'x', name: 'f', rawArguments: '{oops');
    expect(call.arguments, isEmpty);
    expect(call.toJson()['function'], {'name': 'f', 'arguments': '{oops'});
  });
}
