import 'dart:convert';

import '../openai_chat_client.dart';
import 'agent_tools.dart';
import 'tool_call_parser.dart';

/// A model to talk to through text: takes the messages (system first),
/// returns the reply. Streams tokens to [onToken] and may stop at [stop].
typedef AgentLlm = Future<String> Function(
  List<Map<String, String>> messages, {
  void Function(String token)? onToken,
  List<String> stop,
});

/// What the model said in one turn: text, and the tools it asked for.
class AgentReply {
  final String text;
  final List<ToolCall> calls;

  /// Why the model couldn't be asked; null when it answered.
  final String? error;
  const AgentReply(this.text, {this.calls = const [], this.error});
}

/// How a run talks to the model. Messages are in OpenAI's format: role,
/// content, and for tools `tool_calls` and `tool_call_id`.
abstract class AgentBackend {
  /// Whether the model calls tools itself (several at once), rather than
  /// through text this app reads.
  bool get native;

  /// The system prompt for an agent with [tools].
  String systemPrompt(String instructions, List<AgentTool> tools, int maxSteps);

  /// The model's next turn. [allowTools] false: it must answer.
  /// [onPartial] hears the answer as it is written. [brief]: a short
  /// side task (a plan, a check) the model needn't think long about.
  Future<AgentReply> next(
    List<Map<String, dynamic>> messages,
    List<AgentTool> tools, {
    required bool allowTools,
    void Function(String visible)? onPartial,
    bool brief = false,
  });
}

/// Any model, through text: tools are described in the system prompt and
/// calls read from the reply (see [ToolCallParser]). One call per turn.
class TextAgentBackend implements AgentBackend {
  final AgentLlm llm;
  const TextAgentBackend(this.llm);

  @override
  bool get native => false;

  @override
  String systemPrompt(String instructions, List<AgentTool> tools, int maxSteps) {
    if (tools.isEmpty) return instructions;
    final example = tools.first;
    final exampleArgs = {
      for (final p in example.parameters.keys) p: '...',
    };
    return '''$instructions

You can use tools. Available tools:
${tools.map((t) => t.signature).join('\n')}

To use a tool, reply with only this, nothing after it:
${ToolCallParser.openTag}
${jsonEncode({'name': example.name, 'arguments': exampleArgs})}
${ToolCallParser.closeTag}
The result comes back in <tool_response>. Use one tool at a time, at most $maxSteps in all. When you have what you need, answer the user directly, in the language of their question, without any tool call. Cite web sources by their number, like [1].''';
  }

  /// The run's messages as plain text turns: calls written as the model
  /// should write them, results as <tool_response> turns.
  static List<Map<String, String>> asText(List<Map<String, dynamic>> messages) {
    final out = <Map<String, String>>[];
    for (final m in messages) {
      final role = '${m['role']}';
      if (role == 'tool') {
        out.add({
          'role': 'user',
          'content': '<tool_response>\n${m['content']}\n</tool_response>',
        });
      } else if (role == 'assistant' && m['tool_calls'] is List) {
        final calls = m['tool_calls'] as List;
        out.add({
          'role': 'assistant',
          'content': [
            if ('${m['content'] ?? ''}'.isNotEmpty) '${m['content']}',
            for (final c in calls) ...[
              ToolCallParser.openTag,
              jsonEncode({
                'name': c['function']['name'],
                'arguments': _decode('${c['function']['arguments']}'),
              }),
              ToolCallParser.closeTag,
            ],
          ].join('\n'),
        });
      } else {
        out.add({'role': role, 'content': '${m['content'] ?? ''}'});
      }
    }
    return out;
  }

