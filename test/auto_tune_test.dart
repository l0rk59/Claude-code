import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/core/ui.dart';
import 'package:privatelm/services/auto_tune.dart';
import 'package:privatelm/services/hive_service.dart';
import 'package:privatelm/services/speed_test.dart';
import 'package:privatelm/views/speed_test_sheet.dart';

SpeedResult _measured(double speed, {double first = 1.0}) => SpeedResult(
      model: 'qwen3.5-2b-q4_k_m.gguf',
      setup: '',
      firstTokenSeconds: first,
      tokensPerSecond: speed,
      tokens: 96,
      at: DateTime(2026, 11, 13),
    );

void main() {
  test('choices are stored and read back', () {
    for (final choice in const [
      DeviceChoice.gpu(),
      DeviceChoice.cpu(),
      DeviceChoice.cpu(4),
    ]) {
      expect(DeviceChoice.decode(choice.encode()), choice);
    }
    expect(DeviceChoice.decode(null), isNull);
    expect(DeviceChoice.decode('npu'), isNull);
    expect(DeviceChoice.decode('cpu:0'), isNull);
  });

  test('tries the graphics card and the processor, four threads included', () {
    expect(AutoTune.candidates(defaultThreads: 6), const [
      DeviceChoice.gpu(),
      DeviceChoice.cpu(),
      DeviceChoice.cpu(4),
    ]);
    // Four is already the default: no need to try it twice.
    expect(AutoTune.candidates(defaultThreads: 4),
        const [DeviceChoice.gpu(), DeviceChoice.cpu()]);
  });

  test('a long wait for the first word counts against a setting', () {
    // Faster writing, but 6 s before the first word.
    final gpu = _measured(14, first: 6);
    // Slower writing, but it starts at once.
    final cpu = _measured(12, first: 0.4);
    expect(AutoTune.cost(gpu), greaterThan(AutoTune.cost(cpu)));
    expect(AutoTune.cost(_measured(0)), double.infinity);
  });

  test('keeps the fastest, remembers it and leaves the model loaded that way',
      () async {
    // The phone of the first real measurement: a Mali graphics card slower
    // than the processor.
    final speeds = {
      const DeviceChoice.gpu(): _measured(12.7, first: 5.9),
      const DeviceChoice.cpu(): _measured(19.5, first: 0.6),
      const DeviceChoice.cpu(4): _measured(17.0, first: 0.7),
    };
    final applied = <DeviceChoice?>[];
    final loaded = <DeviceChoice>[];
    final steps = <int>[];
    late DeviceChoice current;

    final outcome = await AutoTune.run(
      candidates: AutoTune.candidates(defaultThreads: 6),
      apply: (c) async {
        applied.add(c);
        if (c != null) current = c;
      },
      reload: (c) async {
        loaded.add(c);
        return null;
      },
      measure: () async => speeds[current]!,
      onTrial: (i, _) => steps.add(i),
    );

    expect(outcome.best, const DeviceChoice.cpu());
    expect(steps, [0, 1, 2]);
    // The last thing applied is the winner, and the model is reloaded with
    // it because the last trial was another setting.
    expect(applied.last, const DeviceChoice.cpu());
    expect(loaded.last, const DeviceChoice.cpu());
    expect(outcome.speedup, greaterThan(1.9));
    expect(outcome.bestTrial!.result!.tokensPerSecond, 19.5);
  });

  test('a setting that cannot load is skipped, not fatal', () async {
    late DeviceChoice current;
    final outcome = await AutoTune.run(
      candidates: const [DeviceChoice.gpu(), DeviceChoice.cpu()],
      apply: (c) async {
        if (c != null) current = c;
      },
      reload: (c) async => c.gpu ? 'no graphics card' : null,
      measure: () async => _measured(current.gpu ? 99 : 10),
    );
    expect(outcome.best, const DeviceChoice.cpu());
    expect(outcome.trials.first.error, 'no graphics card');
    expect(outcome.speedup, 1);
  });

  test('nothing measured: nothing is remembered', () async {
    final applied = <DeviceChoice?>[];
    final outcome = await AutoTune.run(
      candidates: const [DeviceChoice.gpu(), DeviceChoice.cpu()],
      apply: (c) async => applied.add(c),
      reload: (c) async => 'failed',
      measure: () async => throw StateError('unused'),
    );
    expect(outcome.best, isNull);
    expect(applied.last, isNull);
  });

  test('the choice is remembered per model', () async {
    final dir = await Directory.systemTemp.createTemp('auto_tune');
    Hive.init(dir.path);
    final hive = await HiveService().init();
    addTearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });
    await DeviceChoices.set(hive, 'a.gguf', const DeviceChoice.cpu(4));
    await DeviceChoices.set(hive, 'b.gguf', const DeviceChoice.gpu());
    expect(DeviceChoices.of(hive, 'a.gguf'), const DeviceChoice.cpu(4));
    expect(DeviceChoices.of(hive, 'b.gguf'), const DeviceChoice.gpu());
    expect(DeviceChoices.of(hive, 'c.gguf'), isNull);
    await DeviceChoices.set(hive, 'a.gguf', null);
    expect(DeviceChoices.of(hive, 'a.gguf'), isNull);
    expect(DeviceChoices.of(hive, 'b.gguf'), const DeviceChoice.gpu());
  });

  testWidgets('the sheet runs the tuning and says what it kept',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAppSheet<void>(context,
                  builder: (_) => SpeedTestSheet(
                        modelName: 'qwen3.5-2b-q4_k_m.gguf',
                        history: const [],
                        run: (_) async => _measured(10),
                        remember: (r) async => [r],
                        autoTune: (onStep) async {
                          onStep('step');
                          return TuneOutcome([
                            TuneTrial(const DeviceChoice.gpu(),
                                result: _measured(12.7, first: 5.9)),
                            TuneTrial(const DeviceChoice.cpu(),
                                result: _measured(19.5, first: 0.6)),
                            const TuneTrial(DeviceChoice.cpu(4),
                                error: 'failed'),
                          ], const DeviceChoice.cpu());
                        },
                      )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find the best setting'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Processor is the fastest for this model. It will be used from now on.'),
        findsOneWidget);
    expect(find.textContaining('faster than the slowest setting'),
        findsOneWidget);
    expect(find.text('Graphics card'), findsOneWidget);
    expect(find.text('Processor, 4 threads'), findsOneWidget);
    expect(find.text('failed'), findsOneWidget);
  });

  testWidgets('says why tuning is not offered', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SpeedTestSheet(
            modelName: 'Qwen3-0.6B.litertlm',
            history: const [],
            run: (_) async => _measured(10),
            remember: (r) async => [r],
            autoTuneUnavailable: 'For GGUF models only.',
          ),
        ),
      ),
    ));
    expect(find.text('For GGUF models only.'), findsOneWidget);
    expect(find.text('Find the best setting'), findsNothing);
  });
}
