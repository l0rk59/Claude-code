import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/model_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/colors.dart';
import '../core/haptics.dart';
import '../core/ui.dart';
import '../models/ai_model.dart';
import '../services/device_info_service.dart';
import '../services/download_service.dart';
import '../services/inference_service.dart';
import '../services/local_image_service.dart';
import 'fit_badge.dart';

/// The chat before its first message: a greeting, and under it whatever
/// gets the user talking fastest — a one-tap install on first launch, the
/// last model to load again, or prompt suggestions once a model is ready.
/// The model itself is named in the pill at the top of the chat.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Keep a readable column on tablets / desktop.
      final hPad = box.maxWidth > 640 ? (box.maxWidth - 600) / 2 : 20.0;
      // While typing, drop everything but the greeting so nothing gets
      // clipped behind the composer.
      final typing = View.of(context).viewInsets.bottom > 0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 20),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const SizedBox(height: 24),
                _Greeting(compact: typing),
                const SizedBox(height: 28),
                const Spacer(),
                if (!typing) const _NextStep(),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Picks the block under the greeting from the app's state.
class _NextStep extends StatelessWidget {
  const _NextStep();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<SettingsController>();
      final models = Get.find<ModelController>();
      final inf = Get.find<InferenceService>();
      final img = Get.find<LocalImageService>();
      if (settings.inferenceMode.value != 'local') {
        return settings.selectedCloudModelName.isEmpty
            ? const _PickCloudModel()
            : const _Starters();
      }
      if (inf.isModelLoaded.value ||
          img.isModelLoaded.value ||
          inf.isLoadingModel.value ||
          img.isLoadingModel.value) {
        return const _Starters();
      }
      // Still installing the first model, or nothing on the phone yet.
      final installing = models.autoLoadAfterDownload.value.isNotEmpty;
      if (models.downloadedCount == 0 || installing) return const _FirstRun();
      return const _Resume();
    });
  }
}

// ── Greeting ────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final bool compact;
  const _Greeting({this.compact = false});

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 5) return 'Up late?'.tr;
    if (h < 12) return 'Good morning,'.tr;
    if (h < 17) return 'Good afternoon,'.tr;
    return 'Good evening,'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(children: [
      if (!compact) ...[
        // The logo on a soft halo of the brand colour.
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.violet.withValues(alpha: t.isDark ? 0.30 : 0.18),
              AppColors.violet.withValues(alpha: 0),
            ]),
          ),
          alignment: Alignment.center,
          child: Image.asset('assets/icons/appicon.png', width: 46, height: 46),
        ),
        const SizedBox(height: 12),
      ],
      Text(
        "@salutation\nwhat's on your mind?"
            .trParams({'salutation': _salutation}),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: compact ? 24 : 28,
          height: 1.25,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.8,
          color: t.text,
        ),
      ),
    ]);
  }
}

String providerLabel(SettingsController s) {
  switch (s.cloudProvider.value) {
    case 'openai':
      return 'OpenAI';
    case 'anthropic':
      return 'Anthropic';
    case 'google':
      return 'Google';
    case 'stability':
      return 'Stability AI';
    case 'nvidia':
      return 'NVIDIA';
    case 'openrouter':
      return 'OpenRouter';
    case 'deepseek':
      return 'DeepSeek';
    case 'kimi':
      return 'Kimi';
    case 'custom':
      final n = s.customCloudName.value.trim();
      return n.isEmpty ? 'a custom endpoint'.tr : n.tr;
    default:
      return 'the cloud'.tr;
  }
}

String _prettyModel(String name) => name.replaceAll(
    RegExp(r'\.(gguf|litertlm|task|bin)$', caseSensitive: false), '');

// ── First launch: one-tap install ───────────────────────────────────────

/// Nothing on the phone yet: suggests the model that suits this phone and
/// installs it in one tap (download, then load).
class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final models = Get.find<ModelController>();
    final home = Get.find<HomeController>();
    final ram = Get.find<DeviceInfoService>().totalRamGB.value;
    return Obx(() {
      final model = models.availableModels.firstWhereOrNull(
              (m) => m.filename == models.autoLoadAfterDownload.value) ??
          models.starterModel;
      if (model == null) return const _PickLocalModel();
      final progress = models.getDownloadProgress(model.filename);
      final downloading = progress != null;

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: t.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Recommended for this phone'.tr,
                    style: t.label.copyWith(color: t.accent)),
              ),
              Text('@ram GB RAM'.trParams({'ram': ram.toStringAsFixed(0)}),
                  style: t.small),
            ]),
            const SizedBox(height: 10),
            Text(_cleanName(model),
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: t.text)),
            const SizedBox(height: 4),
            Text(model.description.tr, style: t.caption),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              FitBadge(models.fitOf(model)),
              AppTag(models.modelSizeLabel(model),
                  icon: Icons.sd_storage_outlined),
              if (model.hasVisionProjector)
                AppTag('Vision'.tr, icon: Icons.visibility_outlined),
            ]),
            const SizedBox(height: 16),
            if (downloading)
              _InstallProgress(
                  progress: progress,
                  onCancel: () => models.cancelInstall(model))
            else
              PrimaryButton(
                label: 'Install and start'.tr,
                icon: Icons.download_rounded,
                onPressed: () {
                  Haptics.lightImpact();
                  models.installAndLoad(model);
                },
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TonalButton.neutral(context,
                label: 'Other models'.tr,
                onTap: () => home.openModels(scope: 'browse')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TonalButton.neutral(context,
                label: 'Use the cloud'.tr,
                onTap: () => home.openModels(scope: 'online')),
          ),
        ]),
        const SizedBox(height: 12),
        Text('Runs on this device. No account, no server.'.tr,
            textAlign: TextAlign.center, style: t.small),
      ]);
    });
  }

  /// "Qwen 3.5 2B (Q4_K_M)" → "Qwen 3.5 2B".
  static String _cleanName(AiModel model) =>
      model.name.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '');
}

