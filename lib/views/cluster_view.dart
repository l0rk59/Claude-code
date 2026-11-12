import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/colors.dart';
import '../core/ui.dart';
import '../services/cluster_service.dart';

/// Phone cluster: pick Master (runs the model) or Worker (lends this phone),
/// and pair them by scanning the worker's QR code.
class ClusterView extends StatefulWidget {
  const ClusterView({super.key});

  @override
  State<ClusterView> createState() => _ClusterViewState();
}

class _ClusterViewState extends State<ClusterView> {
  final ClusterService cluster = Get.find<ClusterService>();
  Timer? _wifiTimer;

  @override
  void initState() {
    super.initState();
    cluster.refreshWorkerStatus();
    cluster.refreshWifiAddress();
    if (cluster.role == ClusterRole.master) cluster.relocateWorkers();
    // Pick up Wi-Fi being turned on while this screen is open.
    _wifiTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => cluster.refreshWifiAddress());
  }

  @override
  void dispose() {
    _wifiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Phone cluster'.tr, showBack: true),
      body: Obx(() {
        final role = cluster.role;
        return ListView(
          padding: kPagePadding,
          children: [
            const SizedBox(height: 8),
            AppSegmented<ClusterRole>(
              items: [
                (ClusterRole.off, 'Off'.tr),
                if (ClusterService.canBeMaster) (ClusterRole.master, 'Master'.tr),
                (ClusterRole.worker, 'Worker'.tr),
              ],
              selected: role,
              onChanged: cluster.setRole,
            ),
            const SizedBox(height: 16),
            if (role != ClusterRole.off && cluster.wifiAddress.value == null) ...[
              AppNotice(
                'Turn on Wi-Fi. All phones in the cluster must be on the same Wi-Fi network.'.tr,
                icon: Icons.wifi_off_rounded,
                color: t.orange,
              ),
              const SizedBox(height: 16),
            ],
            ...switch (role) {
              ClusterRole.off => _offSection(),
              ClusterRole.master => _masterSection(context),
              ClusterRole.worker => _workerSection(context),
            },
          ],
        );
      }),
    );
  }

  List<Widget> _offSection() => [
        AppNotice(
          ClusterService.canBeMaster
              ? 'Run models too big for one phone by sharing the work across '
                  'phones on the same Wi-Fi.\n\n'
                  'Master: the phone you chat on. It runs the model.\n'
                  'Worker: a phone that lends its memory to the master.'.tr
              : 'Help an Android phone running PrivateLM run models too big for '
                  'it alone: choose Worker, then scan this device\'s QR code '
                  'from that phone.'.tr,
          icon: Icons.hub_outlined,
        ),
      ];

  // ── Worker ─────────────────────────────────────────────────────────────

  List<Widget> _workerSection(BuildContext context) {
    final t = AppTokens.of(context);
    final s = cluster.worker.value;
    final qr = cluster.workerQrData;

    final Widget body;
    if (s.state == 'error') {
      body = _centered(context, [
        Icon(Icons.error_outline_rounded, size: 40, color: t.red),
        const SizedBox(height: 12),
        Text('Worker stopped'.tr, style: t.bodyStrong),
        const SizedBox(height: 4),
        Text(s.error ?? 'Unknown error'.tr, style: t.caption, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        PillButton(label: 'Try again'.tr, primary: true, onPressed: cluster.startWorker),
      ]);
    } else if (s.peer != null) {
      body = _centered(context, [
        _PulsingDot(color: t.green),
        const SizedBox(height: 14),
        Text('Sharing with master'.tr, style: t.bodyStrong.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(s.peer!, style: t.caption),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _Stat(label: 'Holding'.tr, value: _gb(s.heldMb))),
          Expanded(child: _Stat(label: 'Free at start'.tr, value: _gb(s.ramMb))),
          Expanded(child: _Stat(label: 'Memory speed'.tr, value: _gbs(s.bandwidth))),
        ]),
      ]);
    } else if (!s.running || qr == null) {
      body = _centered(context, [
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(height: 16),
        Text(s.running ? 'Waiting for Wi-Fi…'.tr : 'Measuring this phone…'.tr, style: t.caption),
      ]);
    } else {
      body = _centered(context, [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(data: qr, size: 220, padding: EdgeInsets.zero),
        ),
        const SizedBox(height: 16),
        Text('Scan this from the master phone'.tr, style: t.bodyStrong),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          StatusDot(t.green, size: 8),
          const SizedBox(width: 6),
          Text(
              'Ready · @address'
                  .trParams({'address': '${cluster.wifiAddress.value}'}),
              style: t.caption),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Stat(label: 'Free memory'.tr, value: _gb(s.ramMb))),
          Expanded(child: _Stat(label: 'Memory speed'.tr, value: _gbs(s.bandwidth))),
        ]),
      ]);
    }

    return [
      if (s.throttled) ...[
        AppNotice(
          'Android is slowing this worker down (slow cores only), which slows '
          'the whole cluster. Set PrivateLM\'s battery use to Unrestricted, '
          'then turn Worker off and on.'.tr,
          icon: Icons.speed_rounded,
          color: t.orange,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: PillButton(
            label: 'Set Unrestricted'.tr,
            primary: true,
            onPressed: LlamaCluster.requestBatteryUnrestricted,
          ),
        ),
        const SizedBox(height: 16),
      ],
      AppCard(padding: const EdgeInsets.fromLTRB(16, 24, 16, 20), child: body),
      SectionFootnote(ClusterService.workerStopsWithApp
          ? 'Keep this device plugged in, on the same Wi-Fi, with PrivateLM open: '
              'iOS pauses apps in the background. Close PrivateLM to stop sharing.'.tr
          : 'Keep this phone plugged in and on the same Wi-Fi, with PrivateLM '
              'open: the screen stays on while sharing, because Android slows '
              'background work. Set Phone cluster to Off to stop.'.tr),
    ];
  }

  Widget _centered(BuildContext context, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: children);

  // ── Master ─────────────────────────────────────────────────────────────

  List<Widget> _masterSection(BuildContext context) {
    final t = AppTokens.of(context);
    return [
      if (cluster.split.length > 1) ...[
        _SplitCard(shares: cluster.split),
        const SizedBox(height: 16),
      ],
      PrimaryButton(
        label: 'Scan a worker\'s QR code'.tr,
        icon: Icons.qr_code_scanner_rounded,
        onPressed: _scanQr,
      ),
      SectionHeader(
          'Workers (@count)'.trParams({'count': '${cluster.workers.length}'})),
      if (cluster.workers.isEmpty)
        AppGroup(children: [
          EmptyState(
            icon: Icons.devices_other_rounded,
            title: 'No workers yet'.tr,
            message: 'On each other phone, open Phone cluster, choose Worker, '
                'then scan the QR code it shows.'.tr,
          ),
        ])
      else
        AppGroup(dividerIndent: 60, children: [
          for (final w in cluster.workers)
            AppRow(
              icon: w.computer
                  ? Icons.laptop_mac_rounded
                  : Icons.smartphone_rounded,
              title: w.computer ? 'Computer'.tr : w.model ?? w.name,
              subtitle: [
                w.endpoint,
                if (w.ramMb != null)
                  w.computer
                      ? '@size given'.trParams({'size': _gb(w.ramMb!)})
                      : '@size free'.trParams({'size': _gb(w.ramMb!)}),
                if (w.bandwidth != null) _gbs(w.bandwidth!),
              ].join(' · '),
              trailing: IconButton(
                icon: Icon(Icons.close_rounded, color: t.muted),
                tooltip: 'Remove'.tr,
                onPressed: () => cluster.remove(w),
              ),
            ),
        ]),
      SectionFootnote(
        'Used the next time you load a GGUF model. If the model fits on this '
        'phone you can keep it here, which is faster. If it doesn\'t, the '
        'fastest phones get the biggest share and phones that aren\'t needed '
        'are left out.'.tr,
      ),
      SectionHeader('Other ways to add'.tr),
      Row(children: [
        PillButton(
          label: cluster.isScanning.value ? 'Searching…'.tr : 'Find nearby'.tr,
          icon: Icons.wifi_find_rounded,
          onPressed: cluster.isScanning.value ? null : cluster.scanNearby,
        ),
        const SizedBox(width: 10),
        PillButton(
          label: 'Enter IP'.tr,
          icon: Icons.keyboard_rounded,
          onPressed: () => _enterIp(context),
        ),
      ]),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: PillButton(
          label: 'Add a computer'.tr,
          icon: Icons.laptop_mac_rounded,
          onPressed: () => _addComputer(context),
        ),
      ),
      if (cluster.found.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppGroup(dividerIndent: 60, children: [
          for (final w in cluster.found)
            AppRow(
              icon: Icons.smartphone_rounded,
              title: w.model ?? w.name,
              subtitle: w.endpoint,
              trailing: PillButton(
                label: 'Add'.tr,
                primary: true,
                onPressed: () => _report(cluster.addFound(w)),
              ),
            ),
        ]),
      ],
    ];
  }

  Future<void> _scanQr() async {
    final code = await Get.to<String>(() => const _QrScanPage());
    if (code != null) await _report(cluster.addFromQr(code));
  }

  Future<void> _enterIp(BuildContext context) async {
    final ctrl = TextEditingController();
    final input = await showAppSheet<String>(
      context,
      title: 'Enter worker IP'.tr,
      subtitle: 'Shown under the worker\'s QR code'.tr,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: appInputDecoration(ctx,
                hint: '192.168.1.20:${LlamaCluster.defaultPort}'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Add'.tr, onPressed: () => Navigator.pop(ctx, ctrl.text)),
        ],
      ),
    );
    ctrl.dispose();
    if (input != null) await _report(cluster.addManual(input));
  }

  Future<void> _addComputer(BuildContext context) async {
    final added = await showAppSheet<bool>(
      context,
      title: 'Add a computer'.tr,
      subtitle:
          'A laptop or desktop on the same Wi-Fi can hold most of a big model.'
              .tr,
      builder: (_) => _AddComputer(cluster: cluster),
    );
    if (added == true) {
      showToast('Computer added'.tr,
          'Used the next time you load a GGUF model.'.tr,
          tone: ToastTone.success);
    }
  }

  Future<void> _report(Future<String?> adding) async {
    final error = await adding;
    if (error != null) {
      showToast('Couldn\'t add worker'.tr, error, tone: ToastTone.error);
    } else {
      showToast('Worker added'.tr, 'Used the next time you load a GGUF model.'.tr,
          tone: ToastTone.success);
    }
  }
}

