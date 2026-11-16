import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/model_controller.dart';
import '../core/app_dirs.dart';
import '../core/constants.dart';
import '../core/ui.dart';
import '../services/desktop/desktop_engine_service.dart';
import '../services/desktop/llama_engine.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/rpc_probe.dart';
import '../core/format.dart';

/// The computer app's engine: which build runs the models, where the
/// models are kept, sharing with the phones, phones lending their memory.
class DesktopEngineView extends StatefulWidget {
  const DesktopEngineView({super.key});

  @override
  State<DesktopEngineView> createState() => _DesktopEngineViewState();
}

class _DesktopEngineViewState extends State<DesktopEngineView> {
  DesktopEngineService get _engine => Get.find<DesktopEngineService>();
  HiveService get _hive => Get.find<HiveService>();

  String _modelsDir = '';
  String _shareKey = '';
  List<String> _addresses = const [];
  final Map<String, RpcServerInfo?> _workerInfo = {};
  bool _scanning = false;
  double _scanProgress = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final dir = await AppDirs.models();
    final key = await _engine.shareKey();
    final addresses = await DesktopEngineService.localAddresses();
    if (!mounted) return;
    setState(() {
      _modelsDir = dir;
      _shareKey = key;
      _addresses = addresses;
    });
    for (final w in _engine.savedWorkers) {
      unawaited(_probe(w));
    }
  }

  Future<void> _probe(String endpoint) async {
    final info = await DesktopEngineService.probeWorker(endpoint);
    if (mounted) setState(() => _workerInfo[endpoint] = info);
  }

  /// Settings that only apply at the next load: offers to reload now.
  Future<void> _reloadIfLoaded() async {
    final inference = Get.find<InferenceService>();
    final name = inference.loadedModelName.value;
    if (!inference.isModelLoaded.value || name.isEmpty) return;
    showToast('Reloading the model'.tr, 'The change applies now.'.tr);
    await Get.find<ModelController>().loadModel(name, confirm: false);
  }

  Future<void> _install(EngineVariant v) async {
    try {
      await _engine.install(v);
      showToast('Engine ready'.tr, v.title, tone: ToastTone.success);
      await _reloadIfLoaded();
    } catch (e) {
      showToast("The engine couldn't be downloaded".tr, '$e',
          tone: ToastTone.error, duration: const Duration(seconds: 6));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickVariant() async {
    final context = this.context;
    final chosen = await showAppSheet<EngineVariant>(
      context,
      title: 'Engine'.tr,
      subtitle:
          'Downloaded once from the official llama.cpp releases (@release).'
              .trParams({'release': LlamaEngine.release}),
      builder: (ctx) => AppGroup(dividerIndent: 16, children: [
        for (final v in _engine.variants)
          AppRow(
            title: v.title,
            subtitle: '${v.description} · ${'@size MB'.trParams({
                  'size': '${v.downloadMb}'
                })}',
            selected: v.id == _engine.installedVariant.value,
            trailing: v.id == _engine.installedVariant.value
                ? Icon(Icons.check_rounded, color: AppTokens.of(ctx).accent)
                : null,
            onTap: () => Navigator.of(ctx).pop(v),
          ),
      ]),
    );
    if (chosen == null) return;
    await _engine.chooseVariant(chosen);
    if (_engine.installedVariant.value.isEmpty) {
      await _install(chosen);
    } else {
      await _reloadIfLoaded();
      if (mounted) setState(() {});
    }
  }

  Future<void> _useOwnServer() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose llama-server'.tr,
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!baseName(path).toLowerCase().startsWith('llama-server')) {
      showToast('Not llama-server'.tr,
          'Choose the llama-server program from a llama.cpp folder.'.tr,
          tone: ToastTone.warning);
      return;
    }
    await _engine.useCustomBinary(path);
    await _reloadIfLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _pickModelsDir() async {
    final dir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Folder for the models'.tr);
    if (dir == null) return;
    await _hive.setSetting(AppConstants.keyModelsDir, dir);
    AppDirs.modelsOverride = dir;
    await Get.find<ModelController>().refreshDownloaded();
    await _refresh();
  }

  Future<void> _resetModelsDir() async {
    await _hive.setSetting(AppConstants.keyModelsDir, '');
    AppDirs.modelsOverride = null;
    await Get.find<ModelController>().refreshDownloaded();
    await _refresh();
  }

  Future<void> _setSharing(bool on) async {
    await _engine.setSharing(on);
    setState(() {});
    await _reloadIfLoaded();
  }

  Future<void> _newKey() async {
    await _hive.setSetting(
        AppConstants.keyDesktopShareKey, DesktopEngineService.newKey());
    await _refresh();
    if (_engine.sharing.value) await _reloadIfLoaded();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });
    final found = await DesktopEngineService.scanWorkers(
        onProgress: (p) => mounted ? setState(() => _scanProgress = p) : null);
    if (!mounted) return;
    final saved = _engine.savedWorkers;
    final added = [
      for (final (endpoint, info) in found)
        if (!saved.contains(endpoint) && info.compatible) endpoint,
    ];
    await _engine.saveWorkers([...saved, ...added]);
    for (final (endpoint, info) in found) {
      _workerInfo[endpoint] = info;
    }
    setState(() => _scanning = false);
    showToast(
      'Search finished'.tr,
      added.isEmpty
          ? 'No new phone in Worker mode found. Check that they are on the same network, with Worker mode on.'
              .tr
          : '@count phones added.'.trParams({'count': '${added.length}'}),
    );
  }

  Future<void> _addWorker() async {
    final endpoint = await showAppSheet<String>(
      context,
      title: 'Add a phone'.tr,
      subtitle:
          'The address shown by the phone in Worker mode (Cluster screen), for example 192.168.1.20.'
              .tr,
      builder: (ctx) => const _AddressField(),
    );
    if (endpoint == null) return;
    final normalized = DesktopEngineService.workerEndpoint(endpoint);
    if (normalized == null) {
      showToast('Address not understood'.tr, endpoint, tone: ToastTone.warning);
      return;
    }
    if (!_engine.savedWorkers.contains(normalized)) {
      await _engine.saveWorkers([..._engine.savedWorkers, normalized]);
    }
    setState(() {});
    unawaited(_probe(normalized));
  }

  Future<void> _removeWorker(String endpoint) async {
    await _engine
        .saveWorkers(_engine.savedWorkers.where((w) => w != endpoint).toList());
    setState(() => _workerInfo.remove(endpoint));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Computer engine'.tr),
      body: PageWidth(
          child: ListView(
        padding: kPagePadding,
        children: [
          Text(
            'On this computer, the models run in llama.cpp, the engine of the phones, using the graphics card when there is one.'
                .tr,
            style: t.caption,
          ),
          SectionHeader('Engine'.tr),
          Obx(() {
            final installed = _engine.installedVariant.value;
            final installing = _engine.installing.value;
            final gpu = _engine.mainGpu;
            final variant =
                _engine.variants.firstWhereOrNull((v) => v.id == installed);
            return AppGroup(dividerIndent: 16, children: [
              AppRow(
                icon: Icons.memory_rounded,
                title: installed.isEmpty
                    ? 'Not installed yet'.tr
                    : installed == 'custom'
                        ? 'Your llama-server'.tr
                        : variant?.title ?? installed,
                subtitle: installing
                    ? _engine.installStatus.value
                    : installed.isEmpty
                        ? 'Downloaded with the first model (@size MB).'
                            .trParams(
                                {'size': '${_engine.chosenVariant.downloadMb}'})
                        : installed == 'custom'
                            ? _engine.customBinary
                            : 'llama.cpp @release'
                                .trParams({'release': LlamaEngine.release}),
                trailing: installing
                    ? SizedBox(
                        width: 80,
                        child: AppProgressBar(
                            value: _engine.installProgress.value))
                    : null,
                chevron: !installing,
                onTap: installing ? null : _pickVariant,
              ),
              AppRow(
                icon: Icons.developer_board_rounded,
                title: gpu == null ? 'No graphics card found'.tr : gpu.name,
                subtitle: gpu == null
                    ? (installed.isEmpty
                        ? 'Known once the engine is installed.'.tr
                        : 'The models run on the processor.'.tr)
                    : '@total GB of graphics memory, @free GB free'.trParams({
                        'total': decimal(gpu.totalMb / 1024, 1),
                        'free': decimal(gpu.freeMb / 1024, 1),
                      }),
              ),
              if (installed.isEmpty && !installing)
                AppRow(
                  icon: Icons.download_rounded,
                  title: 'Install now'.tr,
                  subtitle: _engine.chosenVariant.title,
                  onTap: () => _install(_engine.chosenVariant),
                ),
              AppRow(
                icon: Icons.folder_open_rounded,
                title: 'Use my own llama-server'.tr,
                subtitle:
                    'For a build made for your card (ROCm, SYCL…). The same version is safest for the phones.'
                        .tr,
                onTap: _useOwnServer,
              ),
            ]);
          }),
          SectionHeader('Models folder'.tr),
          AppGroup(dividerIndent: 16, children: [
            AppRow(
              icon: Icons.folder_rounded,
              title: _modelsDir,
              subtitle:
                  'Models downloaded or added from now on go here. Models already in the old folder stay there.'
                      .tr,
              chevron: true,
              onTap: _pickModelsDir,
            ),
            if ((_hive.getSetting<String>(AppConstants.keyModelsDir) ?? '')
                .isNotEmpty)
              AppRow(
                icon: Icons.restart_alt_rounded,
                title: 'Back to the default folder'.tr,
                onTap: _resetModelsDir,
              ),
          ]),
          SectionHeader('Share with my phones'.tr),
          Obx(() {
            final on = _engine.sharing.value;
            return AppGroup(dividerIndent: 16, children: [
              AppRow(
                icon: Icons.share_rounded,
                title: 'Phones of the network use this model'.tr,
                subtitle:
                    'They find this computer in Models > Cloud > A computer on your network, and ask for the key below.'
                        .tr,
                trailing: Switch(value: on, onChanged: _setSharing),
                onTap: () => _setSharing(!on),
              ),
              if (on) ...[
                AppRow(
                  icon: Icons.lan_rounded,
                  title: _addresses.isEmpty
                      ? 'No local network found'.tr
                      : _addresses
                          .map((a) => '$a:${DesktopEngineService.sharePort}')
                          .join('  ·  '),
                  subtitle: 'Address of this computer'.tr,
                ),
                AppRow(
                  icon: Icons.key_rounded,
                  title: _shareKey,
                  subtitle: 'Key to type on the phones'.tr,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Copy'.tr,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _shareKey));
                        showToast('Copied'.tr, _shareKey);
                      },
                    ),
                    IconButton(
                      tooltip: 'New key'.tr,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: _newKey,
                    ),
                  ]),
                ),
              ],
            ]);
          }),
          if (_engine.sharing.value)
            SectionFootnote(
                'Your firewall may ask whether llama-server can accept connections: allow it on private networks only.'
                    .tr),
          SectionHeader('Phones lending their memory'.tr),
          AppGroup(dividerIndent: 16, children: [
            AppRow(
              icon: Icons.hub_rounded,
              title: 'Use the phones in Worker mode'.tr,
              subtitle:
                  'For models too big for this computer: llama.cpp spreads the model over this computer and the phones. Slower than one machine: the network carries every step.'
                      .tr,
              trailing: Switch(
                value: _engine.clusterOn,
                onChanged: (v) async {
                  await _engine.setClusterOn(v);
                  setState(() {});
                },
              ),
            ),
            for (final w in _engine.savedWorkers)
              AppRow(
                icon: Icons.smartphone_rounded,
                title: w,
                subtitle: !_workerInfo.containsKey(w)
                    ? 'Checking…'.tr
                    : _workerInfo[w] == null
                        ? 'Not reachable now'.tr
                        : !_workerInfo[w]!.compatible
                            ? 'Engine version @version: update the app on this phone'
                                .trParams({'version': _workerInfo[w]!.version})
                            : 'Lends about @gb GB'.trParams({
                                'gb': decimal(
                                    _workerInfo[w]!.suggestedMb / 1024, 1)
                              }),
                trailing: IconButton(
                  tooltip: 'Remove'.tr,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _removeWorker(w),
                ),
              ),
            AppRow(
              icon: Icons.radar_rounded,
              title: _scanning
                  ? 'Searching the network… @percent%'
                      .trParams({'percent': '${(_scanProgress * 100).round()}'})
                  : 'Find phones on the network'.tr,
              onTap: _scanning ? null : _scan,
            ),
            AppRow(
              icon: Icons.add_rounded,
              title: 'Add a phone by its address'.tr,
              onTap: _addWorker,
            ),
          ]),
          SectionFootnote(
              'On each phone: Cluster > Worker. Changes apply when a model is next loaded.'
                  .tr),
        ],
      )),
    );
  }
}

/// The address field of "Add a phone" (owns its text controller, so it
/// lives as long as the sheet).
class _AddressField extends StatefulWidget {
  const _AddressField();

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: appInputDecoration(context, hint: '192.168.1.20:50052'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Add'.tr,
            icon: Icons.add_rounded,
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      );
}
