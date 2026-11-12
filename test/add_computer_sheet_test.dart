import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/core/constants.dart';
import 'package:privatelm/core/ui.dart';
import 'package:privatelm/services/app_log_service.dart';
import 'package:privatelm/services/cluster_service.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/views/cluster_view.dart';

import 'support/fake_rpc_server.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  late Directory dir;
  late ClusterService cluster;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('cluster_test');
    Hive.init(dir.path);
    Get.put(await HiveService().init());
    Get.put(AppLogService());
    // The platform side only confirms that the address accepts connections.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('llama_flutter_android/cluster'),
            (call) async => call.method == 'probe' ? true : null);
    cluster = ClusterService();
  });

  tearDown(() async {
    Get.reset();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('asks a computer what it offers, then adds it with the chosen memory',
      () async {
    final server =
        await serveFakeRpc(devices: [(free: 10 * _gb, total: 16 * _gb)]);
    addTearDown(server.close);
    final address = '127.0.0.1:${server.port}';

    final answer = await cluster.inspectComputer(address);
    expect(answer.error, isNull);
    expect(answer.info!.totalMb, 16 * 1024);
    // 85% of the 10 GB measured free.
    expect(answer.info!.suggestedMb, 8704);

    expect(await cluster.addComputer(address, memoryMb: 12800), isNull);
    final added = cluster.workers.single;
    expect(added.computer, isTrue);
    expect(added.endpoint, address);
    expect(ClusterService.capacityMb(added), 12800);

    // Kept for the next launch, still as a computer.
    final saved = Get.find<HiveService>()
        .getSetting<List>(AppConstants.keyClusterWorkers)!
        .single as Map;
    expect(saved['computer'], isTrue);
    expect(saved['ramMb'], 12800);

    // Adding it again replaces it instead of listing it twice.
    expect(await cluster.addComputer(address, memoryMb: 8192), isNull);
    expect(cluster.workers.single.ramMb, 8192);
  });

  test('says why a computer cannot be used', () async {
    final old = await serveFakeRpc(major: 6);
    addTearDown(old.close);
    final mismatch = await cluster.inspectComputer('127.0.0.1:${old.port}');
    expect(mismatch.info, isNull);
    expect(mismatch.error, contains('protocol 6.0.3'));
    expect(mismatch.error, contains('b11157'));

    final web = await serveFakeRpc(garbage: 'HTTP/1.1 400 Bad\r\n\r\n'.codeUnits);
    addTearDown(web.close);
    final notRpc = await cluster.inspectComputer('127.0.0.1:${web.port}');
    expect(notRpc.error, contains("isn't llama.cpp's ggml-rpc-server"));

    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final nothing = await cluster.inspectComputer('127.0.0.1:$port');
    expect(nothing.error, contains("Can't reach 127.0.0.1:$port"));

    final empty = await serveFakeRpc(devices: const []);
    addTearDown(empty.close);
    final noMemory = await cluster.inspectComputer('127.0.0.1:${empty.port}');
    expect(noMemory.error, contains('offers no memory'));

    expect((await cluster.inspectComputer('not an address')).error,
        'Use the form 192.168.1.20:50052');
  });

  test('reads the memory typed by the user', () {
    expect(ClusterService.parseMemoryGb('12'), 12288);
    expect(ClusterService.parseMemoryGb(' 12.5 '), 12800);
    // A French keyboard types a comma.
    expect(ClusterService.parseMemoryGb('12,5'), 12800);
    expect(ClusterService.parseMemoryGb(''), isNull);
    expect(ClusterService.parseMemoryGb('beaucoup'), isNull);
  });

  testWidgets('the sheet says what to run and checks the address first',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAppSheet<bool>(context,
                  builder: (_) => AddComputerSheet(cluster: cluster)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ggml-rpc-server -H 0.0.0.0 -p 50052 -c'), findsOneWidget);
    expect(find.textContaining('llama.cpp b11157'), findsOneWidget);
    // Memory is only asked once the computer has answered.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Add this computer'), findsNothing);

    await tester.enterText(find.byType(TextField), 'my laptop');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('Use the form 192.168.1.20:50052'), findsOneWidget);
    expect(find.text('Add this computer'), findsNothing);
  });
}
