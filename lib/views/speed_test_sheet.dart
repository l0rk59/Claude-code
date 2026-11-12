import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/ui.dart';
import '../services/auto_tune.dart';
import '../services/speed_test.dart';

/// Measures how fast the loaded model answers, and keeps the last results
/// side by side so two settings can be compared.
class SpeedTestSheet extends StatefulWidget {
  /// The model loaded on this phone, '' when there is none.
  final String modelName;

  /// Earlier measurements, most recent first.
  final List<SpeedResult> history;

  /// Runs one measurement, reporting the tokens generated so far.
  final Future<SpeedResult> Function(void Function(int tokens) onProgress) run;

  /// Saves a result and returns the updated history.
  final Future<List<SpeedResult>> Function(SpeedResult result) remember;

  /// Tries the ways this model can run and keeps the fastest, reporting
  /// each step. Null when tuning doesn't apply (no GGUF model, cluster).
  final Future<TuneOutcome> Function(void Function(String step) onStep)?
      autoTune;

  /// Why tuning isn't offered, shown in its place. Null to say nothing.
  final String? autoTuneUnavailable;

  /// The setting remembered for this model, if one was found earlier.
  final DeviceChoice? currentChoice;

  const SpeedTestSheet({
    super.key,
    required this.modelName,
    required this.history,
    required this.run,
    required this.remember,
    this.autoTune,
    this.autoTuneUnavailable,
    this.currentChoice,
  });

  /// "Graphics card", "Processor", "Processor, 4 threads".
  static String describe(DeviceChoice choice) => choice.gpu
      ? 'Graphics card'.tr
      : choice.threads == null
          ? 'Processor'.tr
          : 'Processor, @count threads'.trParams({'count': '${choice.threads}'});

  @override
  State<SpeedTestSheet> createState() => _SpeedTestSheetState();
}

class _SpeedTestSheetState extends State<SpeedTestSheet> {
  late List<SpeedResult> _history = widget.history;
  bool _running = false;
  int _tokens = 0;
  String? _error;

  /// The measurement just made, shown large.
  SpeedResult? _latest;

  bool _tuning = false;
  String _tuneStep = '';
  TuneOutcome? _tuned;

  Future<void> _autoTune() async {
    setState(() {
      _tuning = true;
      _tuneStep = '';
      _error = null;
      _tuned = null;
    });
    try {
      final outcome = await widget.autoTune!((step) {
        if (mounted) setState(() => _tuneStep = step);
      });
      if (!mounted) return;
      setState(() => _tuned = outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "The tuning didn't finish: @error"
          .trParams({'error': e is StateError ? e.message : '$e'}));
    } finally {
      if (mounted) setState(() => _tuning = false);
    }
  }