class _InstallProgress extends StatelessWidget {
  final DownloadProgress progress;
  final VoidCallback onCancel;
  const _InstallProgress({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Obx(() {
      final value = progress.progress.value;
      final speed = progress.bytesPerSecond.value;
      final status = [
        'Downloading'.tr,
        '${(value * 100).clamp(0, 100).round()}%',
        if (speed > 0) DownloadService.formatSpeed(speed),
      ].join(' · ');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppProgressBar(value: value > 0 ? value : null),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(status, style: t.caption)),
          PillButton(label: 'Cancel'.tr, onPressed: onCancel),
        ]),
      ]);
    });
  }
}

/// Fallback when the catalogue has no starter model.
class _PickLocalModel extends StatelessWidget {
  const _PickLocalModel();

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: 'Browse models'.tr,
        icon: Icons.layers_outlined,
        onPressed: () => Get.find<HomeController>().openModels(scope: 'browse'),
      );
}

/// Cloud mode without a model picked yet.
class _PickCloudModel extends StatelessWidget {
  const _PickCloudModel();

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: 'Choose a cloud model'.tr,
        icon: Icons.cloud_outlined,
        onPressed: () => Get.find<HomeController>().openModels(scope: 'online'),
      );
}

// ── Models on the phone, none loaded ────────────────────────────────────

/// Offers to load the last model again, or to pick another one.
class _Resume extends StatelessWidget {
  const _Resume();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final models = Get.find<ModelController>();
    final home = Get.find<HomeController>();
    return Obx(() {
      final last = models.canLoadLastModel ? models.lastLoadedModelName : '';
      final name = last.isNotEmpty
          ? last
          : models.availableModels
                  .firstWhereOrNull((m) => models.isDownloaded(m.filename))
                  ?.filename ??
              '';
      if (name.isEmpty) return const _PickLocalModel();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PrimaryButton(
          label: 'Load @name'.trParams({'name': _prettyModel(name)}),
          icon: Icons.play_arrow_rounded,
          onPressed: () {
            Haptics.lightImpact();
            models.loadModel(name);
          },
        ),
        const SizedBox(height: 10),
        TonalButton.neutral(context,
            label: 'Choose another model'.tr,
            onTap: () => home.openModels(scope: 'local')),
        const SizedBox(height: 12),
        Text(
            last.isNotEmpty
                ? 'The model you used last time.'.tr
                : 'A model has to be loaded before you can chat.'.tr,
            textAlign: TextAlign.center,
            style: t.small),
      ]);
    });
  }
}

// ── Starters ────────────────────────────────────────────────────────────

/// A suggested first message. [label] and [prompt] are English and shown or
/// sent translated.
class _Starter {
  final IconData icon;
  final String label;
  final String prompt;
  const _Starter(this.icon, this.label, this.prompt);
}

const _textStarters = [
  _Starter(Icons.lightbulb_outline_rounded, 'Explain quantum computing simply',
      'Explain quantum computing simply, like I\'m new to it.'),
  _Starter(Icons.mail_outline_rounded, 'Write a polite follow-up email',
      'Write a short, polite follow-up email to someone who hasn\'t replied in a week.'),
  _Starter(Icons.flight_takeoff_rounded, 'Plan a 3-day trip to Tokyo',
      'Plan a relaxed 3-day trip to Tokyo with food and sightseeing.'),
];

const _imageStarters = [
  _Starter(Icons.landscape_outlined, 'A mountain lake at golden hour',
      'Mountain lake at golden hour, wide shot, photorealistic'),
  _Starter(Icons.person_outline_rounded, 'A portrait in soft studio light',
      'Portrait of a person, soft studio lighting, 85mm, detailed'),
  _Starter(Icons.brush_outlined, 'A flat editorial illustration',
      'Flat editorial illustration of a city street, muted palette'),
];

/// Tappable prompt suggestions; sends right away.
class _Starters extends StatelessWidget {
  const _Starters();

  void _use(_Starter s) {
    Haptics.selectionClick();
    final chat = Get.find<ChatController>();
    final prompt = s.prompt.tr;
    chat.textController.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    chat.inputText.value = prompt;
    chat.sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Obx(() {
      final inf = Get.find<InferenceService>();
      final img = Get.find<LocalImageService>();
      final isLocal =
          Get.find<SettingsController>().inferenceMode.value == 'local';
      final imageMode =
          isLocal && img.isModelLoaded.value && !inf.isModelLoaded.value;
      final items = imageMode ? _imageStarters : _textStarters;

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: t.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.hairline, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _use(s),
                splashFactory: NoSplash.splashFactory,
                highlightColor: t.surfacePressed,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(children: [
                    IconBadge(s.icon, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.label.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body),
                    ),
                    Icon(Icons.north_east_rounded, size: 16, color: t.faint),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
