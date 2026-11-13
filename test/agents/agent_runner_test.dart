import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privatelm/services/agents/agent_runner.dart';
import 'package:privatelm/services/agents/agent_tools.dart';
import 'package:privatelm/services/document_library.dart';
import 'package:privatelm/services/web_search_service.dart';

/// A model that answers from a script, one reply per call, and remembers
/// what it was sent.
class ScriptedModel {
  final List<String> replies;
  final calls = <List<Map<String, String>>>[];
  final stops = <List<String>>[];
  ScriptedModel(this.replies);

  Future<String> call(List<Map<String, String>> messages,
      {void Function(String token)? onToken, List<String> stop = const []}) async {
    calls.add(List.of(messages));
    stops.add(stop);
    final reply = replies[calls.length - 1];
    for (final word in reply.split(' ')) {
      onToken?.call('$word ');
    }
    return reply;
  }
}

AgentToolbox toolbox({List<WebResult>? web}) => AgentToolbox(
      searchWeb: (q) async =>
          web ??
          const [
            WebResult(
                title: 'CRE',
                url: 'https://www.cre.fr/tarifs',
                snippet: 'Le tarif baisse de 2,6 %.'),
          ],
      fetchPage: (url) async => 'Page $url',
      searchDocs: (q) => const [DocChunk('bail.pdf', 'Loyer : 850 €.')],
      now: () => DateTime(2026, 11, 13, 9, 5),
    );