  Widget _tuneCard(AppTokens t, TuneOutcome outcome) {
    final best = outcome.best;
    final bestTrial = outcome.bestTrial;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.green.withValues(alpha: t.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: t.green.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            best == null
                ? 'Nothing could be measured.'.tr
                : '@setting is the fastest for this model. It will be used from now on.'
                    .trParams({'setting': SpeedTestSheet.describe(best)}),
            style: t.bodyStrong,
          ),
          if (bestTrial != null && outcome.speedup >= 1.1) ...[
            const SizedBox(height: 4),
            Text(
                '@times× faster than the slowest setting.'.trParams(
                    {'times': outcome.speedup.toStringAsFixed(1)}),
                style: t.caption),
          ],
          const SizedBox(height: 10),
          for (final trial in outcome.trials)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(
                    trial.choice == best
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 14,
                    color: trial.choice == best ? t.green : t.faint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(SpeedTestSheet.describe(trial.choice),
                      style: t.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    trial.result != null
                        ? '${_speed(trial.result!.tokensPerSecond)} · ${_wait(trial.result!.firstTokenSeconds)}'
                        : trial.error ?? '',
                    style: t.small.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()]),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Future<void> _measure() async {
    setState(() {
      _running = true;
      _tokens = 0;
      _error = null;
    });
    try {
      final result = await widget.run((tokens) {
        if (mounted) setState(() => _tokens = tokens);
      });
      final history = await widget.remember(result);
      if (!mounted) return;
      setState(() {
        _latest = result;
        _history = history;
      });
    } catch (e) {
      if (!mounted) return;
      final text = e is StateError ? e.message : '$e';
      setState(() => _error = "The measurement didn't finish: @error"
          .trParams({'error': text}));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  static String _speed(double tokensPerSecond) =>
      '@speed tokens/s'.trParams({'speed': tokensPerSecond.toStringAsFixed(1)});

  static String _wait(double seconds) => 'first word after @seconds s'
      .trParams({'seconds': seconds.toStringAsFixed(1)});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final hasModel = widget.modelName.isNotEmpty;
    final latest = _latest;
    // The latest result is shown on its own above the list.
    final earlier = [
      for (final r in _history)
        if (!identical(r, latest)) r,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasModel)
          AppNotice(
            'Load a model on this phone first: the measurement runs on the model in use.'
                .tr,
            icon: Icons.info_outline_rounded,
          )
        else ...[
          Text(
            'The loaded model writes the same short text every time, so you can compare two settings: graphics card or processor, alone or in a cluster, one model or another.'
                .tr,
            style: t.caption,
          ),
          const SizedBox(height: 14),
          if (latest != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: t.isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(kCardRadius),
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.28), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_speed(latest.tokensPerSecond),
                      style: t.title.copyWith(color: t.accent)),
                  const SizedBox(height: 4),
                  Text(
                      '${_wait(latest.firstTokenSeconds)} · ${latest.setup}',
                      style: t.caption),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_running) ...[
            Text(
                'Measuring… @count of @total tokens'.trParams(
                    {'count': '$_tokens', 'total': '${SpeedTest.maxTokens}'}),
                style: t.caption),
            const SizedBox(height: 8),
            AppProgressBar(
                value: (_tokens / SpeedTest.maxTokens).clamp(0.0, 1.0),
                color: t.accent),
            const SizedBox(height: 14),
          ],
          if (_error != null) ...[
            AppNotice(_error!,
                icon: Icons.error_outline_rounded, color: t.red),
            const SizedBox(height: 14),
          ],
          PrimaryButton(
            label: latest == null ? 'Measure'.tr : 'Measure again'.tr,
            icon: Icons.timer_outlined,
            busy: _running,
            onPressed: _running || _tuning ? null : _measure,
          ),
          const SizedBox(height: 18),
          Text('Best setting for this model'.tr, style: t.label),
          const SizedBox(height: 6),
          if (widget.autoTune == null)
            Text(widget.autoTuneUnavailable ?? '', style: t.caption)
          else ...[
            Text(
              widget.currentChoice == null
                  ? 'Tries the graphics card and the processor, measures each, and keeps the fastest. The model reloads a few times: about a minute.'
                      .tr
                  : 'Now: @setting. Search again after an update, or to try another model.'
                      .trParams({
                      'setting': SpeedTestSheet.describe(widget.currentChoice!)
                    }),
              style: t.caption,
            ),
            const SizedBox(height: 10),
            if (_tuning) ...[
              Text(_tuneStep, style: t.caption),
              const SizedBox(height: 8),
              AppProgressBar(color: t.accent),
              const SizedBox(height: 10),
            ],
            if (_tuned != null) ...[
              _tuneCard(t, _tuned!),
              const SizedBox(height: 10),
            ],
            PillButton(
              label: 'Find the best setting'.tr,
              icon: Icons.auto_awesome_rounded,
              onPressed: _running || _tuning ? null : _autoTune,
            ),
          ],
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Earlier measurements'.tr, style: t.label),
          ),
          AppGroup(dividerIndent: 14, children: [
            for (final r in earlier)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.model,
                            style: t.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('${r.setup} · ${_wait(r.firstTokenSeconds)}',
                            style: t.small,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_speed(r.tokensPerSecond),
                      style: t.bodyStrong.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Text(
          'For a fair measure, close the other apps and keep the phone plugged in.'
              .tr,
          style: t.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
