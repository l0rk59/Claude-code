// The computer app's engine for real: llama.cpp's own llama-server,
// downloaded from its releases, with a real model. Skipped unless
// PRIVATELM_REAL_ENGINE_MODEL names a GGUF file (GitHub runs it: see
// .github/workflows/engine-test.yml).
//
//   PRIVATELM_REAL_ENGINE_MODEL=/path/model.gguf flutter test test/real_engine
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/services/agents/agent_runner.dart';
import 'package:privatelm/services/agents/agent_tools.dart';
import 'package:privatelm/services/desktop/desktop_engine_service.dart';
import 'package:privatelm/services/desktop/desktop_inference.dart';
import 'package:privatelm/services/desktop/llama_engine.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/services/openai_chat_client.dart';

void main() {
  final model = Platform.environment['PRIVATELM_REAL_ENGINE_MODEL'] ?? '';
  final skip = model.isEmpty ? 'set PRIVATELM_REAL_ENGINE_MODEL' : false;
  // The processor build by default: runners have no graphics card.
  final variantId = Platform.environment['PRIVATELM_REAL_ENGINE_VARIANT'] ?? 'cpu';

  late Directory dir;
  late DesktopEngineService engine;
  late DesktopInference inference;

  setUpAll(() async {
    if (model.isEmpty) return;
    dir = await Directory.systemTemp.createTemp('real_engine');
    Hive.init('${dir.path}/hive');
    final hive = await HiveService().init();
    engine = DesktopEngineService(hive: hive, root: Directory('${dir.path}/engine'));
    inference = DesktopInference(engine);
  });

  tearDownAll(() async {
    if (model.isEmpty) return;
    await engine.stop();
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('installs the official release and finds its server', () async {
    final variant = engine.variants.firstWhere((v) => v.id == variantId);
    final watch = Stopwatch()..start();
    await engine.install(variant);
    final bin = await engine.binary();
    print('[real] installed ${variant.assets.join(', ')} in ${watch.elapsed.inSeconds} s → $bin');
    expect(bin, isNotNull);
    expect(bin, endsWith(LlamaEngine.binaryName(engine.os)));
    await engine.refreshDevices();
    print('[real] devices: ${engine.devices.map((d) => '${d.id} ${d.name} ${d.totalMb} MiB').join('; ')}');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

  test('loads the model and chats', () async {
    final watch = Stopwatch()..start();
    final load = await inference.loadModel(
        modelPath: model, contextSize: 4096, useGpu: variantId != 'cpu');
    print('[real] load: ${load.message} (${watch.elapsed.inMilliseconds} ms)');
    expect(load.success, isTrue, reason: load.message);
    expect(engine.server!.contextSize, 4096);

    watch.reset();
    final tokens = <String>[];
    final answer = await inference.generate(
      prompt: 'What is the capital of France? Answer in one short sentence.',
      systemPrompt: 'You are a helpful assistant.',
      modelName: 'qwen3.5-0.8b',
      maxTokens: 400,
      temperature: 0.2,
      onToken: tokens.add,
    );
    final seconds = watch.elapsed.inMilliseconds / 1000;
    print('[real] answer (${tokens.length} pieces, $seconds s): $answer');
    expect(answer, isNot(startsWith('ERROR')));
    expect(tokens.join(), answer, reason: 'what streamed is what was returned');
    final visible = answer.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
    expect(visible.toLowerCase(), contains('paris'));
    final info = inference.contextInfo()!;
    print('[real] context: ${info.$1} of ${info.$2} tokens');
    expect(info.$1, greaterThan(10));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 8)));

  test('the model calls a tool through the native protocol', () async {
    final reply = await engine.client()!.complete(
      messages: [
        {'role': 'system', 'content': 'You are a helpful assistant.'},
        {'role': 'user', 'content': 'What is 1234 * 56? Use the calculator.'},
      ],
      tools: const [
        ChatToolSpec(
          name: 'calculator',
          description: 'Computes arithmetic exactly.',
          parameters: {
            'type': 'object',
            'properties': {
              'expression': {'type': 'string', 'description': 'e.g. "2*3"'},
            },
            'required': ['expression'],
          },
        ),
      ],
      temperature: 0,
      maxTokens: 600,
      extra: const {'tool_choice': 'required'},
    );
    print('[real] tool turn: error=${reply.error} finish=${reply.finishReason} '
        'calls=${reply.toolCalls.map((c) => '${c.name}(${c.rawArguments})').join(', ')} '
        'reasoning=${reply.reasoning.length} chars');
    expect(reply.error, isNull);
    expect(reply.toolCalls, isNotEmpty);
    expect(reply.toolCalls.first.name, 'calculator');
    expect(reply.toolCalls.first.arguments['expression'], isA<String>());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 8)));

  AgentToolbox toolbox() => AgentToolbox(
        searchWeb: (q) async => const [],
        fetchPage: (u) async => '',
        searchDocs: (q) => const [],
      );

  test('an agent runs to an answer with its tools', () async {
    final tools = toolbox();
    final steps = <String>[];
    final run = await AgentRunner(
      backend: NativeAgentBackend(() => engine.client()!,
          temperature: 0.2, maxTokens: 800),
      tools: tools.tools([AgentToolbox.calculator, AgentToolbox.dateTime]),
      maxSteps: 4,
    ).run(
      instructions:
          'You are an analyst. Use the calculator for every calculation.',
      question: 'How much is 365 * 24? Give the number.',
      onStep: (s) => steps.add('${s.label} → ${s.result}'),
    );
    print('[real] agent steps: $steps');
    print('[real] agent answer: ${run.answer}');
    expect(run.error, isNull);
    expect(run.answer, isNotEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('deep mode plans and checks on a real model', () async {
    final steps = <String>[];
    final run = await AgentRunner(
      backend: NativeAgentBackend(() => engine.client()!,
          temperature: 0.2, maxTokens: 800),
      tools: toolbox().tools([AgentToolbox.calculator]),
      maxSteps: 3,
      deep: true,
    ).run(
      instructions: 'You are an analyst. Use the calculator for calculations.',
      question: 'A train travels 120 km in 1.5 hours. What is its speed in km/h?',
      onStep: (s) => steps.add('${s.kind.name}:${s.label}'),
    );
    print('[real] deep steps: $steps');
    print('[real] deep answer: ${run.answer}');
    expect(run.error, isNull);
    expect(run.answer, isNotEmpty);
    expect(steps.first, startsWith('plan:'));
    expect(steps.any((s) => s.startsWith('verify:')), isTrue);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 12)));

  test('stopping cuts a long answer short', () async {
    final watch = Stopwatch()..start();
    final pending = inference.generate(
      prompt: 'Write a very long story about a lighthouse keeper.',
      systemPrompt: 'You are a writer.',
      modelName: 'qwen3.5-0.8b',
      maxTokens: 4000,
      temperature: 0.7,
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await inference.stop();
    await pending;
    print('[real] stopped after ${watch.elapsed.inMilliseconds} ms');
    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('stopping the engine ends the program', () async {
    final server = engine.server!;
    await inference.dispose();
    final code = await server.process.exitCode.timeout(const Duration(seconds: 10));
    print('[real] llama-server exited with $code');
    expect(engine.running.value, isFalse);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 1)));
}
