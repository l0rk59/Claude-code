import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/model_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/constants.dart';
import '../core/ui.dart';
import '../l10n/app_translations.dart';
import '../widgets/home_empty_state.dart' show providerLabel;
import '../services/inference_service.dart';
import '../services/hive_service.dart';
import '../services/local_image_service.dart';
import '../services/update_service.dart';
import '../services/device_info_service.dart';
import '../services/download_service.dart';
import '../services/soc_family.dart' as platform_info;
import '../ffi/sd_backend.dart';
import '../services/cluster_service.dart';
import '../services/speed_test.dart';
import 'cluster_view.dart';
import 'speed_test_sheet.dart';
import 'log_view.dart';
import '../core/haptics.dart';

const _tabular = [FontFeature.tabularFigures()];

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Settings'.tr),
      body: Obx(() {
        final device = Get.find<DeviceInfoService>();
        final showUpdates =
            UpdateService.isSupported && Get.isRegistered<UpdateService>();
        return ListView(
          padding: kPagePadding,
          children: [
            SectionHeader('General'.tr,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8)),
            AppGroup(dividerIndent: 60, children: [
              _navRow(
                context,
                icon: Icons.palette_outlined,
                title: 'Appearance',
                value: _themeLabel(),
                builder: (ctx) => _buildAppearanceGroup(ctx),
              ),
              _navRow(
                context,
                icon: Icons.translate_rounded,
                title: 'Language',
                value: _languageLabel(controller.language.value),
                builder: (ctx) => _buildLanguageGroup(ctx),
              ),
              AppRow(
                icon: Icons.vibration_rounded,
                title: 'Haptic feedback'.tr,
                trailing: Switch(
                  value: controller.hapticsEnabled.value,
                  onChanged: controller.setHapticsEnabled,
                ),
                onTap: () => controller
                    .setHapticsEnabled(!controller.hapticsEnabled.value),
              ),
            ]),
            SectionHeader('Chat'.tr),
            AppGroup(dividerIndent: 60, children: [
              _navRow(
                context,
                icon: Icons.memory_rounded,
                title: 'Inference mode',
                value: controller.inferenceMode.value == 'local'
                    ? 'Local'.tr
                    : 'Cloud'.tr,
                builder: (ctx) => _buildInferenceGroup(ctx),
              ),
              _navRow(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'System prompt',
                value: controller.globalSystemPrompt.value.trim().isEmpty
                    ? 'Default'.tr
                    : 'Custom'.tr,
                builder: (ctx) => _buildSystemPromptGroup(ctx),
                reactive: false,
              ),
              _navRow(
                context,
                icon: Icons.tune_rounded,
                title: 'Model parameters',
                value: controller.temperature.value.toStringAsFixed(2),
                builder: (ctx) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildModelParametersGroup(ctx),
                      SectionHeader('Stop sequences'.tr),
                      _buildStopSequencesGroup(ctx),
                    ]),
              ),
            ]),
            SectionHeader('Performance'.tr),
            AppGroup(dividerIndent: 60, children: [
              _navRow(
                context,
                icon: Icons.speed_rounded,
                title: 'GGUF & LiteRT',
                value: switch (controller.liteRtPerformanceMode.value) {
                  'gpu_fast' => 'GPU fast'.tr,
                  'cpu_safe' => 'CPU safe'.tr,
                  _ => 'Auto fast'.tr,
                },
                builder: (ctx) => _buildLiteRtGroup(ctx),
              ),
              _navRow(
                context,
                icon: Icons.image_outlined,
                title: 'Image generation',
                value: controller.imageGenBackend.value == Backend.cpu
                    ? 'CPU'
                    : 'GPU',
                builder: (ctx) => _buildImageGenerationGroup(ctx),
              ),
              AppRow(
                icon: Icons.timer_outlined,
                title: 'Measure speed'.tr,
                chevron: true,
                onTap: () => _measureSpeed(context),
              ),
              if (Get.isRegistered<ClusterService>())
                AppRow(
                  icon: Icons.hub_outlined,
                  title: 'Phone cluster'.tr,
                  trailing: Text(
                      switch (Get.find<ClusterService>().role) {
                        ClusterRole.master => 'Master'.tr,
                        ClusterRole.worker => 'Worker'.tr,
                        ClusterRole.off => 'Off'.tr,
                      },
                      style: AppTokens.of(context).caption.copyWith(fontSize: 14)),
                  chevron: true,
                  onTap: () => Get.to(() => const ClusterView()),
                ),
            ]),
            SectionHeader('About'.tr),
            AppGroup(dividerIndent: 60, children: [
              if (showUpdates) _buildUpdatesRow(context),
              _navRow(
                context,
                icon: Icons.smartphone_rounded,
                title: 'Device',
                value: '@ram GB RAM'.trParams(
                    {'ram': device.totalRamGB.value.toStringAsFixed(1)}),
                builder: (ctx) => AppGroup(children: [_buildDeviceCard(ctx)]),
                reactive: false,
              ),
              AppRow(
                icon: Icons.article_outlined,
                title: 'Logs'.tr,
                chevron: true,
                onTap: () => Get.to(() => const LogView()),
              ),
              AppRow(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icons/appicon.png',
                      width: 32, height: 32),
                ),
                title: 'PrivateLM',
                subtitle: controller.appVersion.value.isEmpty
                    ? 'by orailnoor & techjarves'.tr
                    : 'Version @version · by orailnoor & techjarves'
                        .trParams({'version': controller.appVersion.value}),
              ),
            ]),
          ],
        );
      }),
    );
  }

  /// Row on the main page: icon, title, current value and a chevron that
  /// opens the section on its own page. [title] is the English text; the row
  /// and the page translate it.
  /// Opens the speed test on the model loaded on this phone.
  void _measureSpeed(BuildContext context) {
    final inference = Get.find<InferenceService>();
    final hive = Get.find<HiveService>();
    // Workers sharing the loaded model, to label the result.
    final workers = Get.isRegistered<ClusterService>()
        ? (Get.find<ClusterService>().split.length - 1).clamp(0, 99)
        : 0;
    showAppSheet<void>(
      context,
      title: 'Measure speed'.tr,
      subtitle: inference.isModelLoaded.value
          ? inference.loadedModelName.value
          : null,
      builder: (_) => SpeedTestSheet(
        modelName: inference.isModelLoaded.value
            ? inference.loadedModelName.value
            : '',
        history: SpeedTest.history(hive),
        run: (onProgress) => SpeedTest.run(inference,
            clusterWorkers: workers, onProgress: onProgress),
        remember: (result) => SpeedTest.remember(hive, result),
      ),
    );
  }

  Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required WidgetBuilder builder,
    bool reactive = true,
  }) {
    final t = AppTokens.of(context);
    return AppRow(
      icon: icon,
      title: title.tr,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(fontSize: 14)),
      ),
      chevron: true,
      onTap: () => Get.to(() =>
          _SettingsPage(title: title, builder: builder, reactive: reactive)),
    );
  }

  String _themeLabel() => switch (controller.themeMode.value) {
        ThemeMode.light => 'Light'.tr,
        ThemeMode.dark => 'Dark'.tr,
        ThemeMode.system => 'System'.tr,
      };

  /// Language names stay in their own language.
  static String _languageLabel(String code) => switch (code) {
        'en' => 'English',
        'fr' => 'Français',
        _ => 'System'.tr,
      };

  Widget _buildLanguageGroup(BuildContext context) {
    return AppGroup(dividerIndent: 60, children: [
      for (final code in AppTranslations.languageCodes)
        AppRow(
          icon: code == AppTranslations.system
              ? Icons.smartphone_rounded
              : Icons.translate_rounded,
          title: _languageLabel(code),
          subtitle: code == AppTranslations.system
              ? 'Same language as the phone'.tr
              : null,
          selected: controller.language.value == code,
          onTap: () => controller.setLanguage(code),
        ),
    ]);
  }

  Widget _buildAppearanceGroup(BuildContext context) {
    final t = AppTokens.of(context);
    return AppGroup(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Theme'.tr, style: t.body),
          const SizedBox(height: 10),
          AppSegmented<ThemeMode>(
            items: [
              (ThemeMode.light, 'Light'.tr),
              (ThemeMode.dark, 'Dark'.tr),
              (ThemeMode.system, 'System'.tr),
            ],
            selected: controller.themeMode.value,
            onChanged: (mode) {
              if (mode != controller.themeMode.value) {
                controller.setThemeMode(mode);
              }
            },
          ),
        ]),
      ),
      _buildFontSizeRow(context),
    ]);
  }

  Widget _buildInferenceGroup(BuildContext context) {
    return AppGroup(dividerIndent: 60, children: [
      AppRow(
        icon: Icons.phone_iphone_rounded,
        title: 'Local (on-device)'.tr,
        subtitle: _localSubtitle(),
        selected: controller.inferenceMode.value == 'local',
        onTap: () => controller.setInferenceMode('local'),
      ),
      AppRow(
        icon: Icons.cloud_outlined,
        title: 'Cloud API'.tr,
        subtitle: providerLabel(controller),
        selected: controller.inferenceMode.value == 'cloud',
        onTap: () => controller.setInferenceMode('cloud'),
      ),
    ]);
  }

  Widget _buildSystemPromptGroup(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(children: [
      TextField(
        controller: controller.globalSystemPromptController,
        minLines: 5,
        maxLines: 12,
        style: t.body,
        decoration:
            appInputDecoration(context, hint: AppConstants.systemPrompt),
        onSubmitted: (v) => controller.setGlobalSystemPrompt(v),
      ),
      _fieldFooter(
        context,
        note: 'Applies to local and cloud models.'.tr,
        onSave: () async {
          await controller.setGlobalSystemPrompt(
              controller.globalSystemPromptController.text);
          if (context.mounted) {
            _confirmSaved(context, 'System prompt saved'.tr);
          }
        },
      ),
    ]);
  }

  Widget _buildStopSequencesGroup(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(children: [
      TextField(
        controller: controller.stopSequencesController,
        minLines: 2,
        maxLines: 5,
        style: t.mono.copyWith(fontSize: 13.5),
        decoration: appInputDecoration(context, hint: '###\n\\nUser:'),
      ),
      _fieldFooter(
        context,
        note: 'Local models stop when they write one of these. '
                'One per line; use \\n for a newline.'
            .tr,
        onSave: () async {
          await controller
              .setStopSequences(controller.stopSequencesController.text);
          if (context.mounted) {
            _confirmSaved(context, 'Stop sequences saved'.tr);
          }
        },
      ),
    ]);
  }

  Widget _buildUpdatesRow(BuildContext context) {
    final updates = Get.find<UpdateService>();
    final t = AppTokens.of(context);
    final update = updates.availableUpdate.value;
    final downloading = updates.state.value == UpdateState.downloading;
    return AppRow(
      icon: Icons.system_update_rounded,
      title: 'App updates'.tr,
      trailing: update != null
          ? AppTag(
              downloading
                  ? '${(updates.progress.value * 100).round()}%'
                  : '@version available'.trParams({'version': update.version}),
              color: t.accent)
          : Text('Up to date'.tr, style: t.caption.copyWith(fontSize: 14)),
      chevron: true,
      onTap: () => Get.to(() => _SettingsPage(
          title: 'App updates', builder: (ctx) => _buildUpdatesGroup(ctx))),
    );
  }

  Widget _buildUpdatesGroup(BuildContext context) {
    final updates = Get.find<UpdateService>();
    final update = updates.availableUpdate.value;
    final checking = updates.state.value == UpdateState.checking;
    final checked = updates.lastCheck.value;
    final current = updates.currentVersion.value;
    final String status;
    if (update != null) {
      status = "You have @current · see what's new"
          .trParams({'current': current});
    } else if (checked != null) {
      status = 'Up to date · checked @ago'.trParams({'ago': _ago(checked)});
    } else {
      status = 'Not checked yet'.tr;
    }
    return AppGroup(dividerIndent: 60, children: [
      AppRow(
        icon: update != null ? Icons.download_rounded : Icons.refresh_rounded,
        title: update != null
            ? 'Update to @version'.trParams({'version': update.version})
            : 'Check for updates'.tr,
        subtitle: status,
        trailing: checking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        chevron: !checking,
        onTap: checking
            ? null
            : () async {
                if (update != null) {
                  updates.showUpdateSheet(context);
                  return;
                }
                final found = await updates.checkForUpdate(manual: true);
                if (found != null && context.mounted) {
                  updates.showUpdateSheet(context);
                }
              },
      ),
      AppRow(
        icon: Icons.schedule_rounded,
        title: 'Check automatically'.tr,
        subtitle: 'Look for a new release once a day'.tr,
        trailing: Switch(
          value: updates.autoCheck.value,
          onChanged: updates.setAutoCheck,
        ),
        onTap: () => updates.setAutoCheck(!updates.autoCheck.value),
      ),
    ]);
  }

  static String _ago(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'just now'.tr;
    if (d.inHours < 1) {
      return '@count min ago'.trParams({'count': '${d.inMinutes}'});
    }
    if (d.inDays < 1) return '@count h ago'.trParams({'count': '${d.inHours}'});
    return '@count d ago'.trParams({'count': '${d.inDays}'});
  }

  // ── Building blocks ─────────────────────────────────────────────────────

  /// Note on the left, explicit Save on the right, under a text field.
  Widget _fieldFooter(BuildContext context,
      {required String note, required VoidCallback onSave}) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note, style: t.small),
          ),
        ),
        const SizedBox(width: 12),
        PillButton(label: 'Save'.tr, primary: true, onPressed: onSave),
      ]),
    );
  }

  void _confirmSaved(BuildContext context, String message) {
    FocusScope.of(context).unfocus();
    showToast('Saved'.tr, message, tone: ToastTone.success);
  }

  /// Consistent slider row: label left, value right, slider below, then an
  /// optional caption and trailing widget (e.g. a warning notice).
  Widget _sliderRow(
    BuildContext context, {
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    Color? color,
    String? caption,
    List<Widget> below = const [],
  }) {
    final t = AppTokens.of(context);
    final c = color ?? t.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text(label, style: t.body)),
            const SizedBox(width: 12),
            Text(valueLabel,
                style: t.body.copyWith(
                    color: color ?? t.muted,
                    fontWeight: color != null ? FontWeight.w600 : null,
                    fontFeatures: _tabular)),
          ]),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: c,
            inactiveTrackColor: t.fill,
            thumbColor: Colors.white,
            overlayColor: c.withValues(alpha: 0.12),
            trackShape: const RoundedRectSliderTrackShape(),
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10, elevation: 2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(caption, style: t.small),
          ),
        for (final w in below)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: w,
          ),
      ]),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────

  String _localSubtitle() {
    final inf = Get.find<InferenceService>();
    final localImage = Get.find<LocalImageService>();
    if (inf.isModelLoaded.value) {
      return 'Active: @name'.trParams({'name': inf.loadedModelName.value});
    } else if (localImage.isModelLoaded.value) {
      return 'Active: @name'
          .trParams({'name': localImage.loadedModelName.value});
    }
    return 'No model loaded'.tr;
  }

  Widget _buildFontSizeRow(BuildContext context) {
    final t = AppTokens.of(context);
    const min = 0.8;
    const max = 1.4;
    final v = controller.fontScale.value;

    String scaleLabel(double v) {
      if (v <= 0.85) return 'XS';
      if (v <= 0.95) return 'Small'.tr;
      if (v <= 1.05) return 'Recommended'.tr;
      if (v <= 1.15) return 'Large'.tr;
      if (v <= 1.25) return 'XL';
      return 'XXL';
    }

    final isDefault = v >= 0.9 && v <= 0.95;
    Widget marker(String s, {bool on = false}) => Text(s,
        style: t.small.copyWith(
            fontSize: 11,
            color: on ? t.text : t.faint,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400));

    return _sliderRow(
      context,
      label: 'Text size'.tr,
      valueLabel: scaleLabel(v),
      value: v,
      min: min,
      max: max,
      divisions: 12,
      onChanged: (v) => controller.setFontScale(v),
      below: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          marker('XS'),
          marker('Small (default)'.tr, on: isDefault),
          marker('Large'.tr),
        ]),
      ],
    );
  }

  Widget _buildDeviceCard(BuildContext context) {
    return Obx(() {
      final t = AppTokens.of(context);
      final device = Get.find<DeviceInfoService>();
      final ram = device.totalRamGB.value.toStringAsFixed(1);
      final (String tierName, String tierHint) =
          switch (device.deviceTier.value) {
        'low' => ('Low RAM'.tr, 'Use small models only'.tr),
        'mid' => ('Mid-range'.tr, 'Good for 1–3B models'.tr),
        'high' => ('High-end'.tr, 'Can run 3–7B models'.tr),
        'ultra' => ('Ultra', 'Full performance mode'.tr),
        _ => ('', ''),
      };
      final isLow = device.deviceTier.value == 'low';

      final soc = device.socFamily.value;
      final quantWarning = soc.quantWarning;

      Widget kv(String k, String v, {Color? color}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Text(k, style: t.caption.copyWith(fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(v,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(
                        fontSize: 14,
                        color: color ?? t.text,
                        fontFeatures: _tabular)),
              ),
            ]),
          );

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBadge(Icons.smartphone_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@ram GB RAM'.trParams({'ram': ram}),
                        style: t.bodyStrong.copyWith(fontFeatures: _tabular)),
                    if (tierHint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(tierHint, style: t.caption),
                    ],
                  ]),
            ),
            if (tierName.isNotEmpty) ...[
              const SizedBox(width: 10),
              AppTag(tierName, color: isLow ? t.orange : null),
            ],
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 0.5, color: t.hairline),
          ),
          kv(
              'Available memory'.tr,
              '@size GB'.trParams({
                'size': device.availableRamGB.value.toStringAsFixed(1)
              })),
          kv('Recommended context'.tr, '${device.recommendedContextSize}'),
          kv('Recommended max tokens'.tr, '${device.recommendedMaxTokens}'),
          if (soc != platform_info.SocFamily.unknown) ...[
            kv('Chipset'.tr, soc.displayName),
            kv('Recommended quant'.tr, soc.recommendedQuant,
                color: quantWarning != null ? t.orange : null),
          ],
          if (quantWarning != null) ...[
            const SizedBox(height: 10),
            AppNotice(quantWarning,
                icon: Icons.warning_amber_rounded, color: t.orange),
          ],
        ]),
      );
    });
  }

  Widget _buildLiteRtGroup(BuildContext context) {
    final modes = [
      (
        value: 'auto_fast',
        title: 'Auto fast'.tr,
        subtitle:
            "Uses the GPU when supported, CPU if the GPU can't load the model"
                .tr,
        icon: Icons.auto_awesome_outlined
      ),
      (
        value: 'gpu_fast',
        title: 'GPU fast'.tr,
        subtitle: 'Always tries the GPU. Fastest, may crash on some devices'.tr,
        icon: Icons.bolt_rounded
      ),
      (
        value: 'cpu_safe',
        title: 'CPU safe'.tr,
        subtitle: 'CPU only. Most stable, slower'.tr,
        icon: Icons.shield_outlined
      ),
    ];
    final t = AppTokens.of(context);
    return AppGroup(dividerIndent: 60, children: [
      for (final m in modes)
        AppRow(
          icon: m.icon,
          title: m.title,
          subtitle: m.subtitle,
          selected: controller.liteRtPerformanceMode.value == m.value,
          onTap: () => controller.setLiteRtPerformanceMode(m.value),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Text(
            'Applies to both GGUF and LiteRT models. Takes effect the next '
                    'time a model is loaded.'
                .tr,
            style: t.small),
      ),
      if (GetPlatform.isAndroid) ..._buildGgufGpuApiRows(context),
      if (GetPlatform.isAndroid) ..._buildSpeculativeRows(context),
    ]);
  }

  /// The engine's reason for skipping the draft model, in plain words.
  static String _draftReason(String error) {
    if (error.contains("doesn't match")) {
      return 'it is not from the same model family'.tr;
    }
    if (error.contains('not found')) return 'its file is missing'.tr;
    if (error.contains("Couldn't")) {
      return 'it could not be loaded (not enough memory?)'.tr;
    }
    return error;
  }

  /// Speculative decoding: pick a small downloaded GGUF model as the draft.
  List<Widget> _buildSpeculativeRows(BuildContext context) {
    final t = AppTokens.of(context);
    final models = Get.find<ModelController>();
    const maxDraftBytes = 1600 * 1000 * 1000;
    final drafts = [
      for (final f in models.downloadedFiles)
        if (f.toLowerCase().endsWith('.gguf') &&
            !f.toLowerCase().contains('mmproj') &&
            (models.fileSizes[f] ?? 0) > 0 &&
            models.fileSizes[f]! <= maxDraftBytes)
          f,
    ]..sort();
    final selected = controller.speculativeDraftModel.value;
    final error = Get.find<InferenceService>().lastDraftError.value;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Speculative decoding · experimental'.tr, style: t.label),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
            'A small model of the same family (e.g. Qwen 3.5 0.8B for Qwen 3.5 '
                    '4B) proposes words the main model checks in one go: same '
                    'answers, faster when it guesses well. Uses extra memory. '
                    'GGUF models, text only.'
                .tr,
            style: t.small),
      ),
      AppRow(
        icon: Icons.block_rounded,
        title: 'Off'.tr,
        selected: selected.isEmpty,
        onTap: () => controller.setSpeculativeDraftModel(''),
      ),
      for (final f in drafts)
        AppRow(
          icon: Icons.bolt_rounded,
          title: f,
          subtitle: DownloadService.formatBytes(models.fileSizes[f]!),
          selected: selected == f,
          onTap: () => controller.setSpeculativeDraftModel(f),
        ),
      if (drafts.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
              'Download a small GGUF model (under 1.6 GB) to use it as a draft.'
                  .tr,
              style: t.small),
        ),
      if (selected.isNotEmpty && error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: AppNotice(
              'Not used with the current model: @reason'
                  .trParams({'reason': _draftReason(error)}),
              icon: Icons.info_outline_rounded),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text('Takes effect the next time a model is loaded.'.tr,
            style: t.small),
      ),
    ];
  }

  /// GPU backend for GGUF models: Vulkan, or llama.cpp's OpenCL backend
  /// tuned for Snapdragon (Adreno) GPUs.
  List<Widget> _buildGgufGpuApiRows(BuildContext context) {
    final t = AppTokens.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('GPU engine for GGUF models'.tr, style: t.label),
      ),
      AppRow(
        icon: Icons.layers_outlined,
        title: 'Vulkan (default)'.tr,
        subtitle: 'Works on most recent phones'.tr,
        selected: controller.ggufGpuApi.value == 'vulkan',
        onTap: () => controller.setGgufGpuApi('vulkan'),
      ),
      AppRow(
        icon: Icons.science_outlined,
        title: 'OpenCL · experimental'.tr,
        subtitle: "Qualcomm's path for Snapdragon 8 Gen 1 and later (Adreno "
                '730+), often faster there. Falls back to the CPU if it fails.'
            .tr,
        selected: controller.ggufGpuApi.value == 'opencl',
        onTap: () => controller.setGgufGpuApi('opencl'),
      ),
    ];
  }

  Widget _buildModelParametersGroup(BuildContext context) {
    return AppGroup(children: [
      _modelParameterSlider(
        context,
        label: 'Temperature'.tr,
        value: controller.temperature.value,
        min: 0.0,
        max: 2.0,
        divisions: 20,
        safeMax: 1.0,
        onChanged: (v) => controller.setTemperature(v),
        warning: 'High temperature = unpredictable output!'.tr,
      ),
      _modelParameterSlider(
        context,
        label: 'Max tokens'.tr,
        value: controller.maxTokens.value.toDouble(),
        min: 64,
        max: 4096,
        divisions: 63,
        safeMax: Get.find<DeviceInfoService>().maxSafeTokens.toDouble(),
        onChanged: (v) => controller.setMaxTokens(v.toInt()),
        displayValue: controller.maxTokens.value.toString(),
        warning: 'Your phone may crash with this value!'.tr,
      ),
      (() {
        final inference = Get.find<InferenceService>();
        final savedRuntime = Get.find<HiveService>()
                .getSetting<String>(AppConstants.keyLocalModelRuntime) ??
            '';
        final isLiteRtActive = (inference.isModelLoaded.value &&
                inference.loadedModelRuntime.value == 'litert') ||
            (!inference.isModelLoaded.value &&
                savedRuntime.toLowerCase() == 'litert');
        final maxContext = isLiteRtActive ? 4096.0 : 8192.0;
        final divisions = isLiteRtActive ? 7 : 15;
        final currentValue =
            controller.contextSize.value.toDouble().clamp(512.0, maxContext);

        if (currentValue != controller.contextSize.value.toDouble()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.setContextSize(currentValue.toInt());
          });
        }

        return _modelParameterSlider(
          context,
          label: 'Context size'.tr,
          value: currentValue,
          min: 512,
          max: maxContext,
          divisions: divisions,
          safeMax: Get.find<DeviceInfoService>().maxSafeContextSize.toDouble(),
          onChanged: (v) => controller.setContextSize(v.toInt()),
          displayValue: currentValue.toInt().toString(),
          warning: isLiteRtActive
              ? 'Context capped at 4096 to prevent driver memory crash for LiteRT models.'
                  .tr
              : 'Context this large will eat all your RAM!'.tr,
        );
      })(),
    ]);
  }

  Widget _modelParameterSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required double safeMax,
    required ValueChanged<double> onChanged,
    required String warning,
    String? displayValue,
  }) {
    final t = AppTokens.of(context);
    final isOver = value > safeMax;
    final danger = safeMax < max
        ? ((value - safeMax) / (max - safeMax)).clamp(0.0, 1.0)
        : 0.0;
    final warnColor = isOver ? Color.lerp(t.orange, t.red, danger)! : null;

    return _sliderRow(
      context,
      label: label,
      valueLabel: displayValue ?? value.toStringAsFixed(2),
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      color: warnColor,
      caption: safeMax < max
          ? 'Recommended max: @value'.trParams({
              'value': safeMax.toInt() > 0
                  ? safeMax.toInt().toString()
                  : safeMax.toStringAsFixed(1)
            })
          : null,
      onChanged: (v) {
        if (v > safeMax && value <= safeMax) {
          Haptics.heavyImpact();
          showToast('Above recommended'.tr, warning, tone: ToastTone.warning);
        } else if (v > safeMax) {
          Haptics.mediumImpact();
        }
        onChanged(v);
      },
      below: [
        if (isOver)
          AppNotice(warning,
              icon: Icons.warning_amber_rounded, color: warnColor),
      ],
    );
  }

  Widget _buildImageGenerationGroup(BuildContext context) {
    final t = AppTokens.of(context);
    final stepsValue = controller.imageSteps.value.toDouble();
    const safeMax = 8.0;
    final isOver = stepsValue > safeMax;
    final selectedBackend = controller.imageGenBackend.value;
    final gpuBackend = controller.recommendedImageGpuBackend();
    final gpuAvailable = gpuBackend != Backend.cpu;
    final size = controller.imageGenSize.value;
    final guard = controller.imageGenGpuGuardMb.value;

    return AppGroup(children: [
      // Steps
      _sliderRow(
        context,
        label: 'Steps'.tr,
        valueLabel: controller.imageSteps.value.toString(),
        value: stepsValue.clamp(1, 50),
        min: 1,
        max: 50,
        divisions: 49,
        color: isOver ? t.orange : null,
        caption: 'Recommended: 15-20 steps'.tr,
        onChanged: (v) => controller.setImageSteps(v.toInt()),
        below: [
          if (isOver)
            AppNotice('More steps = better quality but MUCH slower!'.tr,
                icon: Icons.warning_amber_rounded, color: t.orange),
        ],
      ),

      // Size
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Image size'.tr, style: t.body)),
            Text(size == 0 ? 'Auto'.tr : '${size}px',
                style: t.body.copyWith(color: t.muted, fontFeatures: _tabular)),
          ]),
          const SizedBox(height: 12),
          AppChips<int>(
            items: [
              (0, 'Auto'.tr),
              (256, '256'),
              (320, '320'),
              (384, '384'),
              (512, '512'),
            ],
            selected: size,
            onSelected: (v) => controller.setImageGenSize(v),
          ),
          const SizedBox(height: 10),
          Text(
              'Auto recommended. Bigger size = better detail, but much slower and more memory use.'
                  .tr,
              style: t.small),
          if (size >= 512) ...[
            const SizedBox(height: 10),
            AppNotice(
                '512 gives more detail but can be MUCH slower, heat the phone, and may fail on some devices.'
                    .tr,
                icon: Icons.warning_amber_rounded,
                color: t.orange),
          ],
        ]),
      ),

      // GPU safety
      _sliderRow(
        context,
        label: 'GPU safety'.tr,
        valueLabel: guard <= 0 ? 'Off'.tr : '@size MB'.trParams({'size': '$guard'}),
        value: guard.toDouble().clamp(0, 4096),
        min: 0,
        max: 4096,
        divisions: 16,
        caption:
            'Models at or above this size use CPU. Smaller models can use GPU Experimental.'
                .tr,
        onChanged: (v) => controller.setImageGenGpuGuardMb(v.toInt()),
        below: [
          if (guard <= 0 || guard >= 2048)
            AppNotice(
                guard <= 0
                    ? 'GPU Safety is off. Large models may crash or freeze on GPU.'
                        .tr
                    : 'High GPU Safety allows larger models on GPU and may crash, freeze, or overheat some phones.'
                        .tr,
                icon: Icons.warning_amber_rounded,
                color: t.orange),
        ],
      ),

      // Backend
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Backend'.tr, style: t.body),
          const SizedBox(height: 2),
          Text(controller.imageGpuLabel(), style: t.caption),
          const SizedBox(height: 12),
          AppSegmented<bool>(
            items: const [(false, 'CPU'), (true, 'GPU')],
            selected: selectedBackend != Backend.cpu,
            onChanged: (useGpu) {
              if (useGpu == (selectedBackend != Backend.cpu)) return;
              if (useGpu && !gpuAvailable) return;
              controller.setImageBackendMode(useGpu);
            },
          ),
          if (selectedBackend != Backend.cpu) ...[
            const SizedBox(height: 10),
            Text('GPU is experimental and only used below GPU Safety size.'.tr,
                style: t.small.copyWith(color: t.orange)),
          ],
        ]),
      ),
    ]);
  }
}

/// A settings section on its own page. Rebuilds with the controller state.
class _SettingsPage extends StatelessWidget {
  /// English title, translated on each build so the page follows a language
  /// change made on it.
  final String title;
  final WidgetBuilder builder;

  /// Rebuild on controller changes. Off for pages that read no observables
  /// (or manage their own Obx), which GetX would otherwise reject.
  final bool reactive;
  const _SettingsPage(
      {required this.title, required this.builder, this.reactive = true});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: title.tr, showBack: true),
      body: reactive ? Obx(() => _list(context)) : _list(context),
    );
  }

  Widget _list(BuildContext context) => ListView(
        padding: kPagePadding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [const SizedBox(height: 8), builder(context)],
      );
}
