import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/controllers/chat_controller.dart';
import 'package:privatelm/services/agents/agent_profiles.dart';
import 'package:privatelm/services/agents/agent_runner.dart';
import 'package:privatelm/services/agents/agent_tools.dart';
import 'package:privatelm/services/openai_chat_client.dart';
import 'package:privatelm/services/web_search_service.dart';

import 'agent_runner_test.dart' show ScriptedModel;

/// A model behind an OpenAI-compatible server: answers each request with
/// the next scripted turn (text and/or tool calls), and keeps the requests.
class FakeToolServer {
  final List<Map<String, dynamic>> turns;
  final requests = <Map<String, dynamic>>[];
  late HttpServer _server;
  final int errorStatus;
  final String errorMessage;

  FakeToolServer(this.turns, {this.errorStatus = 0, this.errorMessage = ''});

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      requests.add(Map<String, dynamic>.from(body));
      if (errorStatus != 0 && (body['tools'] as List?)?.isNotEmpty == true) {
        req.response.statusCode = errorStatus;
        req.response.write(jsonEncode({
          'error': {'message': errorMessage}
        }));
        await req.response.close();
        return;
      }
      final turn = turns[requests.length - 1];
      req.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      void send(Map<String, dynamic> delta, [String? finish]) =>
          req.response.write('data: ${jsonEncode({
                'choices': [
                  {'index': 0, 'delta': delta, 'finish_reason': finish}
                ]
              })}\n\n');
      if (turn['text'] != null) send({'content': turn['text']});
      final calls = (turn['calls'] as List?) ?? const [];
      for (var i = 0; i < calls.length; i++) {
        send({
          'tool_calls': [
            {
              'index': i,
              'id': 'c$i',
              'type': 'function',
              'function': {
                'name': calls[i]['name'],
                'arguments': jsonEncode(calls[i]['arguments']),
              }
            }
          ]
        });
      }
      send({}, calls.isEmpty ? 'stop' : 'tool_calls');
      req.response.write('data: [DONE]\n\n');
      await req.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

AgentToolbox box({
  Directory? workspace,
  bool allow = true,
  List<AgentConfirmation>? asked,
  String? python,
  Future<String> Function(String, String)? delegate,
  List<String>? remembered,
  Future<List<WebResult>> Function(String)? searchWeb,
}) =>
    AgentToolbox(
      searchWeb: searchWeb ??
          (q) async => [
                WebResult(
                    title: 'Result for $q',
                    url: 'https://ex.com/$q',
                    snippet: 'About $q'),
              ],
      fetchPage: (url) async => 'Page $url',
      searchDocs: (q) => const [],
      workspace: workspace == null ? null : () async => workspace,
      confirm: (request) async {
        asked?.add(request);
        return allow;
      },
      delegate: delegate,
      assistants: delegate == null
          ? const {}
          : const {'Researcher': 'searches the web', 'Analyst': 'numbers'},
      saveMemory: remembered == null ? null : (f) async => remembered.add(f),
      python: python,
      pythonTimeout: const Duration(seconds: 3),
    );

