import 'dart:async';

import 'hive_service.dart';
import 'inference_service.dart';

/// One measurement of how fast a model answers on this phone.
class SpeedResult {
  final String model;

  /// How the model was running: "GGUF · CPU", "LiteRT · GPU"…
  final String setup;

  /// Time before the first token showed.
  final double firstTokenSeconds;

  /// Generation speed once it had started.
  final double tokensPerSecond;
  final int tokens;
  final DateTime at;

  const SpeedResult({
    required this.model,
    required this.setup,
    required this.firstTokenSeconds,
    required this.tokensPerSecond,
    required this.tokens,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'model': model,
        'setup': setup,
        'first': firstTokenSeconds,
        'speed': tokensPerSecond,
        'tokens': tokens,
        'at': at.millisecondsSinceEpoch,
      };

  factory SpeedResult.fromMap(Map<dynamic, dynamic> map) => SpeedResult(
        model: '${map['model'] ?? ''}',
        setup: '${map['setup'] ?? ''}',
        firstTokenSeconds: (map['first'] as num?)?.toDouble() ?? 0,
        tokensPerSecond: (map['speed'] as num?)?.toDouble() ?? 0,
        tokens: (map['tokens'] as num?)?.toInt() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch(
            (map['at'] as num?)?.toInt() ?? 0),
      );
}

/// Measures the loaded model with the same short task every time, so two
/// settings (processor or graphics card, alone or in a cluster, one model
/// or another) can be compared on the phone itself rather than guessed.
class SpeedTest {
  /// Always the same request, in English: results only compare if the work
  /// is the same.
  static const prompt =
      'Explain how a bicycle stays upright while moving, in about 120 words.';
  static const systemPrompt = 'You are a helpful assistant.';

  /// Long enough to settle into a steady speed, short enough to wait for.
  static const maxTokens = 96;

  static const _historyKey = 'speed_test_results';
  static const _kept = 12;

  /// Tokens per second once generation has started: the first token is
  /// left out, because the wait before it (reading the prompt) is reported
  /// separately.
  static double rate({
    required int tokens,
    required Duration total,
    required Duration firstToken,
  }) {
    final generating = total - firstToken;
    if (tokens < 2 || generating <= Duration.zero) return 0;
    return (tokens - 1) / (generating.inMicroseconds / 1e6);
  }

  /// "GGUF · GPU (Adreno 740)", "LiteRT · CPU"…
  static String describeSetup({
    required String runtime,
    required bool gpu,
    String gpuName = '',
    int clusterWorkers = 0,
  }) {
    final engine = runtime == 'litert' ? 'LiteRT' : 'GGUF';
    final device = !gpu
        ? 'CPU'
        : gpuName.isEmpty
            ? 'GPU'
            : 'GPU ($gpuName)';
    return [
      engine,
      device,
      if (clusterWorkers > 0) 'cluster × ${clusterWorkers + 1}',
    ].join(' · ');
  }

  /// Runs the task on the model loaded in [inference]. [onProgress] gets
  /// the number of tokens so far. Throws a [StateError] with the engine's
  /// message when the model can't answer.
  static Future<SpeedResult> run(
    InferenceService inference, {
    int clusterWorkers = 0,
    int maxTokens = SpeedTest.maxTokens,
    void Function(int tokens)? onProgress,
  }) async {
    final watch = Stopwatch()..start();
    Duration? first;
    final answer = await inference.generate(
      prompt: prompt,
      systemPrompt: systemPrompt,
      conversationHistory: const [],
      maxTokens: maxTokens,
      onToken: (_) {
        first ??= watch.elapsed;
        onProgress?.call(inference.tokenCount.value);
      },
    );
    watch.stop();
    final tokens = inference.tokenCount.value;
    if (answer.startsWith('ERROR') || first == null || tokens == 0) {
      throw StateError(answer.isEmpty ? 'The model gave no answer' : answer);
    }
    return SpeedResult(
      model: inference.loadedModelName.value,
      setup: describeSetup(
        runtime: inference.loadedModelRuntime.value,
        gpu: inference.isGpuAccelerated.value,
        gpuName: inference.gpuName.value,
        clusterWorkers: clusterWorkers,
      ),
      firstTokenSeconds: first!.inMicroseconds / 1e6,
      tokensPerSecond:
          rate(tokens: tokens, total: watch.elapsed, firstToken: first!),
      tokens: tokens,
      at: DateTime.now(),
    );
  }

  /// Earlier measurements, most recent first.
  static List<SpeedResult> history(HiveService hive) {
    final raw = hive.getSetting<List>(_historyKey, defaultValue: const []) ??
        const [];
    return [
      for (final entry in raw.whereType<Map>()) SpeedResult.fromMap(entry),
    ];
  }

  /// Keeps [result] at the top of the history, which holds the last few.
  static Future<List<SpeedResult>> remember(
      HiveService hive, SpeedResult result) async {
    final all = [result, ...history(hive)].take(_kept).toList();
    await hive.setSetting(_historyKey, [for (final r in all) r.toMap()]);
    return all;
  }
}
