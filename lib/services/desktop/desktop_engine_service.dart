import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/app_dirs.dart';
import '../../core/constants.dart';
import '../app_log_service.dart';
import '../hive_service.dart';
import '../device_info_service.dart';
import '../lan_server_finder.dart';
import '../model_fit.dart';
import '../openai_chat_client.dart';
import '../rpc_probe.dart';
import 'llama_engine.dart';
import 'llama_server_process.dart';

/// The computer app's engine: installs llama.cpp's llama-server, runs the
/// loaded model in it, and optionally shares it with the phones of the
/// network.
class DesktopEngineService extends GetxService {
  final HiveService hive;
  final Dio _dio;

  /// Where the engine is kept (tests use a temporary folder).
  final Directory? root;

  /// Where a release file downloads from (tests serve their own).
  final String Function(String asset) assetUrl;

  DesktopEngineService({
    HiveService? hive,
    Dio? dio,
    this.root,
    String Function(String asset)? assetUrl,
  })  : hive = hive ?? Get.find<HiveService>(),
        _dio = dio ?? Dio(),
        assetUrl = assetUrl ?? LlamaEngine.releaseUrl;

  /// Port the phones look for (llama.cpp's usual one).
  static const sharePort = 8080;

  // ── Installation ──
  final installedVariant = ''.obs;
  final installing = false.obs;
  final installProgress = 0.0.obs;
  final installStatus = ''.obs;
  final devices = <EngineDevice>[].obs;

  // ── Server ──
  final running = false.obs;
  final loadStatus = ''.obs;
  LlamaServerProcess? _server;
  LlamaServerProcess? get server => _server;

  /// The model runs for the phones of the network too.
  final sharing = false.obs;

  AppLogService? get _log =>
      Get.isRegistered<AppLogService>() ? Get.find<AppLogService>() : null;

  String get os => LlamaEngine.currentOs;
  bool get isArm => const ['arm64', 'aarch64']
      .any((a) => Platform.version.toLowerCase().contains(a));

  List<EngineVariant> get variants => LlamaEngine.variantsFor(os, arm: isArm);

  /// The build the user picked (the recommended one by default).
  EngineVariant get chosenVariant =>
      LlamaEngine.variant(
          os, hive.getSetting<String>(AppConstants.keyDesktopEngineVariant) ?? '',
          arm: isArm) ??
      variants.first;

  /// A llama-server the user installed themselves, instead of ours (the
  /// PRIVATELM_LLAMA_SERVER environment variable wins, for developers).
  String get customBinary =>
      Platform.environment['PRIVATELM_LLAMA_SERVER'] ??
      hive.getSetting<String>(AppConstants.keyDesktopServerPath) ??
      '';

  Future<Directory> _engineRoot() async =>
      root ?? Directory('${(await AppDirs.data()).path}/engine');

  Future<Directory> _variantDir(EngineVariant v) async =>
      Directory('${(await _engineRoot()).path}/${LlamaEngine.release}-${v.id}');

  Future<DesktopEngineService> init() async {
    sharing.value = hive.getSetting<bool>(AppConstants.keyDesktopShare) ?? false;
    final binary = await this.binary();
    installedVariant.value = binary == null
        ? ''
        : customBinary.isNotEmpty
            ? 'custom'
            : chosenVariant.id;
    await _killStaleServer();
    if (binary != null) unawaited(refreshDevices());
    return this;
  }

  /// The server program to run, or null when none is installed.
  Future<String?> binary() async {
    final custom = customBinary;
    if (custom.isNotEmpty) return await File(custom).exists() ? custom : null;
    final dir = await _variantDir(chosenVariant);
    if (!await dir.exists()) return null;
    return findBinary(dir, os);
  }

