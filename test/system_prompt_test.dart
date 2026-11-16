import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/core/constants.dart';

void main() {
  test("the app's own prompts count as the default, the user's do not", () {
    expect(AppConstants.isDefaultSystemPrompt(''), isTrue);
    expect(AppConstants.isDefaultSystemPrompt(AppConstants.systemPrompt), isTrue);
    // Saved by an earlier version as it was.
    expect(
        AppConstants.isDefaultSystemPrompt(
            'You are AI Chat, a helpful and friendly assistant. Be concise, accurate, and conversational. Answer questions directly without unnecessary preamble.'),
        isTrue);
    expect(AppConstants.isDefaultSystemPrompt('Tu es mon coach sportif.'), isFalse);
  });

  test('the default asks for the language of the question', () {
    expect(AppConstants.systemPrompt, contains("language of the user's message"));
    expect(AppConstants.uncensoredSystemPrompt,
        contains("language of the user's message"));
    expect(AppConstants.systemPrompt, contains('PrivateLM'));
  });
}
