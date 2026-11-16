import 'dart:io';

import 'package:get/get.dart';

/// The llama.cpp build the computer app runs: llama-server from the
/// official releases. Same release as the phones' engine, so a computer and
/// phones speak the same cluster (RPC) protocol.
abstract final class LlamaEngine {
  static const release = 'b11157';

  static String releaseUrl(String asset) =>
      'https://github.com/ggml-org/llama.cpp/releases/download/$release/$asset';

  /// The server program's file name on [os] ('windows', 'linux', 'macos').
  static String binaryName(String os) =>
      os == 'windows' ? 'llama-server.exe' : 'llama-server';

  static String get currentOs => Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
          ? 'macos'
          : 'linux';

  /// The builds offered on [os], the recommended one first.
  static List<EngineVariant> variantsFor(String os, {bool arm = false}) =>
      switch (os) {
        'windows' => [
            EngineVariant('vulkan', ['llama-$release-bin-win-vulkan-${arm ? 'arm64' : 'x64'}.zip'], 32),
            if (!arm)
              const EngineVariant('cuda', [
                'llama-$release-bin-win-cuda-12.4-x64.zip',
                'cudart-llama-bin-win-cuda-12.4-x64.zip',
              ], 646),
            EngineVariant('cpu', ['llama-$release-bin-win-cpu-${arm ? 'arm64' : 'x64'}.zip'], 19),
          ],
        'macos' => [
            EngineVariant(arm ? 'metal' : 'cpu',
                ['llama-$release-bin-macos-${arm ? 'arm64' : 'x64'}.tar.gz'], 11),
          ],
        _ => [
            const EngineVariant('vulkan', ['llama-$release-bin-ubuntu-vulkan-x64.tar.gz'], 31),
            const EngineVariant('cpu', ['llama-$release-bin-ubuntu-x64.tar.gz'], 17),
          ],
      };

  static EngineVariant? variant(String os, String id, {bool arm = false}) =>
      variantsFor(os, arm: arm).firstWhereOrNull((v) => v.id == id);

  /// The llama-server command line for [config].
  static List<String> serverArgs(ServerConfig config) => [
        '-m', config.modelPath,
        '--host', config.host,
        '--port', '${config.port}',
        if (config.apiKey.isNotEmpty) ...['--api-key', config.apiKey],
        if (config.alias.isNotEmpty) ...['--alias', config.alias],
        if (config.contextSize > 0) ...['-c', '${config.contextSize}'],
        // One conversation at a time unless the phones share it.
        '-np', config.host == '127.0.0.1' ? '1' : '2',
        if (!config.useGpu) ...['-ngl', '0'],
        if (config.threads != null && config.threads! > 0)
          ...['-t', '${config.threads}'],
        if (config.mmprojPath != null) ...['--mmproj', config.mmprojPath!],
        if (config.draftPath != null) ...['-md', config.draftPath!],
        if (config.rpc.isNotEmpty) ...['--rpc', config.rpc.join(',')],
        '--no-webui',
      ];

  /// What a line of the server's log says about the load, if anything.
  static LoadStage? stageOf(String line) {
    if (line.contains('server is listening') ||
        line.contains('all slots are idle')) {
      return LoadStage.ready;
    }
    if (line.contains('llama_context:') || line.contains('srv    load_model')) {
      return LoadStage.context;
    }
    if (line.contains('load_tensors:') || line.contains('llama_model_load')) {
      return LoadStage.weights;
    }
    return null;
  }

  /// "offloaded 29/37 layers to GPU" → (29, 37).
  static (int, int)? offloadedLayers(String line) {
    final m = RegExp(r'offloaded (\d+)/(\d+) layers to GPU').firstMatch(line);
    return m == null ? null : (int.parse(m[1]!), int.parse(m[2]!));
  }