  /// The llama-server inside an extracted release (the archives put it at
  /// the top or in a sub-folder).
  static Future<String?> findBinary(Directory dir, String os) async {
    final name = LlamaEngine.binaryName(os);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && baseName(entity.path) == name) return entity.path;
    }
    return null;
  }

  /// Downloads and unpacks [variant]. Progress goes to [installProgress].
  Future<void> install(EngineVariant variant) async {
    if (installing.value) return;
    installing.value = true;
    installProgress.value = 0;
    installStatus.value =
        'Downloading the engine (@size MB)…'.trParams({'size': '${variant.downloadMb}'});
    final root = await _engineRoot();
    final target = await _variantDir(variant);
    final work = Directory('${target.path}.tmp');
    try {
      await root.create(recursive: true);
      if (await work.exists()) await work.delete(recursive: true);
      await work.create(recursive: true);
      final totalBytes = variant.downloadMb * 1024 * 1024;
      var doneBytes = 0;
      for (final asset in variant.assets) {
        final archive = '${work.path}/$asset';
        var assetBytes = 0;
        await _dio.download(
          assetUrl(asset),
          archive,
          onReceiveProgress: (received, total) {
            assetBytes = received;
            installProgress.value =
                ((doneBytes + received) / totalBytes).clamp(0.0, 0.95);
          },
        );
        doneBytes += assetBytes;
        installStatus.value = 'Unpacking the engine…'.tr;
        await extractFileToDisk(archive, '${work.path}/files');
        await File(archive).delete();
      }
      final found = await findBinary(Directory('${work.path}/files'), os);
      if (found == null) {
        throw Exception('llama-server was not found in the download.'.tr);
      }
      if (!Platform.isWindows) {
        await Process.run('chmod', ['-R', 'u+rwx', '${work.path}/files']);
      }
      if (await target.exists()) await target.delete(recursive: true);
      await work.rename(target.path);
      await hive.setSetting(AppConstants.keyDesktopEngineVariant, variant.id);
      await hive.setSetting(AppConstants.keyDesktopServerPath, '');
      installedVariant.value = variant.id;
      installProgress.value = 1;
      installStatus.value = '';
      await refreshDevices();
    } catch (e) {
      installStatus.value = '';
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
      _log?.error('Engine install failed', details: e);
      rethrow;
    } finally {
      installing.value = false;
    }
  }

  /// Uses a llama-server the user already has (e.g. a CUDA build).
  Future<void> useCustomBinary(String path) async {
    await hive.setSetting(AppConstants.keyDesktopServerPath, path);
    installedVariant.value = path.isEmpty ? '' : 'custom';
    if (path.isNotEmpty) await refreshDevices();
  }

  /// Picks a build already downloaded, or forgets the custom one.
  Future<void> chooseVariant(EngineVariant variant) async {
    await hive.setSetting(AppConstants.keyDesktopEngineVariant, variant.id);
    await hive.setSetting(AppConstants.keyDesktopServerPath, '');
    installedVariant.value = await binary() == null ? '' : variant.id;
    if (installedVariant.value.isNotEmpty) await refreshDevices();
  }

  /// Asks the engine which graphics cards it sees.
  Future<void> refreshDevices() async {
    final bin = await binary();
    if (bin == null) return;
    try {
      final result = await Process.run(bin, ['--list-devices'],
              workingDirectory: File(bin).parent.path)
          .timeout(const Duration(seconds: 20));
      devices.assignAll(
          LlamaEngine.parseDevices('${result.stdout}\n${result.stderr}'));
      // Model advice counts a separate card's memory.
      if (Get.isRegistered<DeviceInfoService>()) {
        final gpu = mainGpu;
        Get.find<DeviceInfoService>().graphicsMemoryGB.value =
            gpu != null && isDiscreteGpu(gpu.name) ? gpu.totalMb / 1024 : 0;
      }
    } catch (e) {
      _log?.warning('Engine devices not listed', details: e);
    }
  }

  /// The best graphics card, if any.
  EngineDevice? get mainGpu {
    final local = devices.where((d) => !d.isRemote).toList()
      ..sort((a, b) => b.totalMb.compareTo(a.totalMb));
    return local.firstOrNull;
  }

  // ── Running a model ──

  /// The key phones need while the model is shared.
  Future<String> shareKey() async {
    var key = hive.getSetting<String>(AppConstants.keyDesktopShareKey) ?? '';
    if (key.isEmpty) {
      key = newKey();
      await hive.setSetting(AppConstants.keyDesktopShareKey, key);
    }
    return key;
  }

  static String newKey() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Port of a phone in Worker mode (and of ggml-rpc-server).
  static const workerPort = 50052;

  /// Phones (or computers) known to lend their memory: host:port.
  List<String> get savedWorkers => [
        for (final w in hive.getSetting<List>(AppConstants.keyDesktopRpcWorkers) ??
            const [])
          '$w',
      ];

  Future<void> saveWorkers(List<String> workers) =>
      hive.setSetting(AppConstants.keyDesktopRpcWorkers, workers);

  bool get clusterOn =>
      hive.getSetting<bool>(AppConstants.keyDesktopClusterOn) ?? false;

  Future<void> setClusterOn(bool on) =>
      hive.setSetting(AppConstants.keyDesktopClusterOn, on);

  /// Phones lending their memory (host:port), when the cluster is on.
  List<String> get rpcWorkers => clusterOn ? savedWorkers : const [];

  /// "192.168.1.20" or "192.168.1.20:50052" → "192.168.1.20:50052".
  static String? workerEndpoint(String input) {
    final text = input.trim();
    final m = RegExp(r'^([A-Za-z0-9.\-]+)(?::(\d{1,5}))?$').firstMatch(text);
    if (m == null) return null;
    final port = int.tryParse(m[2] ?? '') ?? workerPort;
    if (port < 1 || port > 65535) return null;
    return '${m[1]}:$port';
  }

  /// Asks a worker for its memory; null when it doesn't answer.
  static Future<RpcServerInfo?> probeWorker(String endpoint) async {
    final i = endpoint.lastIndexOf(':');
    try {
      return await RpcProbe.query(
          endpoint.substring(0, i), int.parse(endpoint.substring(i + 1)));
    } catch (_) {
      return null;
    }
  }

  /// Phones of this network in Worker mode.
  static Future<List<(String, RpcServerInfo)>> scanWorkers(
      {void Function(double progress)? onProgress}) async {
    final own = await LanServerFinder.ownAddress();
    if (own == null) return const [];
    final hosts = LanServerFinder.neighbours(own);
    final found = <(String, RpcServerInfo)>[];
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (next < hosts.length) {
        final host = hosts[next++];
        try {
          final socket = await Socket.connect(host, workerPort,
              timeout: const Duration(milliseconds: 400));
          socket.destroy();
          final info = await probeWorker('$host:$workerPort');
          if (info != null) found.add(('$host:$workerPort', info));
        } catch (_) {}
        onProgress?.call(++done / hosts.length);
      }
    }

    await Future.wait([for (var i = 0; i < 48; i++) worker()]);
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return found;
  }

  /// This computer's addresses on the local network (for the phones).
  static Future<List<String>> localAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final i in interfaces)
          for (final a in i.addresses)
            if (LanServerFinder.isLocal('http://${a.address}')) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Starts llama-server with [modelPath]. Stops the one running first.
  Future<LlamaServerProcess> start({
    required String modelPath,
    required String alias,
    required int contextSize,
    required bool useGpu,
    int? threads,
    String? mmprojPath,
    String? draftPath,
    void Function(double progress)? onProgress,
  }) async {
    await stop();
    final bin = await binary();
    if (bin == null) throw EngineStartException('ENGINE_MISSING');
    final share = sharing.value;
    final config = ServerConfig(
      modelPath: modelPath,
      host: share ? '0.0.0.0' : '127.0.0.1',
      port: share ? sharePort : await LlamaServerProcess.freePort(),
      // Locally too: another program on the computer can't use it.
      apiKey: share ? await shareKey() : newKey(),
      alias: alias,
      contextSize: contextSize,
      useGpu: useGpu,
      threads: threads,
      mmprojPath: mmprojPath,
      draftPath: draftPath,
      rpc: rpcWorkers,
    );
    final log = _log;
    log?.info('[Engine] ${LlamaEngine.serverArgs(config).where((a) => a != config.apiKey).join(' ')}');
    onProgress?.call(0.05);
    loadStatus.value = 'Starting the engine…'.tr;
    final server = await LlamaServerProcess.start(
      bin,
      config,
      onStage: (stage) {
        switch (stage) {
          case LoadStage.weights:
            loadStatus.value = 'Loading the model…'.tr;
            onProgress?.call(0.3);
          case LoadStage.context:
            loadStatus.value = 'Preparing the memory…'.tr;
            onProgress?.call(0.8);
          case LoadStage.ready:
            onProgress?.call(0.98);
        }
      },
    );
    await _rememberPid(server.process.pid);
    _server = server;
    running.value = true;
    loadStatus.value = '';
    server.process.exitCode.then((code) {
      if (identical(_server, server)) {
        _server = null;
        running.value = false;
        log?.warning('[Engine] llama-server stopped (code $code)',
            details: server.log.reversed.take(20).toList().reversed.join('\n'));
      }
    });
    return server;
  }

  /// A client for the running server; null when no model is loaded.
  OpenAiChatClient? client({Duration idle = const Duration(minutes: 5)}) {
    final s = _server;
    if (s == null || s.exited) return null;
    return OpenAiChatClient(
      baseUrl: s.baseUrl,
      apiKey: s.config.apiKey,
      model: s.config.alias,
      idleTimeout: idle,
      connectTimeout: const Duration(minutes: 10),
    );
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    running.value = false;
    if (s != null) await s.stop();
    await _forgetPid();
  }

  /// Shares the model with the phones of the network (or stops). Takes
  /// effect when the model is next loaded.
  Future<void> setSharing(bool on) async {
    sharing.value = on;
    await hive.setSetting(AppConstants.keyDesktopShare, on);
  }

  // A server left running by a crash of the app holds the graphics memory.
  Future<File> _pidFile() async => File('${(await _engineRoot()).path}/server.pid');

  Future<void> _rememberPid(int pid) async {
    final f = await _pidFile();
    await f.parent.create(recursive: true);
    await f.writeAsString('$pid');
  }

  Future<void> _forgetPid() async {
    final f = await _pidFile();
    if (await f.exists()) await f.delete();
  }

  Future<void> _killStaleServer() async {
    try {
      final f = await _pidFile();
      if (!await f.exists()) return;
      final pid = int.tryParse((await f.readAsString()).trim());
      await f.delete();
      if (pid == null || !await _isLlamaServer(pid)) return;
      Process.killPid(pid);
      _log?.info('[Engine] Stopped a server left running ($pid)');
    } catch (_) {}
  }

  static Future<bool> _isLlamaServer(int pid) async {
    if (Platform.isLinux) {
      final cmdline = File('/proc/$pid/cmdline');
      return await cmdline.exists() &&
          (await cmdline.readAsString()).contains('llama-server');
    }
    final result = Platform.isWindows
        ? await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH'])
        : await Process.run('ps', ['-p', '$pid', '-o', 'comm=']);
    return '${result.stdout}'.contains('llama-server');
  }

  @override
  void onClose() {
    unawaited(stop());
    super.onClose();
  }
}

/// Encodes an image file for a chat message.
Future<String> imageDataUri(String path) async {
  final bytes = await File(path).readAsBytes();
  final lower = path.toLowerCase();
  final mime = lower.endsWith('.png')
      ? 'image/png'
      : lower.endsWith('.webp')
          ? 'image/webp'
          : lower.endsWith('.gif')
              ? 'image/gif'
              : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
