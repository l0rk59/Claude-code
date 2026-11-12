import 'package:flutter/services.dart';

/// Engine options for GGUF models on Android: the GPU backend, the
/// speculative-decoding draft model and the vision projector.
class LlamaEngine {
  static const _channel = MethodChannel('llama_flutter_android/engine');

  /// 'vulkan' (default) or 'opencl' (Adreno 730 and later). Applies from the
  /// next [LlamaController.detectGpu].
  static Future<void> setGpuApi(String api) =>
      _channel.invokeMethod('setGpuApi', {'api': api});

  /// Loads a small model with the same vocabulary as the loaded main model,
  /// used to propose tokens the main model then checks in one batch (same
  /// output, faster when the draft guesses well). Text turns only; freed with
  /// the main model. Returns an error message, or null on success.
  static Future<String?> loadDraftModel(String path, {int threads = 4}) =>
      _channel.invokeMethod<String>(
          'loadDraftModel', {'path': path, 'threads': threads});

  /// Loads the vision projector ("mmproj") of the loaded model, so it can
  /// read images. Doing this when the first image arrives, rather than with
  /// the model, keeps the projector's weights (0.2 to 0.9 GB) out of memory
  /// during text-only chats. Freed with the model. Returns an error message,
  /// or null on success.
  static Future<String?> loadVision(String path, {int threads = 4}) =>
      _channel.invokeMethod<String>(
          'loadVision', {'path': path, 'threads': threads});

  /// Stops using the draft model and frees it.
  static Future<void> freeDraftModel() =>
      _channel.invokeMethod('freeDraftModel');
}