void main() {
  test('uses tools until it can answer, and keeps the steps', () async {
    final model = ScriptedModel([
      'Je cherche d’abord.\n<tool_call>\n{"name": "web_search", "arguments": {"query": "tarif électricité 2026"}}',
      '<tool_call>{"name": "calculator", "arguments": {"expression": "100 * (1 - 0,026)"}}',
      'Le tarif baisse de 2,6 % [1] : 100 € deviennent 97,4 €.',
    ]);
    final box = toolbox();
    final activities = <String>[];
    final partials = <String>[];
    final run = await AgentRunner(
      llm: model.call,
      tools: box.tools(AgentToolbox.all),
    ).run(
      instructions: 'You are a researcher.',
      question: 'Le prix baisse-t-il ?',
      onActivity: activities.add,
      onPartial: partials.add,
    );

    expect(run.answer, 'Le tarif baisse de 2,6 % [1] : 100 € deviennent 97,4 €.');
    expect(run.steps, hasLength(2));
    expect(run.steps[0].thought, 'Je cherche d’abord.');
    expect(run.steps[0].result, contains('[1] CRE'));
    expect(run.steps[1].result, '100 * (1 - 0,026) = 97.4');
    expect(activities, hasLength(2));
    expect(box.webSources.single.url, 'https://www.cre.fr/tarifs');

    // The model saw the tools, its own calls and their results.
    final system = model.calls.first.first['content']!;
    expect(system, contains('- web_search:'));
    expect(system, contains('- calculator:'));
    final third = model.calls[2];
    expect(third[third.length - 2]['role'], 'assistant');
    expect(third.last['content'], startsWith('<tool_response>\n100 * (1 - 0,026) = 97.4'));
    // It may stop right after a call.
    expect(model.stops.first, contains('</tool_call>'));
    // The tool call never showed up as answer text.
    expect(partials.any((p) => p.contains('tool_call') || p.contains('{')), isFalse);
    expect(partials.last, contains('97,4'));
  });

  test('a failing tool is reported to the model, not fatal', () async {
    final model = ScriptedModel([
      '<tool_call>{"name": "calculator", "arguments": {"expression": "1/0"}}</tool_call>',
      'Division impossible.',
    ]);
    final run = await AgentRunner(
            llm: model.call, tools: toolbox().tools([AgentToolbox.calculator]))
        .run(instructions: 'x', question: '1/0 ?');
    expect(run.steps.single.failed, isTrue);
    expect(model.calls.last.last['content'], contains('Error:'));
    expect(run.answer, 'Division impossible.');
  });

  test('after the last step the model must answer', () async {
    final model = ScriptedModel([
      for (var i = 0; i < 2; i++)
        '<tool_call>{"name": "current_datetime", "arguments": {}}</tool_call>',
      'Nous sommes vendredi.',
    ]);
    final run = await AgentRunner(
      llm: model.call,
      tools: toolbox().tools([AgentToolbox.dateTime]),
      maxSteps: 2,
    ).run(instructions: 'x', question: 'Quel jour ?');
    expect(run.steps, hasLength(2));
    expect(run.steps.first.result, 'Friday 2026-11-13 09:05');
    expect(model.calls.last.last['content'], contains('without any tool call'));
    expect(model.stops.last, isEmpty);
    expect(run.answer, 'Nous sommes vendredi.');
  });

  test('an agent without tools just answers', () async {
    final model = ScriptedModel(['Hello in French is "Bonjour".']);
    final run = await AgentRunner(llm: model.call, tools: const [])
        .run(instructions: 'You translate.', question: 'Hello?');
    expect(run.answer, 'Hello in French is "Bonjour".');
    expect(model.calls.single.first['content'], 'You translate.');
  });

  test('a team works in turn, the last member answers', () async {
    final model = ScriptedModel([
      '1. Chercher le tarif. 2. Conclure.',
      '<tool_call>{"name": "web_search", "arguments": {"query": "tarif"}}</tool_call>',
      'Le tarif baisse de 2,6 % [1].',
      'Oui : le tarif baisse de 2,6 % [1].',
    ]);
    final box = toolbox();
    AgentRunner runner(List<String> tools) =>
        AgentRunner(llm: model.call, tools: box.tools(tools));
    final members = <String>[];
    final run = await TeamRunner([
      TeamMember(name: 'Planificateur', instructions: 'Plan.', runner: runner(const [])),
      TeamMember(
          name: 'Chercheur',
          instructions: 'Research.',
          runner: runner([AgentToolbox.webSearch])),
      TeamMember(name: 'Relecteur', instructions: 'Review.', runner: runner(const [])),
    ]).run(
      request: 'Le prix baisse-t-il ?',
      onMember: (name, i, n) => members.add('$name ${i + 1}/$n'),
    );

    expect(members, ['Planificateur 1/3', 'Chercheur 2/3', 'Relecteur 3/3']);
    expect(run.answer, 'Oui : le tarif baisse de 2,6 % [1].');
    expect(run.steps.map((s) => s.agent),
        ['Planificateur', 'Chercheur', 'Chercheur']);
    // The reviewer read what the others did.
    final reviewerBrief = model.calls.last.last['content']!;
    expect(reviewerBrief, contains('## Planificateur\n1. Chercher le tarif.'));
    expect(reviewerBrief, contains('## Chercheur\nLe tarif baisse de 2,6 % [1].'));
    expect(reviewerBrief, contains('last member of the team'));
  });

  test('what is shown while writing stops where a tool call starts', () {
    expect(AgentRunner.visibleAnswer('Je vérifie.\n<tool_call>{"name"'), 'Je vérifie.');
    expect(AgentRunner.visibleAnswer('<think>hmm</think>Bonjour'), 'Bonjour');
    expect(AgentRunner.visibleAnswer('Je vérifie <tool_c'), 'Je vérifie');
    expect(AgentRunner.visibleAnswer('2 < 3 donc'), '2 < 3 donc');
  });

  test('reads web pages as text, never the local network', () async {
    final client = MockClient((request) async => http.Response(
        '<html><head><title>Tarifs &amp; offres</title><script>var x=1;</script></head>'
        '<body><nav>Menu</nav><h1>Tarif bleu</h1><p>Baisse de 2,6&nbsp;%.</p><footer>©</footer></body></html>',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'}));
    final text =
        await AgentToolbox.readWebPage('https://www.cre.fr/tarifs', client: client);
    expect(text, 'Tarifs & offres\n\nTarif bleu\nBaisse de 2,6 %.');
    expect(() => AgentToolbox.readWebPage('http://192.168.1.1/admin', client: client),
        throwsFormatException);
    expect(() => AgentToolbox.readWebPage('file:///etc/passwd', client: client),
        throwsFormatException);
  });
}
