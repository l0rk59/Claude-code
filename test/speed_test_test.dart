import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/core/ui.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/services/speed_test.dart';
import 'package:privatelm/views/speed_test_sheet.dart';

SpeedResult _result(String model, double speed, {String setup = 'GGUF · CPU'}) =>
    SpeedResult(
      model: model,
      setup: setup,
      firstTokenSeconds: 1.25,
      tokensPerSecond: speed,
      tokens: 96,
      at: DateTime(2026, 11, 12, 10),
    );

void main() {
  test('speed counts the tokens after the first one', () {
    // 96 tokens, the first after 2 s, the other 95 in the next 10 s.
    expect(
        SpeedTest.rate(
            tokens: 96,
            total: const Duration(seconds: 12),
            firstToken: const Duration(seconds: 2)),
        9.5);
    // Nothing to measure.
    expect(
        SpeedTest.rate(
            tokens: 1,
            total: const Duration(seconds: 3),
            firstToken: const Duration(seconds: 3)),
        0);
    expect(
        SpeedTest.rate(
            tokens: 0, total: Duration.zero, firstToken: Duration.zero),
        0);
  });

  test('names the setup that was measured', () {
    expect(SpeedTest.describeSetup(runtime: 'llama', gpu: false), 'GGUF · CPU');
    expect(
        SpeedTest.describeSetup(
            runtime: 'llama', gpu: true, gpuName: 'Adreno 740'),
        'GGUF · GPU (Adreno 740)');
    expect(SpeedTest.describeSetup(runtime: 'litert', gpu: true), 'LiteRT · GPU');
    // The phone and three other devices.
    expect(
        SpeedTest.describeSetup(runtime: 'llama', gpu: false, clusterWorkers: 3),
        'GGUF · CPU · cluster × 4');
  });

  test('keeps the last measurements, most recent first', () async {
    final dir = await Directory.systemTemp.createTemp('speed_test');
    Hive.init(dir.path);
    final hive = await HiveService().init();
    addTearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    expect(SpeedTest.history(hive), isEmpty);
    for (var i = 1; i <= 15; i++) {
      await SpeedTest.remember(hive, _result('model-$i', i.toDouble()));
    }
    final kept = SpeedTest.history(hive);
    expect(kept, hasLength(12));
    expect(kept.first.model, 'model-15');
    expect(kept.last.model, 'model-4');
    expect(kept.first.tokensPerSecond, 15);
    expect(kept.first.firstTokenSeconds, 1.25);
    expect(kept.first.at, DateTime(2026, 11, 12, 10));
  });

  Future<void> open(WidgetTester tester, SpeedTestSheet sheet) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showAppSheet<void>(context, builder: (_) => sheet),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('measures, shows the result and lists the earlier ones',
      (tester) async {
    final saved = <SpeedResult>[];
    final earlier = _result('Qwen 3.5 2B', 8.4);
    await open(
      tester,
      SpeedTestSheet(
        modelName: 'Qwen 3.5 4B',
        history: [earlier],
        run: (onProgress) async {
          onProgress(48);
          return _result('Qwen 3.5 4B', 14.26, setup: 'GGUF · GPU');
        },
        remember: (result) async {
          saved.add(result);
          return [result, earlier];
        },
      ),
    );
    expect(find.text('8.4 tokens/s'), findsOneWidget);

    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();
    expect(find.text('14.3 tokens/s'), findsOneWidget);
    expect(find.textContaining('first word after 1.3 s · GGUF · GPU'),
        findsOneWidget);
    expect(saved.single.model, 'Qwen 3.5 4B');
    // The earlier one is still there to compare with.
    expect(find.text('8.4 tokens/s'), findsOneWidget);
    expect(find.text('Measure again'), findsOneWidget);
  });

  testWidgets('needs a model, and reports a failed measurement',
      (tester) async {
    await open(
      tester,
      SpeedTestSheet(
        modelName: '',
        history: const [],
        run: (_) async => throw StateError('unused'),
        remember: (r) async => [r],
      ),
    );
    expect(find.textContaining('Load a model on this phone first'),
        findsOneWidget);
    expect(find.text('Measure'), findsNothing);
  });

  testWidgets('reports a measurement that fails', (tester) async {
    await open(
      tester,
      SpeedTestSheet(
        modelName: 'Qwen 3.5 4B',
        history: const [],
        run: (_) async => throw StateError('ERROR: Generation timed out.'),
        remember: (r) async => [r],
      ),
    );
    await tester.tap(find.text('Measure'));
    await tester.pumpAndSettle();
    expect(find.textContaining("didn't finish: ERROR: Generation timed out."),
        findsOneWidget);
    expect(find.text('Measure'), findsOneWidget);
  });
}