String _gb(num mb) =>
    '@size GB'.trParams({'size': (mb / 1024).toStringAsFixed(1)});

/// Memory speed, e.g. "4.2 GB/s".
String _gbs(double bandwidth) =>
    '@size GB/s'.trParams({'size': bandwidth.toStringAsFixed(1)});

/// Adds a computer to the cluster: says what to run on it, checks that it
/// answers, then asks how much of its memory to use.
class _AddComputer extends StatefulWidget {
  final ClusterService cluster;
  const _AddComputer({required this.cluster});

  @override
  State<_AddComputer> createState() => _AddComputerState();
}

class _AddComputerState extends State<_AddComputer> {
  static const _command = 'ggml-rpc-server -H 0.0.0.0 -p ${LlamaCluster.defaultPort} -c';

  final _address = TextEditingController();
  final _memory = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Memory the computer reported, in MB; null until it has answered.
  int? _totalMb;

  @override
  void dispose() {
    _address.dispose();
    _memory.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _totalMb = null;
    });
    final result = await widget.cluster.inspectComputer(_address.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.error;
      final info = result.info;
      if (info != null) {
        _totalMb = info.totalMb;
        _memory.text = (info.suggestedMb / 1024).toStringAsFixed(1);
      }
    });
  }

  Future<void> _add() async {
    // "12,5" on a French keyboard.
    final gb = double.tryParse(_memory.text.trim().replaceAll(',', '.'));
    final totalMb = _totalMb ?? 0;
    if (gb == null || gb < 0.5) {
      setState(() => _error = 'Give it at least 0.5 GB.'.tr);
      return;
    }
    if (gb * 1024 > totalMb) {
      setState(() => _error = 'This computer only has @size.'
          .trParams({'size': _gb(totalMb)}));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.cluster
        .addComputer(_address.text, memoryMb: (gb * 1024).round());
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Widget _step(AppTokens t, int number, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text('$number',
                style: t.small.copyWith(
                    color: t.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final found = _totalMb != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _step(
          t,
          1,
          Text(
            'On the computer, download llama.cpp @release for its system (github.com/ggml-org/llama.cpp, Releases) and unzip it.'
                .trParams({'release': LlamaCluster.llamaCppRelease}),
            style: t.caption,
          ),
        ),
        _step(
          t,
          2,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('In that folder, open a terminal and run:'.tr,
                style: t.caption),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const SelectableText(
                _command,
                style: TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ]),
        ),
        _step(
          t,
          3,
          Text("Enter the computer's address on your Wi-Fi.".tr,
              style: t.caption),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _address,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: appInputDecoration(context,
              hint: '192.168.1.20:${LlamaCluster.defaultPort}'),
          onChanged: (_) {
            if (found) setState(() => _totalMb = null);
          },
          onSubmitted: (_) => _check(),
        ),
        if (found) ...[
          const SizedBox(height: 12),
          AppNotice(
            'The computer answers: it has @size of memory.'
                .trParams({'size': _gb(_totalMb!)}),
            icon: Icons.check_circle_rounded,
            color: t.green,
          ),
          const SizedBox(height: 14),
          AppField(
            label: 'Memory to give the cluster (GB)'.tr,
            helper:
                'Leave some for the computer itself. The more it gives, the bigger the models the cluster can hold.'
                    .tr,
            child: TextField(
              controller: _memory,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: appInputDecoration(context),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppNotice(_error!,
              icon: Icons.error_outline_rounded, color: t.red),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: found ? 'Add this computer'.tr : 'Check'.tr,
          busy: _busy,
          onPressed: _busy ? null : (found ? _add : _check),
        ),
        const SizedBox(height: 12),
        Text(
          'The connection has no password: only do this on a network you trust.'
              .tr,
          style: t.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// How the loaded model is spread across phones: a stacked bar and legend.
class _SplitCard extends StatelessWidget {
  final List<ClusterShare> shares;
  const _SplitCard({required this.shares});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final colors = [t.accent, t.green, t.orange, AppColors.violet, t.red];
    final total = shares.fold<double>(0, (a, s) => a + s.mb);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Loaded model'.tr, style: t.bodyStrong),
        const SizedBox(height: 2),
        Text(
            'Running on @count phones · @size'
                .trParams({'count': '${shares.length}', 'size': _gb(total)}),
            style: t.caption),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              for (var i = 0; i < shares.length; i++)
                Expanded(
                  flex: (shares[i].mb / total * 1000).round().clamp(1, 1000),
                  child: Container(
                    margin: EdgeInsets.only(right: i == shares.length - 1 ? 0 : 2),
                    color: colors[i % colors.length],
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < shares.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              StatusDot(colors[i % colors.length], size: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shares[i].isThisPhone
                      ? '@name (this phone)'.trParams({'name': shares[i].name})
                      : shares[i].name,
                  style: t.body,
                ),
              ),
              Text('${(shares[i].mb / total * 100).round()}%', style: t.bodyStrong),
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                child: Text(_gb(shares[i].mb), textAlign: TextAlign.right, style: t.caption),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(children: [
      Text(value, style: t.bodyStrong),
      const SizedBox(height: 2),
      Text(label, style: t.small, textAlign: TextAlign.center),
    ]);
  }
}

/// Live indicator for an active connection.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 24 + 32 * _c.value,
            height: 24 + 32 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            child: const Icon(Icons.hub_rounded, size: 14, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

/// Full-screen camera that returns the first QR code it reads.
class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final MobileScannerController _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final value = capture.barcodes
        .map((b) => b.rawValue ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _done = true;
    Get.back(result: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan worker QR code'.tr),
      ),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Text(
            'Point at the QR code on the worker phone'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ]),
    );
  }
}
