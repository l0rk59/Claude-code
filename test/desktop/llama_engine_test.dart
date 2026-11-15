import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/desktop/llama_engine.dart';

void main() {
  group('release files', () {
    test('Windows: Vulkan first, then CUDA (with its runtime), then CPU', () {
      final v = LlamaEngine.variantsFor('windows');
      expect(v.map((e) => e.id), ['vulkan', 'cuda', 'cpu']);
      expect(v[0].assets, ['llama-b11157-bin-win-vulkan-x64.zip']);
      expect(v[1].assets, [
        'llama-b11157-bin-win-cuda-12.4-x64.zip',
        'cudart-llama-bin-win-cuda-12.4-x64.zip',
      ]);
      expect(v[2].assets, ['llama-b11157-bin-win-cpu-x64.zip']);
    });

    test('Windows on ARM has no CUDA build', () {
      final v = LlamaEngine.variantsFor('windows', arm: true);
      expect(v.map((e) => e.id), ['vulkan', 'cpu']);
      expect(v.first.assets.single, 'llama-b11157-bin-win-vulkan-arm64.zip');
    });

    test('Linux and macOS', () {
      expect(LlamaEngine.variantsFor('linux').map((e) => e.assets.single), [
        'llama-b11157-bin-ubuntu-vulkan-x64.tar.gz',
        'llama-b11157-bin-ubuntu-x64.tar.gz',
      ]);
      expect(LlamaEngine.variantsFor('macos', arm: true).single.assets.single,
          'llama-b11157-bin-macos-arm64.tar.gz');
      expect(LlamaEngine.releaseUrl('a.zip'),
          'https://github.com/ggml-org/llama.cpp/releases/download/b11157/a.zip');
      expect(LlamaEngine.binaryName('windows'), 'llama-server.exe');
      expect(LlamaEngine.binaryName('linux'), 'llama-server');
    });
  });

  group('command line', () {
    test('local use: loopback, one slot, key, no web page', () {
      final args = LlamaEngine.serverArgs(const ServerConfig(
        modelPath: '/m/qwen.gguf',
        port: 41000,
        apiKey: 'secret',
        alias: 'qwen',
        contextSize: 16384,
      ));
      expect(args.join(' '),
          '-m /m/qwen.gguf --host 127.0.0.1 --port 41000 --api-key secret '
          '--alias qwen -c 16384 -np 1 --no-webui');
    });

    test('shared, on the processor, with vision, draft and phones', () {
      final args = LlamaEngine.serverArgs(const ServerConfig(
        modelPath: 'C:\\m\\big.gguf',
        host: '0.0.0.0',
        port: 8080,
        apiKey: 'k',
        useGpu: false,
        threads: 8,
        mmprojPath: 'C:\\m\\mmproj.gguf',
        draftPath: 'C:\\m\\small.gguf',
        rpc: ['192.168.1.20:50052', '192.168.1.21:50052'],
      ));
      expect(args, containsAllInOrder(['--host', '0.0.0.0', '--port', '8080']));
      expect(args, containsAllInOrder(['-np', '2']));
      expect(args, containsAllInOrder(['-ngl', '0']));
      expect(args, containsAllInOrder(['-t', '8']));
      expect(args, containsAllInOrder(['--mmproj', 'C:\\m\\mmproj.gguf']));
      expect(args, containsAllInOrder(['-md', 'C:\\m\\small.gguf']));
      expect(args,
          containsAllInOrder(['--rpc', '192.168.1.20:50052,192.168.1.21:50052']));
      expect(args, isNot(contains('-c')));
    });
  });

  group('reading the log', () {
    test('load stages', () {
      expect(LlamaEngine.stageOf('load_tensors: loading model tensors'),
          LoadStage.weights);
      expect(LlamaEngine.stageOf('llama_context: n_ctx = 4096'), LoadStage.context);
      expect(
          LlamaEngine.stageOf(
              'main: server is listening on http://127.0.0.1:8080 - starting the main loop'),
          LoadStage.ready);
      expect(LlamaEngine.stageOf('random line'), isNull);
    });

    test('layers on the graphics card', () {
      expect(
          LlamaEngine.offloadedLayers('load_tensors: offloaded 29/37 layers to GPU'),
          (29, 37));
      expect(LlamaEngine.offloadedLayers('nothing'), isNull);
    });

    test('graphics cards from --list-devices', () {
      final devices = LlamaEngine.parseDevices('''
ggml_vulkan: Found 1 Vulkan devices:
Available devices:
  Vulkan0: NVIDIA GeForce RTX 3060 (12288 MiB, 11203 MiB free)
  RPC0: 192.168.1.20:50052 (11000 MiB, 10500 MiB free)
''');
      expect(devices, hasLength(2));
      expect(devices[0].name, 'NVIDIA GeForce RTX 3060');
      expect(devices[0].totalMb, 12288);
      expect(devices[0].freeMb, 11203);
      expect(devices[0].isRemote, isFalse);
      expect(devices[1].isRemote, isTrue);
    });

    test('reasons for a failed start', () {
      expect(
          LlamaEngine.failureReason(
              ['llama_model_load: error loading model: unknown model architecture: \'foo\'']),
          contains("doesn't know this type"));
      expect(
          LlamaEngine.failureReason(
              ['ggml_vulkan: Device memory allocation failed: ErrorOutOfDeviceMemory']),
          contains('Not enough memory'));
      expect(
          LlamaEngine.failureReason(
              ['couldn\'t bind HTTP server socket, hostname: 0.0.0.0, port: 8080']),
          contains('port'));
      expect(
          LlamaEngine.failureReason(
              ['llama_model_load: error loading model: failed to load model']),
          contains("couldn't be read"));
      expect(LlamaEngine.failureReason(['', 'last words', '']), 'last words');
    });
  });
}