  /// The graphics cards `llama-server --list-devices` reports, e.g.
  /// "Vulkan0: NVIDIA GeForce RTX 3060 (12288 MiB, 11203 MiB free)".
  static List<EngineDevice> parseDevices(String output) => [
        for (final m in RegExp(
                r'^\s*(\w+?\d*):\s*(.+?)\s*\((\d+) MiB, (\d+) MiB free\)',
                multiLine: true)
            .allMatches(output))
          EngineDevice(
            id: m[1]!,
            name: m[2]!,
            totalMb: int.parse(m[3]!),
            freeMb: int.parse(m[4]!),
          ),
      ];

  /// A short reason for the user when the server stopped while loading,
  /// from the end of its log.
  static String failureReason(List<String> log) {
    final text = log.join('\n');
    if (RegExp(r'unknown model architecture', caseSensitive: false)
        .hasMatch(text)) {
      return "This engine doesn't know this type of model yet.".tr;
    }
    if (RegExp(r'out of memory|failed to allocate|ErrorOutOfDeviceMemory|cudaMalloc failed',
            caseSensitive: false)
        .hasMatch(text)) {
      return 'Not enough memory for this model. Try a smaller model, a '
              'smaller context, or the processor only.'
          .tr;
    }
    // Not just "bind": every start logs "binding port with default address
    // family", so a model that fails to load would read as a port problem.
    if (RegExp(r"address already in use|(couldn't|could not|failed to) bind",
            caseSensitive: false)
        .hasMatch(text)) {
      return 'The network port is already used by another program.'.tr;
    }
    if (RegExp(r'failed to load model|error loading model', caseSensitive: false)
        .hasMatch(text)) {
      return "The model file couldn't be read: it may be incomplete or damaged."
          .tr;
    }
    if (RegExp(r'Failed to connect to|RPC.*(connect|unreachable)',
            caseSensitive: false)
        .hasMatch(text)) {
      return "A phone lending its memory can't be reached.".tr;
    }
    for (final line in log.reversed) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return 'The engine stopped.'.tr;
  }
}

/// A build of the engine: which graphics cards it uses, what to download.
class EngineVariant {
  /// 'vulkan', 'cuda', 'cpu' or 'metal'.
  final String id;

  /// Release files, extracted into the same folder.
  final List<String> assets;

  /// Approximate download size.
  final int downloadMb;

  const EngineVariant(this.id, this.assets, this.downloadMb);

  String get title => switch (id) {
        'vulkan' => 'Graphics card (Vulkan)'.tr,
        'cuda' => 'NVIDIA graphics card (CUDA)'.tr,
        'metal' => 'Apple chip (Metal)'.tr,
        _ => 'Processor only'.tr,
      };

  String get description => switch (id) {
        'vulkan' =>
          'Works with NVIDIA, AMD and Intel cards, and on the processor without one.'
              .tr,
        'cuda' => 'Fastest on NVIDIA cards. Bigger download.'.tr,
        'metal' => 'Uses the graphics part of Apple chips.'.tr,
        _ => 'For computers whose graphics card causes problems.'.tr,
      };
}

/// How to start llama-server.
class ServerConfig {
  final String modelPath;
  final String host;
  final int port;
  final String apiKey;
  final String alias;
  final int contextSize;
  final bool useGpu;
  final int? threads;
  final String? mmprojPath;
  final String? draftPath;

  /// Phones (or computers) lending their memory: host:port of their
  /// ggml-rpc-server.
  final List<String> rpc;

  const ServerConfig({
    required this.modelPath,
    this.host = '127.0.0.1',
    required this.port,
    this.apiKey = '',
    this.alias = '',
    this.contextSize = 0,
    this.useGpu = true,
    this.threads,
    this.mmprojPath,
    this.draftPath,
    this.rpc = const [],
  });
}

enum LoadStage { weights, context, ready }

/// A graphics card the engine can use.
class EngineDevice {
  final String id;
  final String name;
  final int totalMb;
  final int freeMb;
  const EngineDevice(
      {required this.id,
      required this.name,
      required this.totalMb,
      required this.freeMb});

  bool get isRemote => id.toUpperCase().startsWith('RPC');
}
