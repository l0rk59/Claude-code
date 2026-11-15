import 'dart:io';

import 'package:get/get.dart';

import '../../core/app_dirs.dart';
import '../../core/constants.dart';
import '../hive_service.dart';
import '../openai_chat_client.dart';
import '../sampling_presets.dart';
import 'desktop_engine_service.dart';
import 'llama_server_process.dart';

/// How a load on the computer went.
class DesktopLoad {
  final bool success;
  final String message;
  final String gpuName;
  final int gpuLayers;
  final String backend;
  const DesktopLoad({
    required this.success,
    required this.message,
    this.gpuName = '',
    this.gpuLayers = 0,
    this.backend = '',
  });
}

/// The computer app's side of the inference engine: the model runs in
/// llama-server (see [DesktopEngineService]); this sends it the chat.
class DesktopInference {
  final DesktopEngineService engine;
  DesktopInference(this.engine);

  OpenAiChatClient? _active;
  bool _hasVision = false;
  String? _draftUsed;
  String? _draftError;
  int _tokensUsed = 0;

  bool get hasVision => _hasVision;

  /// Messages as the chat sends them, in OpenAI format.
  static Future<List<Map<String, dynamic>>> buildMessages({
    required String prompt,
    required String systemPrompt,
    List<Map<String, String>>? history,
    String? imagePath,
    int maxHistory = 40,
  }) async {
    final messages = <Map<String, dynamic>>[
      if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
    ];
    if (history != null && history.isNotEmpty) {
      var recent = history.length > maxHistory
          ? history.sublist(history.length - maxHistory)
          : List.of(history);
      if (recent.isNotEmpty &&
          recent.last['role'] == 'user' &&
          recent.last['content'] == prompt) {
        recent = recent.sublist(0, recent.length - 1);
      }
      for (final m in recent) {
        messages.add({'role': m['role'] ?? 'user', 'content': m['content'] ?? ''});
      }
    }
    if (imagePath != null && imagePath.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {'url': await imageDataUri(imagePath)},
          },
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }
    return messages;
  }

  Future<DesktopLoad> loadModel({
    required String modelPath,
    required int contextSize,
    bool useGpu = true,
    int? threads,
    String? mmprojPath,
    void Function(double)? onProgress,
  }) async {
    final lower = modelPath.toLowerCase();
    if (lower.endsWith('.litertlm') || lower.endsWith('.task')) {
      return DesktopLoad(
        success: false,
        message: 'ERROR: LiteRT models run on phones only. On the computer, '
                'use a GGUF model.'
            .tr,
      );
    }
    // The engine is downloaded with the first model (about 30 MB).
    if (await engine.binary() == null) {
      try {
        final sub = engine.installProgress.listen((p) => onProgress?.call(p * 0.5));
        try {
          await engine.install(engine.chosenVariant);
        } finally {
          await sub.cancel();
        }
      } catch (e) {
        return DesktopLoad(
          success: false,
          message: "ERROR: The engine couldn't be downloaded: @error"
              .trParams({'error': '$e'}),
        );
      }
    }
    final draft = _draftPath(modelPath);
    try {
      final server = await engine.start(
        modelPath: modelPath,
        alias: baseName(modelPath).replaceAll(RegExp(r'\.gguf$', caseSensitive: false), ''),
        contextSize: contextSize,
        useGpu: useGpu,
        threads: threads,
        mmprojPath: mmprojPath,
        draftPath: draft,
        onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
      );
      _hasVision = mmprojPath != null;
      _draftUsed = draft;
      _draftError = null;
      _tokensUsed = 0;
      final gpu = engine.mainGpu;
      final layers = server.offloaded;
      final onGpu = useGpu && gpu != null && (layers == null || layers.$1 > 0);
      final workers = server.config.rpc.length;
      final skipped = engine.skippedWorkers;
      final accel = onGpu
          ? (layers != null
              ? 'GPU (@layers layers, @gpu)'
                  .trParams({'layers': '${layers.$1}', 'gpu': gpu.name})
              : gpu.name)
          : 'Processor'.tr;
      final loaded = workers > 0
          ? 'Model loaded (@accel) with @count phones lending their memory.'
              .trParams({'accel': accel, 'count': '$workers'})
          : 'Model loaded (@accel).'.trParams({'accel': accel});
      return DesktopLoad(
        success: true,
        message: skipped.isEmpty
            ? loaded
            : '$loaded ${'Not reachable, loading without: @names'.trParams({'names': skipped.join(', ')})}',
        gpuName: onGpu ? gpu.name : '',
        gpuLayers: onGpu ? (layers?.$1 ?? 1) : 0,
        backend: onGpu ? 'gpu' : 'cpu',
      );
    } on EngineStartException catch (e) {
      return DesktopLoad(
        success: false,
        message: 'ERROR: @error'.trParams({'error': e.message}),
      );
    } catch (e) {
      return DesktopLoad(
        success: false,
        message: 'ERROR: Failed to load model — @error'.trParams({'error': '$e'}),
      );
    }
  }

  /// The speculative-decoding draft picked in Settings, next to the model.
  String? _draftPath(String modelPath) {
    if (!Get.isRegistered<HiveService>()) return null;
    final draft = Get.find<HiveService>()
            .getSetting<String>(AppConstants.keySpeculativeDraftModel) ??
        '';
    if (draft.isEmpty || baseName(modelPath) == draft) return null;
    final path = '${dirName(modelPath)}/$draft';
    if (!File(path).existsSync()) {
      _draftError = 'Draft model file not found';
      return null;
    }
    return path;
  }

  /// Null when the draft picked in Settings is in use.
  String? draftResult(String path) {
    if (_draftUsed != null && baseName(_draftUsed!) == baseName(path)) return null;
    return _draftError ?? 'Draft model not used';
  }

  Future<String> generate({
    required String prompt,
    List<Map<String, String>>? conversationHistory,
    required String systemPrompt,
    required String modelName,
    required int maxTokens,
    required double temperature,
    String? imagePath,
    void Function(String token)? onToken,
  }) async {
    final client = engine.client();
    if (client == null) return 'ERROR: The engine is not running. Load the model again.'.tr;
    if (imagePath != null && imagePath.isNotEmpty && !_hasVision) {
      return "This model can't read images. Load a vision model (one marked "
              'Vision in Models) to ask about photos.'
          .tr;
    }
    _active = client;
    final preset = SamplingPreset.forModel(modelName);
    final out = StringBuffer();
    var thinking = false;
    void emit(String s) {
      out.write(s);
      onToken?.call(s);
    }

    // A long conversation can outgrow the context: the server refuses it
    // whole, so the oldest turns are left out until it fits.
    ChatReply reply;
    var keep = 40;
    while (true) {
      reply = await _complete(client, prompt, systemPrompt,
          conversationHistory, imagePath, keep, temperature, maxTokens, preset,
          onReasoning: (t) {
        if (!thinking) {
          thinking = true;
          emit('<think>');
        }
        emit(t);
      }, onText: (t) {
        if (thinking) {
          thinking = false;
          emit('</think>\n\n');
        }
        emit(t);
      });
      if (reply.ok || out.isNotEmpty || keep == 0 || !isContextOverflow(reply.error!)) {
        break;
      }
      keep = keep > 8 ? keep ~/ 3 : 0;
    }
    if (thinking) emit('</think>\n\n');
    if (identical(_active, client)) _active = null;
    if (reply.promptTokens + reply.completionTokens > 0) {
      _tokensUsed = reply.promptTokens + reply.completionTokens;
    }
    if (!reply.ok && out.isEmpty) {
      return isContextOverflow(reply.error!)
          ? 'ERROR: This message is too long for the context of the model. Shorten it, or raise the context in Settings > Chat > Model parameters.'
              .tr
          : 'ERROR: Generation failed — @error'.trParams({'error': reply.error!});
    }
    if (!reply.ok) {
      emit('\n\n⚠️ ${'The answer was cut off: @error'.trParams({'error': reply.error!})}');
    }
    return out.toString();
  }

  /// The server's refusal of a request longer than the context.
  static bool isContextOverflow(String error) => RegExp(
          r'exceed_context_size|exceeds the available context|context size|n_ctx',
          caseSensitive: false)
      .hasMatch(error);

  Future<ChatReply> _complete(
    OpenAiChatClient client,
    String prompt,
    String systemPrompt,
    List<Map<String, String>>? history,
    String? imagePath,
    int keep,
    double temperature,
    int maxTokens,
    SamplingPreset preset, {
    required void Function(String) onReasoning,
    required void Function(String) onText,
  }) async {
    final reply = await client.complete(
      messages: await buildMessages(
        prompt: prompt,
        systemPrompt: systemPrompt,
        history: keep == 0 ? const [] : history,
        imagePath: imagePath,
        maxHistory: keep == 0 ? 1 : keep,
      ),
      temperature: temperature,
      maxTokens: maxTokens,
      extra: {
        'top_p': preset.topP,
        'top_k': preset.topK,
        'min_p': preset.minP,
        'repeat_penalty': preset.repeatPenalty,
        'presence_penalty': preset.presencePenalty,
        'repeat_last_n': 64,
        'cache_prompt': true,
      },
      // The chat shows thinking between <think> tags, as phones send it.
      onReasoning: onReasoning,
      onText: onText,
    );
    return reply;
  }

  Future<void> stop() async {
    _active?.cancel();
    _active = null;
  }

  (int used, int size)? contextInfo() {
    final s = engine.server;
    if (s == null) return null;
    return (_tokensUsed, s.contextSize);
  }

  Future<void> dispose() async {
    await stop();
    await engine.stop();
    _hasVision = false;
  }
}
