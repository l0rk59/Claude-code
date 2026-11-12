import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/rpc_probe.dart';

import 'support/fake_rpc_server.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  test('reads the version and each device\'s memory', () async {
    final server = await serveFakeRpc(devices: [
      (free: 6 * _gb, total: 8 * _gb),
      (free: 16 * _gb, total: 16 * _gb),
    ]);
    addTearDown(server.close);
    final info = await RpcProbe.query('127.0.0.1', server.port);
    expect(info.version, '7.0.3');
    expect(info.compatible, isTrue);
    expect(info.devices, [
      (free: 6 * _gb, total: 8 * _gb),
      (free: 16 * _gb, total: 16 * _gb),
    ]);
    expect(info.totalMb, 24 * 1024);
  });

  test('suggests what a computer can really give', () {
    // Measured free memory (Windows, or a graphics card): 85% of it.
    const measured = RpcServerInfo(
        major: 7, minor: 0, patch: 0, devices: [(free: 10 * _gb, total: 16 * _gb)]);
    expect(measured.suggestedMb, (10 * 1024 * 0.85).floor());
    // "Everything is free" (Linux and macOS processors): 60% of the total.
    const unmeasured = RpcServerInfo(
        major: 7, minor: 0, patch: 0, devices: [(free: 16 * _gb, total: 16 * _gb)]);
    expect(unmeasured.suggestedMb, (16 * 1024 * 0.6).floor());
  });

  test('stops at an incompatible version', () async {
    final server = await serveFakeRpc(major: 6, devices: [(free: _gb, total: _gb)]);
    addTearDown(server.close);
    final info = await RpcProbe.query('127.0.0.1', server.port);
    expect(info.compatible, isFalse);
    expect(info.version, '6.0.3');
    expect(info.devices, isEmpty);
  });

  test('a newer minor version is not usable either', () {
    const newer = RpcServerInfo(major: 7, minor: 1, patch: 0);
    expect(newer.compatible, isFalse);
  });

  test('nothing listening is a connection error', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    expect(RpcProbe.query('127.0.0.1', port),
        throwsA(isA<SocketException>()));
  });

  test('a server that stays silent times out', () async {
    final server = await serveFakeRpc(silent: true);
    addTearDown(server.close);
    expect(
        RpcProbe.query('127.0.0.1', server.port,
            timeout: const Duration(milliseconds: 300)),
        throwsA(isA<TimeoutException>()));
  });

  test('something that is not an RPC server is rejected', () async {
    final server =
        await serveFakeRpc(garbage: 'HTTP/1.1 400 Bad Request\r\n\r\n'.codeUnits);
    addTearDown(server.close);
    expect(RpcProbe.query('127.0.0.1', server.port),
        throwsA(isA<FormatException>()));
  });

  test('the protocol numbers match the bundled llama.cpp', () {
    const root = 'local_plugins/llama_flutter_android/android/src/main/cpp/'
        'llama.cpp/ggml';
    int define(String file, String name) => int.parse(
        RegExp('$name\\s*=?\\s*(\\d+)')
            .firstMatch(File('$root/$file').readAsStringSync())![1]!);
    expect(RpcProbe.protocolMajor,
        define('include/ggml-rpc.h', 'RPC_PROTO_MAJOR_VERSION'));
    expect(RpcProbe.protocolMinor,
        define('include/ggml-rpc.h', 'RPC_PROTO_MINOR_VERSION'));
    expect(RpcProbe.capsSize,
        define('src/ggml-rpc/transport.h', 'RPC_CONN_CAPS_SIZE'));

    // Commands are numbered by their place in the enum.
    final source = File('$root/src/ggml-rpc/ggml-rpc.cpp').readAsStringSync();
    final body =
        RegExp(r'enum rpc_cmd \{(.*?)\};', dotAll: true).firstMatch(source)![1]!;
    final commands = RegExp(r'RPC_CMD_\w+')
        .allMatches(body)
        .map((m) => m[0]!)
        .toList();
    expect(commands.indexOf('RPC_CMD_HELLO'), RpcProbe.cmdHello);
    expect(commands.indexOf('RPC_CMD_DEVICE_COUNT'), RpcProbe.cmdDeviceCount);
    expect(commands.indexOf('RPC_CMD_GET_DEVICE_MEMORY'),
        RpcProbe.cmdGetDeviceMemory);
  });

  // Against the real thing: a server built from the engine's own sources.
  // RPC_TEST_ENDPOINT=127.0.0.1:50052 flutter test test/rpc_probe_test.dart
  final live = Platform.environment['RPC_TEST_ENDPOINT'];
  test('talks to a real llama.cpp RPC server', () async {
    final parts = live!.split(':');
    final info = await RpcProbe.query(parts[0], int.parse(parts[1]));
    expect(info.compatible, isTrue);
    expect(info.devices, isNotEmpty);
    expect(info.devices.first.total, greaterThan(_gb ~/ 2));
    // ignore: avoid_print
    print('real server: v${info.version}, ${info.devices}');
  }, skip: live == null ? 'set RPC_TEST_ENDPOINT to run' : false);
}
