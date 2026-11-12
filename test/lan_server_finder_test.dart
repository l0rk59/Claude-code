import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/lan_server_finder.dart';

/// A stand-in model server answering `/v1/models`.
Future<HttpServer> _serve(Object answer, {int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode =
        request.uri.path == '/v1/models' ? status : 404;
    request.response.headers.contentType = ContentType.json;
    request.response.write(answer is String ? answer : jsonEncode(answer));
    await request.response.close();
  });
  return server;
}

Map<String, Object> _models(List<String> ids, String owner) => {
      'object': 'list',
      'data': [
        for (final id in ids) {'id': id, 'object': 'model', 'owned_by': owner},
      ],
    };

void main() {
  test('recognises llama.cpp, Ollama and LM Studio', () {
    LanServer parse(String owner, {int port = 9999}) => LanServerFinder.parse(
        '192.168.1.20', port, jsonEncode(_models(['m'], owner)))!;
    expect(parse('llamacpp').software, 'llama.cpp');
    expect(parse('library').software, 'Ollama');
    expect(parse('organization_owner').software, 'LM Studio');
    // An unknown program is named after the port it uses, if that says so.
    expect(parse('someone', port: 11434).software, 'Ollama');
    expect(parse('someone').software, '');
  });

  test('reads the models a server offers', () async {
    final server = await _serve(
        _models(['Qwen3.5-35B-A3B-Q4_K_M.gguf', 'other'], 'llamacpp'));
    addTearDown(() => server.close(force: true));
    final found = await LanServerFinder.probe('127.0.0.1', server.port);
    expect(found!.models, ['Qwen3.5-35B-A3B-Q4_K_M.gguf', 'other']);
    expect(found.software, 'llama.cpp');
    expect(found.baseUrl, 'http://127.0.0.1:${server.port}/v1');
    expect(found.address, '127.0.0.1:${server.port}');
  });

  test('ignores what is not a model server', () async {
    final web = await _serve('<html>router</html>');
    addTearDown(() => web.close(force: true));
    expect(await LanServerFinder.probe('127.0.0.1', web.port), isNull);

    final locked = await _serve({'error': 'key required'}, status: 401);
    addTearDown(() => locked.close(force: true));
    expect(await LanServerFinder.probe('127.0.0.1', locked.port), isNull);

    final other = await _serve({'data': 'not a list'});
    addTearDown(() => other.close(force: true));
    expect(await LanServerFinder.probe('127.0.0.1', other.port), isNull);

    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    expect(await LanServerFinder.probe('127.0.0.1', port), isNull);
  });

  test('scans addresses and ports, keeping only the servers', () async {
    final server = await _serve(_models(['big-model'], 'llamacpp'));
    addTearDown(() => server.close(force: true));
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = closed.port;
    await closed.close();

    final progress = <double>[];
    final found = await LanServerFinder.scan(
      ['127.0.0.1'],
      ports: [deadPort, server.port],
      onProgress: progress.add,
    );
    expect(found.single.address, '127.0.0.1:${server.port}');
    expect(found.single.models, ['big-model']);
    expect(progress.last, 1.0);
  });

  test('a cancelled scan stops asking', () async {
    final found = await LanServerFinder.scan(
      LanServerFinder.neighbours('192.168.1.42'),
      cancelled: () => true,
    );
    expect(found, isEmpty);
  });

  test('lists the other addresses of a home network', () {
    final others = LanServerFinder.neighbours('192.168.1.42');
    expect(others, hasLength(253));
    expect(others.first, '192.168.1.1');
    expect(others.last, '192.168.1.254');
    expect(others, isNot(contains('192.168.1.42')));
    expect(LanServerFinder.neighbours('not an address'), isEmpty);
    expect(LanServerFinder.neighbours('fe80::1'), isEmpty);
  });

  test('tells a computer at home from a server on the Internet', () {
    for (final url in [
      'http://192.168.1.20:8080/v1',
      'http://10.0.0.5:11434/v1',
      'http://172.16.4.2:1234/v1',
      'http://172.31.255.1/v1',
      'http://localhost:8080/v1',
      'http://127.0.0.1:8080/v1',
      'http://mon-pc.local:8080/v1',
    ]) {
      expect(LanServerFinder.isLocal(url), isTrue, reason: url);
    }
    for (final url in [
      'https://api.openai.com/v1',
      'https://openrouter.ai/api/v1',
      'http://172.32.0.1/v1',
      'http://8.8.8.8/v1',
      'http://192.168.example.com/v1',
      '',
      'not a url',
    ]) {
      expect(LanServerFinder.isLocal(url), isFalse, reason: url);
    }
  });

  test('tries what the user typed', () async {
    final server = await _serve(_models(['m'], 'library'));
    addTearDown(() => server.close(force: true));
    final exact = await LanServerFinder.find('127.0.0.1:${server.port}');
    expect(exact.single.software, 'Ollama');
    // A pasted URL works too.
    final pasted =
        await LanServerFinder.find('http://127.0.0.1:${server.port}/v1/');
    expect(pasted.single.port, server.port);
    expect(await LanServerFinder.find(''), isEmpty);
    expect(await LanServerFinder.find('my laptop'), isEmpty);
    expect(await LanServerFinder.find('127.0.0.1:abc'), isEmpty);
  });
}
