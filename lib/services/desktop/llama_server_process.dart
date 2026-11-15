import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'llama_engine.dart';

/// One running llama-server: started, watched until it answers, stopped.
class LlamaServerProcess {
  final Process process;
  final ServerConfig config;

  /// The end of what the server printed (for error messages and the log).
  final List<String> log = [];
  static const _logLines = 300;

  /// Layers on the graphics card, from the server's log: (on GPU, total).
  (int, int)? offloaded;

  /// Context the server really uses (it can shrink it to fit in memory).
  int contextSize = 0;

  bool _exited = false;
  int? exitCode;

  LlamaServerProcess._(this.process, this.config) {
    process.exitCode.then((code) {
      _exited = true;
      exitCode = code;
    });
  }

  bool get exited => _exited;

  /// Where the app talks to it (always through the loopback, even when it
  /// is shared with the network).
  String get baseUrl => 'http://127.0.0.1:${config.port}/v1';

  /// A free port on this computer.
  static Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// Starts [binary] with [config]. [onStage] follows the load; the future
  /// completes once the server answers, or throws [EngineStartException]
  /// with a reason when it stops or takes longer than [timeout].
  static Future<LlamaServerProcess> start(
    String binary,
    ServerConfig config, {
    void Function(LoadStage stage)? onStage,
    void Function(String line)? onLine,
    Duration timeout = const Duration(minutes: 20),
    http.Client? client,
  }) async {
    final process = await Process.start(
      binary,
      LlamaEngine.serverArgs(config),
      workingDirectory: File(binary).parent.path,
    );
    final server = LlamaServerProcess._(process, config);
    void listen(Stream<List<int>> stream) {
      stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
        server.log.add(line);
        if (server.log.length > _logLines) server.log.removeAt(0);
        server.offloaded = LlamaEngine.offloadedLayers(line) ?? server.offloaded;
        final stage = LlamaEngine.stageOf(line);
        if (stage != null) onStage?.call(stage);
        onLine?.call(line);
      });
    }

    listen(process.stdout);
    listen(process.stderr);
    try {
      await server._waitReady(timeout, client ?? http.Client());
    } catch (_) {
      await server.stop();
      rethrow;
    }
    return server;
  }

  Future<void> _waitReady(Duration timeout, http.Client client) async {
    final deadline = DateTime.now().add(timeout);
    final health = Uri.parse('http://127.0.0.1:${config.port}/health');
    try {
      while (true) {
        if (_exited) {
          // Let the last lines of the log arrive.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          throw EngineStartException(LlamaEngine.failureReason(log), log);
        }
        if (DateTime.now().isAfter(deadline)) {
          throw EngineStartException('The engine took too long to start.'.tr, log);
        }
        try {
          final response =
              await client.get(health).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) break;
        } catch (_) {
          // Not listening yet.
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      contextSize = await _readContextSize(client);
    } finally {
      client.close();
    }
  }

  Future<int> _readContextSize(http.Client client) async {
    try {
      final response = await client.get(
        Uri.parse('http://127.0.0.1:${config.port}/props'),
        headers: {
          if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
        },
      ).timeout(const Duration(seconds: 3));
      final data = jsonDecode(response.body);
      final settings = data is Map ? data['default_generation_settings'] : null;
      final n = settings is Map ? settings['n_ctx'] : null;
      if (n is num && n > 0) return n.toInt();
    } catch (_) {}
    return config.contextSize;
  }

  /// Stops the server and frees its memory.
  Future<void> stop() async {
    if (_exited) return;
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

class EngineStartException implements Exception {
  final String message;
  final List<String> log;
  EngineStartException(this.message, [this.log = const []]);
  @override
  String toString() => message;
}