  static Object _decode(String json) {
    try {
      return jsonDecode(json) as Object;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<AgentReply> next(
    List<Map<String, dynamic>> messages,
    List<AgentTool> tools, {
    required bool allowTools,
    void Function(String visible)? onPartial,
    bool brief = false,
  }) async {
    final useTools = allowTools && tools.isNotEmpty;
    final buffer = StringBuffer();
    final reply = await llm(
      asText(messages),
      stop: useTools ? ToolCallParser.stopSequences : const [],
      onToken: (token) {
        buffer.write(token);
        onPartial?.call(AgentRunner.visibleAnswer(buffer.toString()));
      },
    );
    if (reply.startsWith('ERROR') || reply.startsWith('ERREUR')) {
      return AgentReply('', error: reply);
    }
    final call = useTools
        ? ToolCallParser.parse(reply, {for (final t in tools) t.name})
        : null;
    if (call == null) return AgentReply(ToolCallParser.withoutThinking(reply));
    return AgentReply(call.before, calls: [call]);
  }
}

/// A model that calls tools itself, through an OpenAI-compatible server
/// (llama.cpp's llama-server, cloud providers): sturdier, and several
/// calls can run at once. Falls back to text when the server refuses
/// tools.
class NativeAgentBackend implements AgentBackend {
  final OpenAiChatClient Function() client;
  final double? temperature;
  final int? maxTokens;

  /// Used when the server refuses the tools (some models can't).
  final TextAgentBackend? fallback;
  bool _useFallback = false;

  /// The server is llama.cpp's: brief tasks can switch the model's
  /// thinking off (models that think spend their whole budget on it).
  final bool llamaCpp;

  NativeAgentBackend(this.client,
      {this.temperature, this.maxTokens, this.fallback, this.llamaCpp = false});

  @override
  bool get native => !_useFallback;

  @override
  String systemPrompt(String instructions, List<AgentTool> tools, int maxSteps) {
    if (_useFallback && fallback != null) {
      return fallback!.systemPrompt(instructions, tools, maxSteps);
    }
    if (tools.isEmpty) return instructions;
    return '''$instructions

You have tools: use them whenever they make the answer more accurate, several at once when they don't depend on each other, at most $maxSteps rounds in all. When you have what you need, answer the user directly, in the language of their question. Cite web sources by their number, like [1].''';
  }

  @override
  Future<AgentReply> next(
    List<Map<String, dynamic>> messages,
    List<AgentTool> tools, {
    required bool allowTools,
    void Function(String visible)? onPartial,
    bool brief = false,
  }) async {
    if (_useFallback && fallback != null) {
      return fallback!.next(messages, tools,
          allowTools: allowTools, onPartial: onPartial, brief: brief);
    }
    final useTools = allowTools && tools.isNotEmpty;
    final text = StringBuffer();
    final reply = await client().complete(
      messages: messages,
      tools: useTools
          ? [
              for (final t in tools)
                ChatToolSpec(
                    name: t.name, description: t.description, parameters: t.schema),
            ]
          : const [],
      temperature: temperature,
      maxTokens: maxTokens,
      extra: brief && llamaCpp
          ? const {
              'chat_template_kwargs': {'enable_thinking': false},
            }
          : const {},
      onText: (t) {
        text.write(t);
        onPartial?.call(ToolCallParser.withoutThinking(text.toString()).trimRight());
      },
    );
    if (!reply.ok && reply.text.isEmpty && reply.toolCalls.isEmpty) {
      // A server or model without tools: carry on through text.
      if (useTools &&
          fallback != null &&
          RegExp(r'tool|function', caseSensitive: false).hasMatch(reply.error!)) {
        _useFallback = true;
        return fallback!.next(messages, tools,
            allowTools: allowTools, onPartial: onPartial, brief: brief);
      }
      return AgentReply('', error: reply.error);
    }
    final known = {for (final t in tools) t.name};
    final calls = [
      for (final c in reply.toolCalls)
        if (known.contains(c.name)) ToolCall(c.name, c.arguments, id: c.id),
    ];
    final content = ToolCallParser.withoutThinking(reply.text);
    // Some models write the call as text even when they can call tools.
    if (calls.isEmpty && useTools) {
      final textCall = ToolCallParser.parse(reply.text, known);
      if (textCall != null) return AgentReply(textCall.before, calls: [textCall]);
    }
    return AgentReply(calls.isEmpty ? content : content.trim(), calls: calls);
  }
}

enum AgentStepKind { plan, tool, member, verify }

/// One thing the agent did.
class AgentStep {
  /// Who did it, in a team or when delegated ('' for the agent itself).
  final String agent;

  /// What it did, for the user ("Searching the web: …", or a team
  /// member's contribution).
  final String label;

  /// What the model wrote before acting, if anything.
  final String thought;

  /// What came back (a tool's result, or a team member's output, or the
  /// plan).
  final String result;

  /// The tool failed.
  final bool failed;

  final AgentStepKind kind;

  const AgentStep({
    this.agent = '',
    required this.label,
    this.thought = '',
    this.result = '',
    this.failed = false,
    this.kind = AgentStepKind.tool,
  });
}

/// The outcome of a run: the answer and how it was reached.
class AgentRun {
  final String answer;
  final List<AgentStep> steps;

  /// The model couldn't be asked (engine stopped, network…).
  final String? error;
  const AgentRun(this.answer, this.steps, {this.error});
}

/// Runs an agent: the model answers, or asks for tools; the tools run
/// (at the same time when there are several) and their results go back to
/// the model; until it answers or the steps run out.
///
/// In deep mode it first writes a plan, and its answer is then checked
/// against what it found: approved, corrected, or sent back for one more
/// round of research.
class AgentRunner {
  final AgentBackend backend;
  final List<AgentTool> tools;

  /// Rounds of tool calls allowed before the model must answer.
  final int maxSteps;

  /// Plan first, check the answer at the end.
  final bool deep;

  /// Tool results kept whole in the conversation, in characters; older
  /// ones are shortened beyond it (a phone's context is small).
  final int contextBudget;

  AgentRunner({
    AgentLlm? llm,
    AgentBackend? backend,
    required this.tools,
    this.maxSteps = 5,
    this.deep = false,
    this.contextBudget = 12000,
  })  : assert(llm != null || backend != null),
        backend = backend ?? TextAgentBackend(llm!);

  /// The system prompt: the agent's [instructions], its tools and how to
  /// call them.
  String systemPrompt(String instructions, {DateTime? today}) =>
      backend.systemPrompt(instructions, tools, maxSteps);

  static const _planPrompt =
      'Before working, write a short plan to answer the request below: at most 5 numbered steps, each saying what to find out or do, and with which tool when one helps. Do not answer the request yet.';

  static const _verifierPrompt =
      'You check answers before they reach the user. Compare the draft with the request and the evidence. '
      'If the draft is correct, complete and supported by the evidence, reply with exactly: APPROVED\n'
      'If something important is missing and could still be found with the tools, reply with: MISSING: followed by what to look for.\n'
      'Otherwise reply with the corrected final answer only, in the language of the request, keeping the source numbers.';

  /// Runs the agent on [question], after [history] (earlier turns, oldest
  /// first). [onStep] hears each step, [onActivity] what is happening now,
  /// [onPartial] the answer as it is written. [cancelled] stops between
  /// steps.
  Future<AgentRun> run({
    required String instructions,
    required String question,
    List<Map<String, String>> history = const [],
    String agentName = '',
    void Function(AgentStep step)? onStep,
    void Function(String activity)? onActivity,
    void Function(String partial)? onPartial,
    bool Function()? cancelled,
  }) async {
    final steps = <AgentStep>[];
    void record(AgentStep s) {
      steps.add(s);
      onStep?.call(s);
    }

    var system = systemPrompt(instructions);

    // ── Plan ──
    if (deep && tools.isNotEmpty) {
      onActivity?.call('PLAN');
      final plan = await backend.next([
        {'role': 'system', 'content': instructions},
        ...history,
        {'role': 'user', 'content': '$_planPrompt\n\nRequest:\n$question'},
      ], tools, allowTools: false, brief: true);
      final text = plan.text.trim();
      if (plan.error == null && text.isNotEmpty) {
        record(AgentStep(
            agent: agentName, label: 'PLAN', result: text, kind: AgentStepKind.plan));
        system = '$system\n\nYour plan (adapt it if what you find calls for it):\n$text';
      }
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': question},
    ];
    final evidence = <String>[];
    final seen = <String, String>{};
    var budget = maxSteps;
    var verified = false;
    var callCount = 0;

    for (var round = 0; round <= budget; round++) {
      if (cancelled?.call() ?? false) break;
      final lastChance = round == budget;
      if (lastChance && tools.isNotEmpty && callCount > 0) {
        messages.add({
          'role': 'user',
          'content':
              'Answer the question now with what you found, without any tool call.',
        });
      }
      _trim(messages);
      onActivity?.call('');
      final reply = await backend.next(messages, tools,
          allowTools: !lastChance, onPartial: onPartial);
      if (cancelled?.call() ?? false) break;
      if (reply.error != null) {
        return AgentRun('', steps, error: reply.error);
      }

      if (reply.calls.isEmpty) {
        var answer = reply.text.trim();
        // ── Verify ──
        if (deep && !verified && answer.isNotEmpty) {
          verified = true;
          onActivity?.call('VERIFY');
          final check = await backend.next([
            {'role': 'system', 'content': _verifierPrompt},
            {
              'role': 'user',
              'content': [
                'Request:\n$question',
                if (evidence.isNotEmpty)
                  'Evidence found:\n${_shorten(evidence.join('\n\n'), contextBudget ~/ 2)}',
                'Draft answer:\n$answer',
              ].join('\n\n'),
            },
          ], tools, allowTools: false, brief: true);
          final verdict = check.text.trim();
          if (check.error != null || verdict.isEmpty || verdict.startsWith('APPROVED')) {
            record(AgentStep(
                agent: agentName, label: 'APPROVED', kind: AgentStepKind.verify));
          } else if (verdict.startsWith('MISSING') && tools.isNotEmpty && !lastChance) {
            final gap = verdict.replaceFirst(RegExp(r'^MISSING:?\s*'), '');
            record(AgentStep(
                agent: agentName,
                label: 'MISSING',
                result: gap,
                kind: AgentStepKind.verify));
            onPartial?.call('');
            messages.add({'role': 'assistant', 'content': answer});
            messages.add({
              'role': 'user',
              'content':
                  'A reviewer says this is missing: $gap\nUse your tools to fill the gap, then give the complete answer again.',
            });
            budget = round + 3;
            continue;
          } else {
            record(AgentStep(
                agent: agentName,
                label: 'CORRECTED',
                result: verdict,
                kind: AgentStepKind.verify));
            answer = verdict;
          }
        }
        return AgentRun(answer, steps);
      }

      // ── Act ──
      onPartial?.call('');
      final calls = backend.native ? reply.calls : reply.calls.take(1).toList();
      final ids = [
        for (var i = 0; i < calls.length; i++)
          calls[i].id.isEmpty ? 'call_${callCount + i}' : calls[i].id,
      ];
      messages.add({
        'role': 'assistant',
        'content': reply.text,
        'tool_calls': [
          for (var i = 0; i < calls.length; i++)
            {
              'id': ids[i],
              'type': 'function',
              'function': {
                'name': calls[i].name,
                'arguments': jsonEncode(calls[i].arguments),
              },
            },
        ],
      });
      final results = await Future.wait([
        for (var i = 0; i < calls.length; i++)
          _runCall(calls[i], seen, agentName, onActivity),
      ]);
      for (var i = 0; i < calls.length; i++) {
        final (step, result) = results[i];
        record(AgentStep(
            agent: agentName,
            label: step.label,
            thought: i == 0 ? reply.text : '',
            result: result,
            failed: step.failed));
        evidence.add('[${step.label}]\n$result');
        messages.add({'role': 'tool', 'tool_call_id': ids[i], 'content': result});
      }
      callCount += calls.length;
    }
    return AgentRun('', steps);
  }

  Future<(AgentStep, String)> _runCall(
    ToolCall call,
    Map<String, String> seen,
    String agentName,
    void Function(String activity)? onActivity,
  ) async {
    final tool = tools.where((t) => t.name == call.name).firstOrNull;
    if (tool == null) {
      return (
        AgentStep(agent: agentName, label: call.name, failed: true),
        'Error: unknown tool ${call.name}. Available: ${tools.map((t) => t.name).join(', ')}.',
      );
    }
    final label = tool.label(call.arguments);
    final key = '${call.name} ${jsonEncode(call.arguments)}';
    if (seen.containsKey(key)) {
      return (
        AgentStep(agent: agentName, label: label),
        'You already did exactly this; the result is above. Use it, or try something different.',
      );
    }
    onActivity?.call(label);
    String result;
    var failed = false;
    try {
      result = await tool.run(call.arguments);
    } catch (e) {
      failed = true;
      result = 'Error: $e';
    }
    seen[key] = result;
    return (AgentStep(agent: agentName, label: label, failed: failed), result);
  }

  /// Shortens the oldest tool results once they add up to more than the
  /// budget: the model keeps what it read last whole.
  void _trim(List<Map<String, dynamic>> messages) {
    var total = 0;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m['role'] != 'tool') continue;
      final content = '${m['content']}';
      total += content.length;
      if (total > contextBudget && content.length > 400) {
        m['content'] = '${content.substring(0, 400)}… [shortened]';
      }
    }
  }

