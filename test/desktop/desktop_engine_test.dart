import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/services/desktop/desktop_engine_service.dart';
import 'package:privatelm/services/desktop/desktop_inference.dart';
import 'package:privatelm/services/desktop/llama_engine.dart';
import 'package:privatelm/services/desktop/llama_server_process.dart';
import 'package:privatelm/services/hive_service.dart';

/// The stand-in llama-server (Python), or null where it can't run.
String? _fakeServer() {
  if (Platform.isWindows) return null;
  final python = Process.runSync('which', ['python3']);
  if (python.exitCode != 0) return null;
  return File('test/support/fake_llama_server.py').absolute.path;
}

void main() {
  final fake = _fakeServer();
  late Directory dir;
  late HiveService hive;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('desktop_engine');
    Hive.init('${dir.path}/hive');
    hive = await HiveService().init();
    Get.testMode = true;
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('installs a release: downloads, unpacks, finds the server, makes it runnable',
      () async {
    // A release archive like llama.cpp's: a folder with the program and a
    // library link.
    final archive = Archive()
      ..add(ArchiveFile.bytes('llama-b11157/llama-server',
          File('test/support/fake_llama_server.py').readAsBytesSync())
        ..mode = 0x1ed)
      ..add(ArchiveFile.bytes('llama-b11157/libllama.so.0', [1, 2, 3]))
      ..add(ArchiveFile.symlink('llama-b11157/libllama.so', 'libllama.so.0'));
    final tarGz =
        const GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    final asked = <String>[];
    http.listen((req) async {
      asked.add(req.uri.path);
      req.response.add(tarGz);
      await req.response.close();
    });

    final engine = DesktopEngineService(
      hive: hive,
      root: Directory('${dir.path}/engine'),
      assetUrl: (asset) => 'http://127.0.0.1:${http.port}/$asset',
    );
    expect(await engine.binary(), isNull);
    final variant = engine.variants.firstWhere((v) => v.assets.length == 1);
    await engine.install(variant);

    expect(asked, ['/${variant.assets.single}']);
    final bin = await engine.binary();
    expect(bin, isNotNull);
    expect(bin, endsWith(LlamaEngine.binaryName(engine.os)));
    expect(engine.installedVariant.value, variant.id);
    expect(engine.installProgress.value, 1);
    expect(hive.getSetting<String>(AppConstants.keyDesktopEngineVariant),
        variant.id);
    if (!Platform.isWindows) {
      final mode = (await File(bin!).stat()).mode;
      expect(mode & 0x40, isNot(0), reason: 'owner can run it');
      expect(
          await Link('${File(bin).parent.path}/libllama.so').target(),
          'libllama.so.0');
    }
    // Nothing is left half-installed.
    expect(Directory('${dir.path}/engine').listSync().map((e) => e.path),
        everyElement(isNot(endsWith('.tmp'))));
  }, skip: fake == null ? 'python3 needed' : false);

  test('a failed download leaves nothing installed', () async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    http.listen((req) async {
      req.response.statusCode = 404;
      await req.response.close();
    });
    final engine = DesktopEngineService(
      hive: hive,
      root: Directory('${dir.path}/engine'),
      assetUrl: (asset) => 'http://127.0.0.1:${http.port}/$asset',
    );
    await expectLater(engine.install(engine.variants.first), throwsA(anything));
    expect(await engine.binary(), isNull);
    expect(engine.installing.value, isFalse);
  });

  group('with the stand-in llama-server', () {
    late DesktopEngineService engine;
    late File model;

    setUp(() async {
      engine = DesktopEngineService(hive: hive, root: Directory('${dir.path}/engine'));
      await engine.useCustomBinary(fake!);
      model = File('${dir.path}/models/qwen3.5-4b-q4_k_m.gguf')
        ..createSync(recursive: true)
        ..writeAsStringSync('GGUF');
    });

    tearDown(() => engine.stop());

    test('lists the graphics cards', () async {
      await engine.refreshDevices();
      expect(engine.mainGpu?.name, 'Fake GPU 9000');
      expect(engine.mainGpu?.totalMb, 12288);
    });

    test('loads, chats with thinking in <think> tags, counts the context',
        () async {
      final inference = DesktopInference(engine);
      final progress = <double>[];
      final load = await inference.loadModel(
        modelPath: model.path,
        contextSize: 8192,
        onProgress: progress.add,
      );
      expect(load.success, isTrue, reason: load.message);
      expect(load.backend, 'gpu');
      expect(load.gpuLayers, 29);
      expect(load.gpuName, 'Fake GPU 9000');
      expect(progress.last, greaterThan(0.9));
      expect(engine.running.value, isTrue);
      expect(engine.server!.config.host, '127.0.0.1');
      expect(engine.server!.config.apiKey, isNotEmpty,
          reason: 'other programs of the computer cannot use it');
      expect(engine.server!.contextSize, 8192);

      final tokens = <String>[];
      final answer = await inference.generate(
        prompt: 'Bonjour',
        systemPrompt: 'Be brief.',
        conversationHistory: const [
          {'role': 'user', 'content': 'Earlier'},
          {'role': 'assistant', 'content': 'Yes'},
          {'role': 'user', 'content': 'Bonjour'},
        ],
        modelName: 'qwen3.5-4b',
        maxTokens: 100,
        temperature: 0.3,
        onToken: tokens.add,
      );
      expect(answer, startsWith('<think>Thinking briefly.</think>'));
      expect(answer, contains('Echo from qwen3.5-4b-q4_k_m: Bonjour'));
      expect(tokens.join(), answer);
      expect(inference.contextInfo(), (52, 8192));

      await inference.dispose();
      expect(engine.running.value, isFalse);
    });

    test('on the processor only: no layers on the graphics card', () async {
      final inference = DesktopInference(engine);
      final load = await inference.loadModel(
          modelPath: model.path, contextSize: 4096, useGpu: false);
      expect(load.success, isTrue);
      expect(load.backend, 'cpu');
      expect(engine.server!.config.useGpu, isFalse);
    });

    test('shared with the phones: every address, fixed port, saved key',
        () async {
      await engine.setSharing(true);
      final key = await engine.shareKey();
      expect(key, hasLength(20));
      final server = await engine.start(
          modelPath: model.path, alias: 'qwen', contextSize: 4096, useGpu: true);
      expect(server.config.host, '0.0.0.0');
      expect(server.config.port, DesktopEngineService.sharePort);
      expect(server.config.apiKey, key);
      expect(await engine.shareKey(), key, reason: 'the phones keep working');
    });

    test('a model that cannot load gives a clear reason', () async {
      final inference = DesktopInference(engine);
      final load = await inference.loadModel(
          modelPath: '${dir.path}/missing.gguf', contextSize: 4096);
      expect(load.success, isFalse);
      expect(load.message, contains("couldn't be read"));
      expect(engine.running.value, isFalse);
    });

    test('LiteRT models are refused on the computer', () async {
      final load = await DesktopInference(engine)
          .loadModel(modelPath: '${dir.path}/gemma.litertlm', contextSize: 4096);
      expect(load.success, isFalse);
      expect(load.message, contains('LiteRT'));
    });

    test('loading again replaces the running server', () async {
      final first = await engine.start(
          modelPath: model.path, alias: 'a', contextSize: 2048, useGpu: true);
      final second = await engine.start(
          modelPath: model.path, alias: 'b', contextSize: 2048, useGpu: true);
      expect(first.exited || await first.process.exitCode
          .timeout(const Duration(seconds: 5), onTimeout: () => -999) != -999,
          isTrue);
      expect(engine.server, same(second));
    });
  }, skip: fake == null ? 'python3 needed' : false);

  test('the stand-in stops while loading: the start fails with its reason',
      () async {
    final port = await LlamaServerProcess.freePort();
    final env = Map.of(Platform.environment)..['FAKE_LLAMA_FAIL'] = '1';
    // Through a wrapper so the variable reaches the program.
    final wrapper = File('${dir.path}/failing-server')
      ..writeAsStringSync('#!/bin/sh\nFAKE_LLAMA_FAIL=1 exec "$fake" "\$@"\n');
    await Process.run('chmod', ['+x', wrapper.path], environment: env);
    await expectLater(
      LlamaServerProcess.start(
          wrapper.path, ServerConfig(modelPath: 'x.gguf', port: port)),
      throwsA(isA<EngineStartException>().having(
          (e) => e.message, 'message', contains("couldn't be read"))),
    );
  }, skip: fake == null ? 'python3 needed' : false);
}

