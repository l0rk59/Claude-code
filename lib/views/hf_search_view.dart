import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/model_controller.dart';
import '../core/constants.dart';
import '../core/ui.dart';
import '../services/device_info_service.dart';
import '../services/hive_service.dart';
import '../services/hf_search_service.dart';
import '../services/model_fit.dart';
import '../widgets/fit_badge.dart';

/// Search Hugging Face for GGUF models, see which files suit this phone,
/// and download one.
class HfSearchView extends StatefulWidget {
  /// Replaces the real service in tests.
  final HfSearchService? service;
  const HfSearchView({super.key, this.service});

  @override
  State<HfSearchView> createState() => _HfSearchViewState();
}

class _HfSearchViewState extends State<HfSearchView> {
  /// Model families worth a first search. Names, so not translated.
  static const _ideas = [
    'Qwen3.5',
    'Gemma 4',
    'LFM2.5',
    'Phi-4 mini',
    'SmolLM3',
    'Mistral',
    'DeepSeek',
  ];

  late final HfSearchService _service =
      widget.service ?? HfSearchService(token: savedHfToken);
  final _input = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  bool _failed = false;
  List<HfRepo> _results = const [];

  /// Number of the latest search, to drop answers that arrive late.
  int _search = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(value));
    // Keeps the clear button in step with the text.
    setState(() {});
  }

  void _pick(String idea) {
    _input.text = idea;
    _run(idea);
  }

  Future<void> _run(String value) async {
    _debounce?.cancel();
    final query = value.trim();
    final search = ++_search;
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _loading = false;
        _failed = false;
        _results = const [];
      });
      return;
    }
    setState(() {
      _query = query;
      _loading = true;
      _failed = false;
    });
    try {
      final results = await _service.search(query);
      if (!mounted || search != _search) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || search != _search) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Hugging Face', actions: [
        IconButton(
          tooltip: 'Hugging Face token'.tr,
          icon: Icon(
              (savedHfToken() ?? '').isEmpty
                  ? Icons.key_off_rounded
                  : Icons.key_rounded,
              color: t.muted),
          onPressed: () async {
            await showHfTokenSheet(context, _service);
            if (mounted) setState(() {});
          },
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _input,
            autofocus: true,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            onChanged: _onChanged,
            onSubmitted: _run,
            style: t.body,
            decoration: appInputDecoration(
              context,
              hint: 'Search a model'.tr,
              prefix: Icon(Icons.search_rounded, size: 20, color: t.muted),
              suffix: _input.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear'.tr,
                      icon: Icon(Icons.close_rounded, size: 18, color: t.muted),
                      onPressed: () {
                        _input.clear();
                        _run('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(child: _body(context, t)),
      ]),
    );
  }

  Widget _body(BuildContext context, AppTokens t) {
    if (_query.isEmpty) return _intro(context, t);
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: t.accent),
        ),
      );
    }
    if (_failed) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't reach Hugging Face".tr,
          message: 'Check your connection and try again.'.tr,
          action: PillButton(
            label: 'Try again'.tr,
            icon: Icons.refresh_rounded,
            onPressed: () => _run(_query),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return SingleChildScrollView(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No model found'.tr,
          message: 'Try a shorter name, such as "qwen" or "gemma".'.tr,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AppGroup(children: [
          for (final repo in _results)
            _RepoRow(repo: repo, onTap: () => _open(context, repo)),
        ]),
        SectionFootnote('Most downloaded first.'.tr),
      ],
    );
  }

  Widget _intro(BuildContext context, AppTokens t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Thousands of open models, straight from Hugging Face. Each file shows whether it suits this phone before you download it.'
              .tr,
          style: t.caption,
        ),
        const SizedBox(height: 18),
        Text('Ideas'.tr, style: t.label),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final idea in _ideas)
            PillButton(label: idea, onPressed: () => _pick(idea)),
        ]),
      ],
    );
  }

  void _open(BuildContext context, HfRepo repo) {
    FocusScope.of(context).unfocus();
    showAppSheet<void>(
      context,
      title: repo.name,
      subtitle: repo.owner,
      builder: (_) => _RepoFiles(repo: repo, service: _service),
    );
  }
}

/// "1,2 M", "505 k": short counts in the app's language.
String _compact(int count) =>
    NumberFormat.compact(locale: Get.locale?.languageCode).format(count);

/// One search result: the model, who published it, how popular it is.
class _RepoRow extends StatelessWidget {
  final HfRepo repo;
  final VoidCallback onTap;
  const _RepoRow({required this.repo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    Widget stat(IconData icon, int count) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: t.faint),
          const SizedBox(width: 3),
          Text(_compact(count), style: t.small),
        ]);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.name,
                    style: t.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(
                    child: Text(repo.owner,
                        style: t.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 10),
                  stat(Icons.download_rounded, repo.downloads),
                  const SizedBox(width: 10),
                  stat(Icons.favorite_rounded, repo.likes),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 22, color: t.faint),
        ]),
      ),
    );
  }
}

