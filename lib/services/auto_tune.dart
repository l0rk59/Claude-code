import 'hive_service.dart';
import 'speed_test.dart';

/// How a GGUF model runs on this phone: on the graphics card, or on the
/// processor with a given number of threads (null: the app's default).
class DeviceChoice {
  final bool gpu;
  final int? threads;

  const DeviceChoice.gpu()
      : gpu = true,
        threads = null;
  const DeviceChoice.cpu([this.threads]) : gpu = false;

  /// Stored form: "gpu", "cpu" or "cpu:4".
  String encode() => gpu
      ? 'gpu'
      : threads == null
          ? 'cpu'
          : 'cpu:$threads';

  static DeviceChoice? decode(String? text) {
    if (text == null) return null;
    if (text == 'gpu') return const DeviceChoice.gpu();
    if (text == 'cpu') return const DeviceChoice.cpu();
    final match = RegExp(r'^cpu:(\d+)$').firstMatch(text);
    if (match == null) return null;
    final threads = int.parse(match[1]!);
    return threads > 0 ? DeviceChoice.cpu(threads) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceChoice && other.gpu == gpu && other.threads == threads;

  @override
  int get hashCode => Object.hash(gpu, threads);

  @override
  String toString() => encode();
}

/// The device choice remembered for each GGUF model, by file name. A model
/// without one follows the Performance setting.
class DeviceChoices {
  static const _key = 'gguf_device_choices';

  static Map<String, String> _all(HiveService hive) {
    final raw = hive.getSetting<Map>(_key, defaultValue: const {}) ?? const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    };
  }

  static DeviceChoice? of(HiveService hive, String model) =>
      DeviceChoice.decode(_all(hive)[model]);

  /// Remembers [choice] for [model]; null forgets it.
  static Future<void> set(
      HiveService hive, String model, DeviceChoice? choice) async {
    final all = _all(hive);
    if (choice == null) {
      all.remove(model);
    } else {
      all[model] = choice.encode();
    }
    await hive.setSetting(_key, all);
  }
}

/// One setting tried by [AutoTune].
class TuneTrial {
  final DeviceChoice choice;
  final SpeedResult? result;

  /// Why it couldn't be measured (the graphics card isn't usable, the load
  /// failed…). Null when [result] is set.
  final String? error;

  const TuneTrial(this.choice, {this.result, this.error});
}

/// What [AutoTune] found.
class TuneOutcome {
  final List<TuneTrial> trials;

  /// The fastest setting, now remembered for the model. Null when nothing
  /// could be measured.
  final DeviceChoice? best;

  const TuneOutcome(this.trials, this.best);

  TuneTrial? get bestTrial {
    for (final t in trials) {
      if (t.choice == best && t.result != null) return t;
    }
    return null;
  }

  /// How many times faster the best setting is than the slowest one that
  /// was measured. 1 when only one was.
  double get speedup {
    final costs = [
      for (final t in trials)
        if (t.result != null) AutoTune.cost(t.result!),
    ];
    if (costs.length < 2) return 1;
    costs.sort();
    return costs.last / costs.first;
  }
}

/// Finds the fastest way to run a GGUF model on this phone by measuring it:
/// graphics cards and thread counts that are fastest on one phone are often
/// the slowest on another (a Mali graphics card, for instance, can be
/// slower than the processor).
class AutoTune {
  /// Typical answer length the settings are compared on, in tokens.
  static const answerTokens = 200;

  /// Seconds to write a typical answer: the wait for the first word plus
  /// the writing. Lower is better.
  static double cost(SpeedResult r) => r.tokensPerSecond <= 0
      ? double.infinity
      : r.firstTokenSeconds + answerTokens / r.tokensPerSecond;

  /// The settings worth trying: the graphics card, the processor with the
  /// app's default thread count, and with four threads (memory speed, not
  /// the number of cores, limits generation, so fewer threads often win).
  static List<DeviceChoice> candidates({int? defaultThreads}) => [
        const DeviceChoice.gpu(),
        const DeviceChoice.cpu(),
        if (defaultThreads != 4) const DeviceChoice.cpu(4),
      ];

  /// The fastest measured trial's setting, or null.
  static DeviceChoice? pick(List<TuneTrial> trials) {
    TuneTrial? best;
    for (final t in trials) {
      if (t.result == null) continue;
      if (best == null || cost(t.result!) < cost(best.result!)) best = t;
    }
    return best?.choice;
  }

  /// Tries each of [candidates] on [model]: [apply] remembers the setting,
  /// [reload] loads the model with it (returning why it couldn't, or null),
  /// [measure] times it. The fastest is remembered and loaded at the end.
  static Future<TuneOutcome> run({
    required List<DeviceChoice> candidates,
    required Future<void> Function(DeviceChoice? choice) apply,
    required Future<String?> Function(DeviceChoice choice) reload,
    required Future<SpeedResult> Function() measure,
    void Function(int index, DeviceChoice choice)? onTrial,
  }) async {
    final trials = <TuneTrial>[];
    for (var i = 0; i < candidates.length; i++) {
      final choice = candidates[i];
      onTrial?.call(i, choice);
      await apply(choice);
      final problem = await reload(choice);
      if (problem != null) {
        trials.add(TuneTrial(choice, error: problem));
        continue;
      }
      try {
        trials.add(TuneTrial(choice, result: await measure()));
      } catch (e) {
        trials.add(TuneTrial(choice, error: e is StateError ? e.message : '$e'));
      }
    }
    final best = pick(trials);
    await apply(best);
    // Leave the model loaded the fastest way.
    if (best != null && trials.isNotEmpty && trials.last.choice != best) {
      await reload(best);
    }
    return TuneOutcome(trials, best);
  }
}