void main() {
  group('native tool calls', () {
    test('several tools at once, results sent back with their ids', () async {
      final server = FakeToolServer([
        {
          'text': 'Je cherche les deux.',
          'calls': [
            {
              'name': 'web_search',
              'arguments': {'query': 'paris'}
            },
            {
              'name': 'calculator',
              'arguments': {'expression': '6*7'}
            },
          ],
        },
        {'text': 'Paris [1], et 6×7 = 42.'},
      ]);
      await server.start();
      addTearDown(server.stop);
      final tools = box();
      final activities = <String>[];
      final run = await AgentRunner(
        backend:
            NativeAgentBackend(() => OpenAiChatClient(baseUrl: server.baseUrl)),
        tools: tools.tools([AgentToolbox.webSearch, AgentToolbox.calculator]),
      ).run(
        instructions: 'You research.',
        question: 'Paris et 6*7 ?',
        onActivity: activities.add,
      );
      expect(run.error, isNull);
      expect(run.answer, 'Paris [1], et 6×7 = 42.');
      expect(run.steps.map((s) => s.label), [
        'Searching the web: “paris”',
        'Calculating 6*7',
      ]);
      expect(run.steps[1].result, '6*7 = 42');
      expect(tools.webSources.single.url, 'https://ex.com/paris');

      // The tools were offered as JSON schemas.
      final offered = server.requests.first['tools'] as List;
      expect(offered.map((t) => t['function']['name']),
          ['web_search', 'calculator']);
      expect(offered.first['function']['parameters']['required'], ['query']);
      // The second request carries the calls and both results.
      final messages = server.requests[1]['messages'] as List;
      final assistant = messages.firstWhere((m) => m['role'] == 'assistant');
      expect(
          (assistant['tool_calls'] as List).map((c) => c['id']), ['c0', 'c1']);
      final results = messages.where((m) => m['role'] == 'tool').toList();
      expect(results.map((m) => m['tool_call_id']), ['c0', 'c1']);
      expect(results[1]['content'], '6*7 = 42');
      // The system prompt doesn't spell the text protocol out.
      expect(messages.first['content'], isNot(contains('<tool_call>')));
    });

    test('a server that refuses tools: the run carries on through text',
        () async {
      final server = FakeToolServer([],
          errorStatus: 400, errorMessage: 'This model does not support tools');
      await server.start();
      addTearDown(server.stop);
      final text = ScriptedModel([
        '<tool_call>{"name": "calculator", "arguments": {"expression": "2+3"}}</tool_call>',
        'Cela fait 5.',
      ]);
      final backend = NativeAgentBackend(
        () => OpenAiChatClient(baseUrl: server.baseUrl),
        fallback: TextAgentBackend(text.call),
      );
      final run = await AgentRunner(
        backend: backend,
        tools: box().tools([AgentToolbox.calculator]),
      ).run(instructions: 'x', question: '2+3 ?');
      expect(run.answer, 'Cela fait 5.');
      expect(run.steps.single.result, '2+3 = 5');
      expect(backend.native, isFalse);
      // The text model got the call protocol and the result as text.
      expect(text.calls[1].last['content'], contains('<tool_response>'));
    });

    test('a model that writes its call as text is understood too', () async {
      final server = FakeToolServer([
        {
          'text':
              '<tool_call>{"name": "calculator", "arguments": {"expression": "1+1"}}</tool_call>'
        },
        {'text': '2.'},
      ]);
      await server.start();
      addTearDown(server.stop);
      final run = await AgentRunner(
        backend:
            NativeAgentBackend(() => OpenAiChatClient(baseUrl: server.baseUrl)),
        tools: box().tools([AgentToolbox.calculator]),
      ).run(instructions: 'x', question: '1+1');
      expect(run.answer, '2.');
      expect(run.steps.single.label, 'Calculating 1+1');
    });
  });

  group('deep mode', () {
    test('plans, works, is sent back for what is missing, then answers',
        () async {
      final model = ScriptedModel([
        '1. Chercher le prix.\n2. Calculer.',
        '<tool_call>{"name": "web_search", "arguments": {"query": "prix"}}</tool_call>',
        'Le prix est 10 €.',
        'MISSING: the price with tax',
        '<tool_call>{"name": "web_search", "arguments": {"query": "prix TTC"}}</tool_call>',
        'Le prix est 10 € HT, 12 € TTC [2].',
      ]);
      final activities = <String>[];
      final run = await AgentRunner(
        llm: model.call,
        tools: box().tools([AgentToolbox.webSearch]),
        deep: true,
      ).run(
          instructions: 'You research.',
          question: 'Quel prix ?',
          onActivity: activities.add);
      expect(run.answer, 'Le prix est 10 € HT, 12 € TTC [2].');
      expect(run.steps.map((s) => (s.kind, s.label)), [
        (AgentStepKind.plan, 'PLAN'),
        (AgentStepKind.tool, 'Searching the web: “prix”'),
        (AgentStepKind.verify, 'MISSING'),
        (AgentStepKind.tool, 'Searching the web: “prix TTC”'),
      ]);
      expect(run.steps.first.result, contains('Chercher le prix'));
      expect(activities, containsAllInOrder(['PLAN', 'VERIFY']));
      // The plan guides the work; the reviewer saw the evidence.
      expect(model.calls[1].first['content'], contains('Your plan'));
      expect(model.calls[3].last['content'], contains('Evidence found'));
      expect(model.calls[3].last['content'], contains('Result for prix'));
      // The second answer is not checked again.
      expect(model.calls, hasLength(6));
    });

    test('a corrected answer replaces the draft; an approved one stays',
        () async {
      final corrected = await AgentRunner(
        llm: ScriptedModel(['1. Calculer.', 'Ça fait 41.', 'Ça fait 42.']).call,
        tools: box().tools([AgentToolbox.calculator]),
        deep: true,
      ).run(instructions: 'x', question: '6*7');
      expect(corrected.answer, 'Ça fait 42.');
      expect(corrected.steps.last.label, 'CORRECTED');

      final approved = await AgentRunner(
        llm: ScriptedModel(['1. Calculer.', 'Ça fait 42.', 'APPROVED']).call,
        tools: box().tools([AgentToolbox.calculator]),
        deep: true,
      ).run(instructions: 'x', question: '6*7');
      expect(approved.answer, 'Ça fait 42.');
      expect(approved.steps.last.kind, AgentStepKind.verify);
      expect(approved.steps.last.label, 'APPROVED');
    });
  });

  test('the same call twice is not run again', () async {
    var searches = 0;
    const call =
        '<tool_call>{"name": "web_search", "arguments": {"query": "x"}}</tool_call>';
    final model = ScriptedModel([call, call, 'Fini.']);
    final run = await AgentRunner(
      llm: model.call,
      tools: box(searchWeb: (q) async {
        searches++;
        return const [WebResult(title: 't', url: 'https://a.b', snippet: 's')];
      }).tools([AgentToolbox.webSearch]),
    ).run(instructions: 'x', question: 'x');
    expect(run.answer, 'Fini.');
    expect(searches, 1);
    expect(model.calls[2].last['content'],
        contains('You already did exactly this'));
  });

  test('old tool results are shortened past the context budget', () async {
    String call(String q) =>
        '<tool_call>{"name": "read_page", "arguments": {"url": "https://a.b/$q"}}</tool_call>';
    final model = ScriptedModel([call('1'), call('2'), call('3'), 'Fini.']);
    final tools = AgentToolbox(
      searchWeb: (q) async => const [],
      fetchPage: (url) async => '$url ${'x' * 3000}',
      searchDocs: (q) => const [],
      maxResultChars: 5000,
    );
    await AgentRunner(
      llm: model.call,
      tools: tools.tools([AgentToolbox.readPage]),
      contextBudget: 5000,
    ).run(instructions: 'x', question: 'x');
    final results = model.calls.last
        .where((m) => m['content']!.startsWith('<tool_response>'))
        .map((m) => m['content']!)
        .toList();
    expect(results, hasLength(3));
    expect(results.first, contains('[shortened]'));
    expect(results.last, isNot(contains('[shortened]')));
  });

  test('a model error ends the run with the error, not an answer', () async {
    final run = await AgentRunner(
      llm: ScriptedModel(['ERROR: No model loaded.']).call,
      tools: box().tools([AgentToolbox.calculator]),
    ).run(instructions: 'x', question: 'x');
    expect(run.answer, '');
    expect(run.error, 'ERROR: No model loaded.');
  });

  group('work folder', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('agent_ws'));
    tearDown(() => dir.delete(recursive: true));

    test('paths stay inside the folder', () {
      expect(AgentToolbox.safeRelative('notes/plan.md'), 'notes/plan.md');
      expect(AgentToolbox.safeRelative('./a//b.txt'), 'a/b.txt');
      expect(AgentToolbox.safeRelative(''), '');
      expect(AgentToolbox.safeRelative('../secret'), isNull);
      expect(AgentToolbox.safeRelative('a/../../b'), isNull);
      expect(AgentToolbox.safeRelative('/etc/passwd'), isNull);
      expect(AgentToolbox.safeRelative('C:\\Windows\\x'), isNull);
      expect(AgentToolbox.safeRelative('~/x'), isNull);
    });

    test('writes only once allowed, then lists and reads', () async {
      final asked = <AgentConfirmation>[];
      final refused = box(workspace: dir, allow: false, asked: asked);
      final write = refused.tools([AgentToolbox.writeFile]).single;
      expect(await write.run({'path': 'notes/plan.md', 'content': '# Plan'}),
          contains('declined'));
      expect(File('${dir.path}/notes/plan.md').existsSync(), isFalse);
      expect(asked.single.tool, AgentToolbox.writeFile);
      expect(asked.single.detail, '# Plan');

      final allowed = box(workspace: dir, allow: true);
      final tools = {
        for (final t in allowed.tools([
          AgentToolbox.writeFile,
          AgentToolbox.listFiles,
          AgentToolbox.readFile,
        ]))
          t.name: t,
      };
      expect(
          await tools['write_file']!
              .run({'path': 'notes/plan.md', 'content': '# Plan'}),
          'Wrote 6 characters to notes/plan.md.');
      expect(allowed.filesWritten, ['notes/plan.md']);
      expect(await tools['list_files']!.run({}), 'notes/');
      expect(await tools['list_files']!.run({'path': 'notes'}),
          'notes/plan.md (6 B)');
      expect(
          await tools['read_file']!.run({'path': 'notes/plan.md'}), '# Plan');
      await expectLater(
          tools['read_file']!.run({'path': '../x'}), throwsFormatException);
    });

    test('a link pointing out of the folder is refused', () async {
      final outside = await Directory.systemTemp.createTemp('outside');
      addTearDown(() => outside.delete(recursive: true));
      File('${outside.path}/secret.txt').writeAsStringSync('secret');
      Link('${dir.path}/escape').createSync('${outside.path}/secret.txt');
      final read = box(workspace: dir).tools([AgentToolbox.readFile]).single;
      await expectLater(read.run({'path': 'escape'}), throwsFormatException);
    }, skip: Platform.isWindows);

    test('a linked folder pointing out is refused too, even for a new file',
        () async {
      final outside = await Directory.systemTemp.createTemp('outside');
      addTearDown(() => outside.delete(recursive: true));
      File('${outside.path}/secret.txt').writeAsStringSync('secret');
      Link('${dir.path}/linked').createSync(outside.path);
      final tools = {
        for (final t in box(workspace: dir, allow: true)
            .tools([AgentToolbox.readFile, AgentToolbox.writeFile]))
          t.name: t,
      };
      await expectLater(tools['read_file']!.run({'path': 'linked/secret.txt'}),
          throwsFormatException);
      await expectLater(
          tools['write_file']!
              .run({'path': 'linked/new/planted.txt', 'content': 'x'}),
          throwsFormatException);
      expect(Directory('${outside.path}/new').existsSync(), isFalse);
    }, skip: Platform.isWindows);

    test('inside means inside, not a neighbour with a longer name', () {
      expect(AgentToolbox.isInside('/w/work', '/w/work'), isTrue);
      expect(AgentToolbox.isInside('/w/work/a.txt', '/w/work/'), isTrue);
      expect(AgentToolbox.isInside('/w/work2/a.txt', '/w/work'), isFalse);
      expect(
          AgentToolbox.isInside(r'C:\Users\Me\Work\a.txt', r'c:\users\me\work',
              windows: true, separator: r'\'),
          isTrue);
      expect(
          AgentToolbox.isInside(r'C:\Users\Me\Work2', r'C:\Users\Me\Work',
              windows: true, separator: r'\'),
          isFalse);
      expect(AgentToolbox.safeRelative('notes.txt:hidden'), isNull);
    });

    test('runs Python once allowed, in the folder, and stops it when too long',
        () async {
      final python = await AgentToolbox.findPython();
      if (python == null) return;
      final asked = <AgentConfirmation>[];
      File('${dir.path}/data.csv').writeAsStringSync('a,b\n1,2\n3,4\n');
      final tool = box(workspace: dir, python: python, asked: asked)
          .tools([AgentToolbox.runPython]).single;
      final out = await tool.run({
        'code': 'import csv\nrows = list(csv.DictReader(open("data.csv")))\n'
            'print(sum(int(r["b"]) for r in rows))',
      });
      expect(out, 'Finished.\n6');
      expect(asked.single.detail, contains('import csv'));

      final error = await tool.run({'code': 'raise ValueError("boom")'});
      expect(error, startsWith('Exit code 1.'));
      expect(error, contains('ValueError: boom'));

      final slow = await tool.run({'code': 'import time\ntime.sleep(30)'});
      expect(slow, startsWith('Stopped'));

      final refused = box(workspace: dir, python: python, allow: false)
          .tools([AgentToolbox.runPython]).single;
      expect(await refused.run({'code': 'print(1)'}), contains('declined'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('tools missing what they need are not offered', () {
      final none = box();
      expect(none.tools(AgentToolbox.all).map((t) => t.name), [
        AgentToolbox.webSearch,
        AgentToolbox.readPage,
        AgentToolbox.searchDocuments,
        AgentToolbox.calculator,
        AgentToolbox.dateTime,
      ]);
      // Python needs a program and a folder.
      expect(box(workspace: dir).isAvailable(AgentToolbox.runPython), isFalse);
      expect(
          box(workspace: dir, python: 'python3')
              .isAvailable(AgentToolbox.runPython),
          isTrue);
    });
  });

  test('remembers a fact only once allowed', () async {
    final remembered = <String>[];
    final asked = <AgentConfirmation>[];
    final tool = box(remembered: remembered, asked: asked)
        .tools([AgentToolbox.remember]).single;
    expect(await tool.run({'fact': 'Végétarien'}), 'Saved to memory.');
    expect(remembered, ['Végétarien']);
    expect(asked.single.detail, 'Végétarien');
    final refused = box(remembered: remembered, allow: false)
        .tools([AgentToolbox.remember]).single;
    expect(await refused.run({'fact': 'Autre'}), contains('declined'));
    expect(remembered, ['Végétarien']);
  });

  test('recognises an assistant written loosely', () {
    const names = [
      'Chercheur',
      'Analyste',
      'Chef de projet',
      'Chercheur approfondi'
    ];
    expect(AgentToolbox.matchAssistant('analyste', names), 'Analyste');
    expect(AgentToolbox.matchAssistant('Analyst', names), 'Analyste');
    expect(
        AgentToolbox.matchAssistant('chef de projet', names), 'Chef de projet');
    expect(
        AgentToolbox.matchAssistant('ChefDeProjet', names), 'Chef de projet');
    expect(AgentToolbox.matchAssistant('Chercheur', names), 'Chercheur');
    // Two assistants start the same way: not guessed.
    expect(AgentToolbox.matchAssistant('Cherch', names), isNull);
    expect(AgentToolbox.matchAssistant('', names), isNull);
    expect(AgentToolbox.matchAssistant('Pilote', names), isNull);
  });

  test('hands a task to another assistant by its name', () async {
    final asked = <(String, String)>[];
    final tool = box(delegate: (name, task) async {
      asked.add((name, task));
      return 'Done by $name';
    }).tools([AgentToolbox.askAssistant]).single;
    expect(tool.description, contains('Researcher (searches the web)'));
    expect(await tool.run({'assistant': 'researcher', 'task': 'Trouve X'}),
        'Done by Researcher');
    expect(asked.single, ('Researcher', 'Trouve X'));
    expect(await tool.run({'assistant': 'Nobody', 'task': 'x'}),
        contains('Unknown assistant'));
  });

  test('a manager delegates two tasks at once through native calls', () async {
    final server = FakeToolServer([
      {
        'calls': [
          {
            'name': 'ask_assistant',
            'arguments': {'assistant': 'Researcher', 'task': 'A'}
          },
          {
            'name': 'ask_assistant',
            'arguments': {'assistant': 'Analyst', 'task': 'B'}
          },
        ],
      },
      {'text': 'Synthèse : A et B.'},
    ]);
    await server.start();
    addTearDown(server.stop);
    final running = <String>[];
    var concurrent = 0;
    final tools = box(delegate: (name, task) async {
      running.add(name);
      concurrent = running.length > concurrent ? running.length : concurrent;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      running.remove(name);
      return '$name: $task fait';
    });
    final run = await AgentRunner(
      backend:
          NativeAgentBackend(() => OpenAiChatClient(baseUrl: server.baseUrl)),
      tools: tools.tools([AgentToolbox.askAssistant]),
    ).run(instructions: 'You lead.', question: 'A et B');
    expect(run.answer, 'Synthèse : A et B.');
    expect(concurrent, 2, reason: 'the two assistants work at the same time');
    expect(run.steps.map((s) => s.result),
        ['Researcher: A fait', 'Analyst: B fait']);
  });

  group('profiles', () {
    test('the new built-in assistants', () {
      final byId = {for (final a in AgentStore.builtInAgents()) a.id: a};
      expect(byId['builtin:manager']!.delegates, isTrue);
      expect(byId['builtin:manager']!.deep, isTrue);
      expect(byId['builtin:deep_researcher']!.deep, isTrue);
      expect(
          byId['builtin:programmer']!.tools, contains(AgentToolbox.runPython));
      expect(byId['builtin:files']!.tools, contains(AgentToolbox.writeFile));
      expect(byId['builtin:researcher']!.deep, isFalse);
    });

    test('deep mode is saved with the assistant', () {
      const a = AgentProfile(
          id: 'agent:1',
          name: 'N',
          description: 'D',
          instructions: 'I',
          tools: [AgentToolbox.runPython, 'unknown'],
          deep: true);
      final back = AgentProfile.fromMap(a.toMap());
      expect(back.deep, isTrue);
      expect(back.tools, [AgentToolbox.runPython]);
      expect(a.copyWith(deep: false).deep, isFalse);
    });
  });

  test('the steps read well: plan, tools of each assistant, check', () {
    final text = ChatController.agentStepsMarkdown(const [
      AgentStep(label: 'PLAN', result: '1. A\n2. B', kind: AgentStepKind.plan),
      AgentStep(agent: 'Researcher', label: 'Searching the web: “x”'),
      AgentStep(label: 'Asking Researcher'),
      AgentStep(
          label: 'MISSING', result: 'the date', kind: AgentStepKind.verify),
      AgentStep(label: 'APPROVED', kind: AgentStepKind.verify),
    ]);
    expect(text, contains('**Plan**\n> 1. A\n> 2. B'));
    expect(text, contains('1. **Researcher** · Searching the web: “x”'));
    expect(text, contains('2. Asking Researcher'));
    expect(text,
        contains('↻ Check: something is missing, more research\n> the date'));
    expect(text, contains('✓ Answer checked'));
  });
}