/// The files of one repository, each with its size, how it suits this phone,
/// and a download button.
class _RepoFiles extends StatefulWidget {
  final HfRepo repo;
  final HfSearchService service;
  const _RepoFiles({required this.repo, required this.service});

  @override
  State<_RepoFiles> createState() => _RepoFilesState();
}

class _RepoFilesState extends State<_RepoFiles> {
  late Future<HfRepoDetails> _details = widget.service.details(widget.repo.id);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return FutureBuilder<HfRepoDetails>(
      future: _details,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: t.accent),
              ),
            ),
          );
        }
        final details = snapshot.data;
        if (details == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppNotice(
                "Couldn't load this model's files. Check your connection and try again."
                    .tr,
                icon: Icons.cloud_off_rounded,
                color: t.red,
              ),
              const SizedBox(height: 14),
              Center(
                child: PillButton(
                  label: 'Try again'.tr,
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() {
                    _details = widget.service.details(widget.repo.id);
                  }),
                ),
              ),
            ],
          );
        }
        return _files(context, t, details);
      },
    );
  }

  Widget _files(BuildContext context, AppTokens t, HfRepoDetails details) {
    final models = details.models;
    final mmproj = details.mmproj;
    final ram = Get.find<DeviceInfoService>().totalRamGB.value;
    final recommended = details.recommended(ram);
    final blocked = !details.downloadable || !details.supported;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (details.gated && details.accessible == null) ...[
          AppNotice(
            'Its publisher asks you to accept a licence first. Accept it on huggingface.co/@repo with your account, then add your Hugging Face token here. The same model is often available from another publisher without one.'
                .trParams({'repo': widget.repo.id}),
            icon: Icons.lock_outline_rounded,
            color: t.orange,
          ),
          const SizedBox(height: 10),
          Center(
            child: PillButton(
              label: 'Add a token'.tr,
              icon: Icons.key_rounded,
              onPressed: () async {
                final saved = await showHfTokenSheet(context, widget.service);
                if (saved && mounted) {
                  setState(() {
                    _details = widget.service.details(widget.repo.id);
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 12),
        ] else if (details.gated && details.accessible == false) ...[
          AppNotice(
            "Your token doesn't open this model yet. Accept its licence on huggingface.co/@repo with the same account, then come back."
                .trParams({'repo': widget.repo.id}),
            icon: Icons.lock_outline_rounded,
            color: t.orange,
          ),
          const SizedBox(height: 12),
        ] else if (!details.supported) ...[
          AppNotice(
            "The app's engine can't run this kind of model yet (@kind)."
                .trParams({'kind': details.architecture}),
            icon: Icons.block_rounded,
            color: t.orange,
          ),
          const SizedBox(height: 12),
        ] else if (mmproj != null && models.isNotEmpty) ...[
          AppNotice(
            'Reads images: its vision file (@size) downloads with it.'
                .trParams({'size': HfSearchService.catalogSize(mmproj.bytes)}),
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 12),
        ],
        if (models.isEmpty)
          AppNotice(
            "No file the app can download here. Models split in several parts aren't supported yet."
                .tr,
          )
        else ...[
          // The file to take, so nobody has to know what "Q4_K_M" means.
          if (!blocked && recommended != null) ...[
            Container(
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: t.isDark ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(kCardRadius),
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.28), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Row(children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 14, color: t.accent),
                      const SizedBox(width: 6),
                      Text('Recommended for this phone'.tr,
                          style: t.small.copyWith(
                              color: t.accent, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  _FileRow(
                    repo: widget.repo,
                    file: recommended,
                    mmproj: mmproj,
                    fit: ModelFit.ideal,
                    primary: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else if (!blocked) ...[
            AppNotice(
              'None of these files runs comfortably on this phone.'.tr,
              icon: Icons.error_outline_rounded,
              color: t.orange,
            ),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
                'All sizes · @count'.trParams({'count': '${models.length}'}),
                style: t.label),
          ),
          AppGroup(dividerIndent: 14, children: [
            for (final file in models)
              _FileRow(
                repo: widget.repo,
                file: file,
                mmproj: mmproj,
                fit: modelFit(modelBytes: file.bytes, totalRamGb: ram),
                blocked: blocked,
              ),
          ]),
          SectionFootnote(
              'Bigger files answer better, but need more memory and run slower.'
                  .tr),
        ],
      ],
    );
  }
}

/// One downloadable file: "Q4_K_M · Runs well · 1.28 GB" and its action.
class _FileRow extends StatelessWidget {
  final HfRepo repo;
  final HfFile file;
  final HfFile? mmproj;
  final ModelFit fit;

  /// The suggested file: its download button stands out.
  final bool primary;

  /// The model can't be used (licence to accept, or unsupported): listed,
  /// but without a download button.
  final bool blocked;

  const _FileRow({
    required this.repo,
    required this.file,
    required this.mmproj,
    required this.fit,
    this.primary = false,
    this.blocked = false,
  });

  Future<void> _download(BuildContext context) async {
    final controller = Get.find<ModelController>();
    if (fit == ModelFit.tooBig) {
      final go = await confirmSheet(
        context,
        title: 'Too big for this phone'.tr,
        message:
            'This file needs more memory than this phone has, so it will probably not load. Download it anyway?'
                .tr,
        confirmLabel: 'Download'.tr,
      );
      if (!go) return;
    }
    final model = await controller
        .addFromHub(HfSearchService.toModel(repo, file, mmproj: mmproj));
    showToast(
      'Download started'.tr,
      '@name is in My models once it is ready.'.trParams({'name': model.name}),
      tone: ToastTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final controller = Get.find<ModelController>();
    final title = file.quant.isEmpty ? file.basename : file.quant;
    final model = HfSearchService.toModel(repo, file, mmproj: mmproj);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: t.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(children: [
                  if (fit != ModelFit.unknown)
                    TextSpan(
                      text: '${FitBadge.label(fit)} · ',
                      style: TextStyle(
                          color: FitBadge.color(fit, t),
                          fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: HfSearchService.catalogSize(file.bytes)),
                ]),
                style: t.small.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (!blocked)
          Obx(() {
            // The catalogue may already list this file under another
            // name: follow that entry, or it would download twice.
            final filename = (controller.listed(model) ?? model).filename;
            if (controller.isDownloaded(filename)) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: t.green),
                  const SizedBox(width: 5),
                  Text('On this phone'.tr,
                      style: t.small.copyWith(color: t.green)),
                ]),
              );
            }
            final progress = controller.activeDownloads[filename];
            if (progress != null) {
              final percent =
                  (progress.progress.value * 100).clamp(0.0, 100.0).round();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('$percent%',
                    style: t.bodyStrong.copyWith(
                        color: t.accent,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              );
            }
            return PillButton(
              label: 'Download'.tr,
              icon: Icons.download_rounded,
              primary: primary,
              onPressed: () => _download(context),
            );
          }),
      ]),
    );
  }
}

