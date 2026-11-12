import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/ui.dart';
import '../services/lan_server_finder.dart';

/// Finds the computers of the Wi-Fi that run a model (llama.cpp, Ollama,
/// LM Studio) and lets the user pick one of their models to chat with.
///
/// The computer does the work, so the model can be far bigger than a phone
/// could hold, and nothing leaves the local network. Pops with true once
/// [onConnect] has run.
class ComputerFinderSheet extends StatefulWidget {
  /// Called with the computer and the model the user picked.
  final Future<void> Function(LanServer server, String model) onConnect;

  /// Looks for computers on the network. Replaced in tests.
  final Future<List<LanServer>> Function(
      void Function(double progress) onProgress,
      bool Function() cancelled)? scan;

  /// Tries the address the user typed. Replaced in tests.
  final Future<List<LanServer>> Function(String input)? find;

  const ComputerFinderSheet({
    super.key,
    required this.onConnect,
    this.scan,
    this.find,
  });

  @override
  State<ComputerFinderSheet> createState() => _ComputerFinderSheetState();
}

class _ComputerFinderSheetState extends State<ComputerFinderSheet> {
  final _address = TextEditingController();
  final _servers = <LanServer>[];
  bool _scanning = false;
  bool _checking = false;
  bool _connecting = false;
  double _progress = 0;

  /// The phone has no Wi-Fi address: there is no network to search.
  bool _noWifi = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<List<LanServer>> _defaultScan(
      void Function(double) onProgress, bool Function() cancelled) async {
    final own = await LanServerFinder.ownAddress();
    if (own == null) {
      if (mounted) setState(() => _noWifi = true);
      return const [];
    }
    return LanServerFinder.scan(LanServerFinder.neighbours(own),
        onProgress: onProgress, cancelled: cancelled);
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _noWifi = false;
      _error = null;
      _progress = 0;
    });
    final found = await (widget.scan ?? _defaultScan)((progress) {
      if (mounted) setState(() => _progress = progress);
    }, () => !mounted);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _add(found);
    });
  }

  void _add(List<LanServer> found) {
    for (final server in found) {
      _servers.removeWhere((s) => s.address == server.address);
      _servers.add(server);
    }
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    final found = await (widget.find ?? LanServerFinder.find)(_address.text);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (found.isEmpty) {
        _error =
            'No model server answers there. Check the address, that the program is running on the computer, and that it accepts connections from the network.'
                .tr;
      } else {
        _add(found);
      }
    });
  }

  Future<void> _connect(LanServer server, String model) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    await widget.onConnect(server, model);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_scanning) ...[
          Text('Looking on your Wi-Fi…'.tr, style: t.caption),
          const SizedBox(height: 8),
          AppProgressBar(value: _progress, color: t.accent),
          const SizedBox(height: 16),
        ] else if (_servers.isEmpty) ...[
          AppNotice(
            _noWifi
                ? 'This phone is not on a Wi-Fi network. Connect it to the same Wi-Fi as the computer.'
                    .tr
                : 'No computer found. On the computer, start llama-server, Ollama or LM Studio and let it accept connections from the network, then search again.'
                    .tr,
            icon: Icons.wifi_find_rounded,
          ),
          const SizedBox(height: 14),
        ],
        for (final server in _servers) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(children: [
              Icon(Icons.laptop_mac_rounded, size: 16, color: t.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  server.software.isEmpty
                      ? server.address
                      : '${server.software} · ${server.address}',
                  style: t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          if (server.models.isEmpty)
            AppNotice('This computer has no model ready yet.'.tr)
          else
            AppGroup(dividerIndent: 16, children: [
              for (final model in server.models.take(12))
                AppRow(
                  title: model,
                  chevron: true,
                  onTap: _connecting ? null : () => _connect(server, model),
                ),
            ]),
          const SizedBox(height: 16),
        ],
        AppField(
          label: "Or enter the computer's address".tr,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: appInputDecoration(context, hint: '192.168.1.20'),
                onSubmitted: (_) => _check(),
              ),
            ),
            const SizedBox(width: 10),
            PillButton(
              label: _checking ? 'Checking…'.tr : 'Check'.tr,
              onPressed: _checking ? null : _check,
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppNotice(_error!, icon: Icons.error_outline_rounded, color: t.red),
        ],
        if (!_scanning) ...[
          const SizedBox(height: 14),
          Center(
            child: PillButton(
              label: 'Search again'.tr,
              icon: Icons.refresh_rounded,
              onPressed: _scan,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'The computer runs the model and this phone only shows the conversation. Nothing leaves your network.'
              .tr,
          style: t.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