  static String _shorten(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';

  /// What can be shown of a reply being written: its answer so far, without
  /// thinking, and nothing from the point a tool call starts.
  static String visibleAnswer(String reply) {
    var text = ToolCallParser.withoutThinking(reply);
    for (final marker in [ToolCallParser.openTag, '<|tool_call_start|>', '{"name"', '```json']) {
      final at = text.indexOf(marker);
      if (at >= 0) text = text.substring(0, at);
    }
    // A tag being written ("<tool_c", "<|tool"), not a "less than".
    text = text.replaceFirst(RegExp(r'<[|/]?[A-Za-z_|]*$'), '');
    return text.trimRight();
  }
}

/// One member of a team, as the team runs it.
class TeamMember {
  final String name;

  /// Its role, read by the model.
  final String instructions;

  /// Its tools (empty: it only writes).
  final AgentRunner runner;

  const TeamMember({
    required this.name,
    required this.instructions,
    required this.runner,
  });
}

/// Runs a team: each member works in turn on the request, reading what the
/// members before it produced; the last one's work is the answer.
class TeamRunner {
  final List<TeamMember> members;
  const TeamRunner(this.members);

  /// What [member] (number [index]) is asked to do.
  static String briefing({
    required String request,
    required List<({String name, String output})> before,
    required int index,
    required int count,
  }) {
    final last = index == count - 1;
    return [
      'Request from the user:\n$request',
      if (before.isNotEmpty)
        'Work done so far by your team:\n${before.map((b) => '## ${b.name}\n${b.output}').join('\n\n')}',
      last
          ? 'You are the last member of the team: write the final answer for the user, in the language of their request, using the team\'s work.'
          : 'Do your part of the work for the next member of the team. Be concise.',
    ].join('\n\n');
  }