/// The user's Hugging Face token, or null.
String? savedHfToken() => Get.isRegistered<HiveService>()
    ? Get.find<HiveService>().getSetting<String>(AppConstants.keyHfToken)
    : null;

/// Lets the user add, check or remove their Hugging Face token. Returns
/// true when a token was saved.
Future<bool> showHfTokenSheet(
    BuildContext context, HfSearchService service) async {
  final saved = await showAppSheet<bool>(
    context,
    title: 'Hugging Face token'.tr,
    subtitle:
        'Opens the models whose publisher asks to accept a licence (Gemma, Llama…). Stored in the phone\'s keystore, sent only to Hugging Face.'
            .tr,
    builder: (_) => HfTokenSheet(
      service: service,
      current: savedHfToken() ?? '',
      save: (token) async {
        if (Get.isRegistered<HiveService>()) {
          await Get.find<HiveService>().setSetting(
              AppConstants.keyHfToken, token.isEmpty ? null : token);
        }
      },
    ),
  );
  return saved == true;
}

/// Enters and checks a Hugging Face token. Pops with true once one is
/// saved, false once it is removed.
class HfTokenSheet extends StatefulWidget {
  final HfSearchService service;
  final String current;
  final Future<void> Function(String token) save;

  const HfTokenSheet({
    super.key,
    required this.service,
    required this.current,
    required this.save,
  });

  @override
  State<HfTokenSheet> createState() => _HfTokenSheetState();
}

class _HfTokenSheetState extends State<HfTokenSheet> {
  late final _token = TextEditingController(text: widget.current);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final token = _token.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Paste your token first.'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await widget.service.whoAmI(token);
      if (!mounted) return;
      if (account == null) {
        setState(() {
          _busy = false;
          _error = 'Hugging Face refuses this token. Copy it again from huggingface.co/settings/tokens.'
              .tr;
        });
        return;
      }
      await widget.save(token);
      if (!mounted) return;
      showToast('Token saved'.tr,
          'Connected as @name.'.trParams({'name': account}),
          tone: ToastTone.success);
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't reach Hugging Face".tr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create one with "Read" access on huggingface.co/settings/tokens, then paste it here.'
              .tr,
          style: t.caption,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: appInputDecoration(context, hint: 'hf_…'),
          onSubmitted: (_) => _check(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppNotice(_error!, icon: Icons.error_outline_rounded, color: t.red),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Check and save'.tr,
          busy: _busy,
          onPressed: _busy ? null : _check,
        ),
        if (widget.current.isNotEmpty) ...[
          const SizedBox(height: 10),
          TonalButton.destructive(
            context,
            label: 'Remove the token'.tr,
            onTap: () async {
              await widget.save('');
              if (context.mounted) Navigator.pop(context, false);
            },
          ),
        ],
      ],
    );
  }
}
