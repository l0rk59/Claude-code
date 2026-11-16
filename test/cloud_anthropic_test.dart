import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/cloud_service.dart';

void main() {
  test('the Claude request: system apart, no temperature, no empty turns', () {
    final body = CloudService.anthropicBody(
      model: 'claude-opus-5-5',
      messages: const [
        {'role': 'system', 'content': 'Be brief.'},
        {'role': 'user', 'content': 'Bonjour'},
        {'role': 'assistant', 'content': ''},
        {'role': 'user', 'content': 'Encore ?'},
      ],
      stream: true,
    );
    expect(body['system'], 'Be brief.');
    expect(body.containsKey('temperature'), isFalse);
    expect(body['messages'], [
      {'role': 'user', 'content': 'Bonjour'},
      {'role': 'user', 'content': 'Encore ?'},
    ]);
    expect(body['stream'], isTrue);
    expect(body['max_tokens'], 16000);
    // A model that declines hands over to another one.
    expect(body['fallbacks'], 'default');
  });

  test('fallbacks only where the API offers them', () {
    expect(CloudService.claudeHasFallbacks('claude-opus-5-5'), isTrue);
    expect(CloudService.claudeHasFallbacks('claude-sonnet-5-5'), isTrue);
    expect(CloudService.claudeHasFallbacks('claude-fable-5-2'), isTrue);
    expect(CloudService.claudeHasFallbacks('claude-haiku-5-5'), isFalse);
    expect(CloudService.claudeHasFallbacks('claude-sonnet-4-6'), isFalse);
    final body = CloudService.anthropicBody(
        model: 'claude-haiku-5-5', messages: const [{'role': 'user', 'content': 'x'}]);
    expect(body.containsKey('fallbacks'), isFalse);
    expect(body.containsKey('stream'), isFalse);
  });

  test('an image goes before the question', () {
    final body = CloudService.anthropicBody(
      model: 'claude-opus-5-5',
      messages: const [{'role': 'user', 'content': 'Que vois-tu ?'}],
      imageBase64: 'AAAA',
    );
    final content = (body['messages'] as List).single['content'] as List;
    expect(content[0]['type'], 'image');
    expect(content[0]['source']['data'], 'AAAA');
    expect(content[1], {'type': 'text', 'text': 'Que vois-tu ?'});
  });

  test('reads the text blocks only, and says when Claude declines', () {
    expect(
        CloudService.anthropicText({
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': 'Paris'},
            {'type': 'text', 'text': ' est la capitale.'},
          ],
          'stop_reason': 'end_turn',
        }),
        'Paris est la capitale.');
    expect(
        CloudService.anthropicText({
          'content': const [],
          'stop_reason': 'refusal',
        }),
        startsWith('ERROR'));
  });
}