  Future<AgentRun> run({
    required String request,
    List<Map<String, String>> history = const [],
    void Function(AgentStep step)? onStep,
    void Function(String activity, int index, int count)? onMember,
    void Function(String activity)? onActivity,
    void Function(String partial)? onPartial,
    bool Function()? cancelled,
  }) async {
    final steps = <AgentStep>[];
    final outputs = <({String name, String output})>[];
    var answer = '';
    for (var i = 0; i < members.length; i++) {
      if (cancelled?.call() ?? false) break;
      final member = members[i];
      final last = i == members.length - 1;
      onMember?.call(member.name, i, members.length);
      final run = await member.runner.run(
        instructions: member.instructions,
        question: briefing(
            request: request, before: outputs, index: i, count: members.length),
        // Only the first member reads the conversation: the others work
        // from the briefing, which keeps the context small.
        history: i == 0 ? history : const [],
        agentName: member.name,
        onStep: (s) {
          steps.add(s);
          onStep?.call(s);
        },
        onActivity: onActivity,
        onPartial: last ? onPartial : null,
        cancelled: cancelled,
      );
      if (run.error != null) return AgentRun('', steps, error: run.error);
      outputs.add((name: member.name, output: run.answer));
      if (last) {
        answer = run.answer;
      } else {
        final contribution = AgentStep(
            agent: member.name,
            label: member.name,
            result: run.answer,
            kind: AgentStepKind.member);
        steps.add(contribution);
        onStep?.call(contribution);
      }
    }
    return AgentRun(answer, steps);
  }
}
