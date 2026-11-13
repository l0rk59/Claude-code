import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/agents/calculator.dart';
import 'package:privatelm/services/agents/tool_call_parser.dart';

void main() {
  group('calculator', () {
    double calc(String e) => Calculator.evaluate(e);

    test('does arithmetic with the usual priorities', () {
      expect(calc('2 + 3 * 4'), 14);
      expect(calc('(2 + 3) * 4'), 20);
      expect(calc('2^3^2'), 512);
      expect(calc('-3^2'), -9);
      expect(calc('2^-1'), 0.5);
      expect(calc('17 % 5'), 2);
      expect(calc('1250 * 0,2'), 250);
      expect(calc('3 × 4 ÷ 2 − 1'), 5);
      expect(calc('sqrt(16) + abs(-2)'), 6);
      expect(calc('round(2.5) + floor(2.9) + ceil(2.1)'), 8);
      expect(calc('log(1000)'), closeTo(3, 1e-12));
      expect(calc('2 * pi'), closeTo(6.283185, 1e-6));
    });

    test('refuses what is not arithmetic', () {
      for (final bad in ['', '2 +', '(1', '1 / 0', 'foo(2)', 'system("ls")', '2 2']) {
        expect(() => calc(bad), throwsFormatException, reason: bad);
      }
    });

    test('writes results simply', () {
      expect(Calculator.format(14), '14');
      expect(Calculator.format(0.1 + 0.2), '0.3');
      expect(Calculator.format(2 / 3), '0.6666666667');
    });
  });

  group('tool calls', () {
    const known = {'web_search', 'calculator'};

    test('reads the tagged format, even cut before its closing tag', () {
      final call = ToolCallParser.parse(
          'Je cherche.\n<tool_call>\n{"name": "web_search", "arguments": {"query": "météo Lille"}}',
          known)!;
      expect(call.name, 'web_search');
      expect(call.arguments['query'], 'météo Lille');
      expect(call.before, 'Je cherche.');
    });

    test('reads bare and fenced JSON, and string arguments', () {
      expect(
          ToolCallParser.parse(
                  '```json\n{"name": "calculator", "parameters": {"expression": "2+2"}}\n```',
                  known)!
              .arguments['expression'],
          '2+2');
      expect(
          ToolCallParser.parse(
                  '{"name": "calculator", "arguments": "{\\"expression\\": \\"3*3\\"}"}',
                  known)!
              .arguments['expression'],
          '3*3');
      expect(
          ToolCallParser.parse(
                  '{"function": {"name": "calculator", "arguments": {"expression": "1"}}}',
                  known)!
              .name,
          'calculator');
    });

    test("reads Liquid's call format", () {
      final call = ToolCallParser.parse(
          '<|tool_call_start|>[web_search(query="prix, électricité", count=3)]<|tool_call_end|>',
          known)!;
      expect(call.name, 'web_search');
      expect(call.arguments, {'query': 'prix, électricité', 'count': 3});
    });

    test('ignores thinking, unknown tools and ordinary answers', () {
      expect(
          ToolCallParser.parse(
              '<think>maybe {"name": "web_search", "arguments": {}}</think>The answer is 4.',
              known),
          isNull);
      expect(
          ToolCallParser.parse(
              '{"name": "delete_files", "arguments": {}}', known),
          isNull);
      expect(
          ToolCallParser.parse(
              'Voici un exemple JSON : {"name": "Léo", "age": 7}', known),
          isNull);
      expect(ToolCallParser.parse('Bonjour !', known), isNull);
    });
  });
}
