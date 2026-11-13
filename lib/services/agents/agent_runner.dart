import 'dart:convert';

import 'agent_tools.dart';
import 'tool_call_parser.dart';

/// A model to talk to: takes the messages (system first), returns the
/// reply. Streams tokens to [onToken] and may stop at [stop].
typedef AgentLlm = Future<String> Function(
  List<Map<String, String>> messages, {
  void Function(String token)? onToken,
  List<String> stop,
});

/// One thing the agent did.
class AgentStep {
  /// Who did it, in a team ('' for a single agent).
  final String agent;

  /// What it did, for the user ("Searching the web: …", or a team
  /// member's contribution).
  final String label;

  /// What the model wrote before acting, if anything.
  final String thought;

  /// What came back (a tool's result, or a team member's output).
  final String result;

  /// The tool failed.
  final bool failed;

  const AgentStep({
    this.agent = '',
    required this.label,
    this.thought = '',
    this.result = '',
    this.failed = false,
  });
}

/// The outcome of a run: the answer and how it was reached.
class AgentRun {
  final String answer;
  final List<AgentStep> steps;
  const AgentRun(this.answer, this.steps);
}

/// Runs an agent: the model answers, or asks for a tool; the tool runs and
/// its result goes back to the model; until the model answers or the steps
/// run out. Works with any model, through text: the tools are described in
/// the system prompt and calls are read from the reply.
class AgentRunner {
  final AgentLlm llm;
  final List<AgentTool> tools;

  /// Tool calls allowed before the model must answer.
  final int maxSteps;

  const AgentRunner({required this.llm, required this.tools, this.maxSteps = 5});

  /// The system prompt: the agent's [instructions], its tools and how to
  /// call them.
  String systemPrompt(String instructions, {DateTime? today}) {
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

  /// Runs the agent on [question], after [history] (earlier turns, oldest
  /// first). [onStep] hears each tool used, [onActivity] what is happening
  /// now, [onPartial] the answer as it is written. [cancelled] stops
  /// between steps.
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
    final names = {for (final t in tools) t.name};
    final steps = <AgentStep>[];
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt(instructions)},
      ...history,
      {'role': 'user', 'content': question},
    ];

    for (var step = 0; step <= maxSteps; step++) {
      if (cancelled?.call() ?? false) break;
      final lastChance = step == maxSteps;
      if (lastChance && tools.isNotEmpty) {
        messages.add({
          'role': 'user',
          'content':
              'Answer the question now with what you found, without any tool call.',
        });
      }
      final buffer = StringBuffer();
      final reply = await llm(
        messages,
        stop: tools.isEmpty || lastChance ? const [] : ToolCallParser.stopSequences,
        onToken: (token) {
          buffer.write(token);
          onPartial?.call(visibleAnswer(buffer.toString()));
        },
      );
      final call =
          tools.isEmpty || lastChance ? null : ToolCallParser.parse(reply, names);
      if (call == null) {
        return AgentRun(ToolCallParser.withoutThinking(reply), steps);
      }

      onPartial?.call('');
      final tool = tools.firstWhere((t) => t.name == call.name);
      final label = tool.label(call.arguments);
      onActivity?.call(label);
      String result;
      var failed = false;
      try {
        result = await tool.run(call.arguments);
      } catch (e) {
        failed = true;
        result = 'Error: $e';
      }
      final done = AgentStep(
          agent: agentName,
          label: label,
          thought: call.before,
          result: result,
          failed: failed);
      steps.add(done);
      onStep?.call(done);

      // The call as the model should have written it, then the result.
      messages.add({
        'role': 'assistant',
        'content': [
          if (call.before.isNotEmpty) call.before,
          ToolCallParser.openTag,
          jsonEncode({'name': call.name, 'arguments': call.arguments}),
          ToolCallParser.closeTag,
        ].join('\n'),
      });
      messages.add({
        'role': 'user',
        'content': '<tool_response>\n$result\n</tool_response>',
      });
    }
    return AgentRun('', steps);
  }

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
      outputs.add((name: member.name, output: run.answer));
      if (last) {
        answer = run.answer;
      } else {
        final contribution = AgentStep(
            agent: member.name, label: member.name, result: run.answer);
        steps.add(contribution);
        onStep?.call(contribution);
      }
    }
    return AgentRun(answer, steps);
  }
}
