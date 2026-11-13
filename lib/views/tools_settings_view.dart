import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants.dart';
import '../core/ui.dart';
import '../services/hive_service.dart';
import '../services/memory_service.dart';
import '../services/web_search_service.dart';

/// Which engine the chat's web search uses, and its key or address.
class WebSearchSettingsView extends StatefulWidget {
  const WebSearchSettingsView({super.key});

  @override
  State<WebSearchSettingsView> createState() => _WebSearchSettingsViewState();
}

class _WebSearchSettingsViewState extends State<WebSearchSettingsView> {
  HiveService get _hive => Get.find<HiveService>();
  late WebSearchProvider _provider = WebSearchProvider.fromName(
      _hive.getSetting<String>(AppConstants.keyWebSearchProvider));
  late final _braveKey = TextEditingController(
      text: _hive.getSetting<String>(AppConstants.keyBraveSearchKey) ?? '');
  late final _searxng = TextEditingController(
      text: _hive.getSetting<String>(AppConstants.keySearxngUrl) ?? '');

  @override
  void dispose() {
    _braveKey.dispose();
    _searxng.dispose();
    super.dispose();
  }

  Future<void> _choose(WebSearchProvider provider) async {
    setState(() => _provider = provider);
    await _hive.setSetting(AppConstants.keyWebSearchProvider, provider.name);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    String describe(WebSearchProvider p) => switch (p) {
          WebSearchProvider.duckDuckGo =>
            'No account. It sometimes turns searches away when there are too many.'
                .tr,
          WebSearchProvider.brave =>
            'Needs a key (a free plan exists on brave.com/search/api). Dependable.'
                .tr,
          WebSearchProvider.searxng =>
            'Your own search server, for instance on your computer: the search engines see it, not your phone.'
                .tr,
        };
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Web search'.tr),
      body: ListView(
        padding: kPagePadding,
        children: [
          Text(
            'Switched on from the + menu of the chat. Only your question goes to the search engine; the results are given to the model with it, and the answer lists its sources.'
                .tr,
            style: t.caption,
          ),
          SectionHeader('Search engine'.tr),
          AppGroup(dividerIndent: 16, children: [
            for (final p in WebSearchProvider.values)
              AppRow(
                title: switch (p) {
                  WebSearchProvider.duckDuckGo => 'DuckDuckGo',
                  WebSearchProvider.brave => 'Brave Search',
                  WebSearchProvider.searxng => 'SearXNG',
                },
                subtitle: describe(p),
                selected: p == _provider,
                trailing: p == _provider
                    ? Icon(Icons.check_rounded, color: t.accent)
                    : null,
                onTap: () => _choose(p),
              ),
          ]),
          if (_provider == WebSearchProvider.brave) ...[
            const SizedBox(height: 16),
            AppField(
              label: 'Brave Search key'.tr,
              helper: "Stored in the phone's keystore.".tr,
              child: TextField(
                controller: _braveKey,
                obscureText: true,
                autocorrect: false,
                decoration: appInputDecoration(context),
                onChanged: (v) => _hive.setSetting(AppConstants.keyBraveSearchKey,
                    v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ],
          if (_provider == WebSearchProvider.searxng) ...[
            const SizedBox(height: 16),
            AppField(
              label: 'Address of the SearXNG server'.tr,
              helper:
                  'For example http://192.168.1.20:8888. Its settings must allow the "json" format.'
                      .tr,
              child: TextField(
                controller: _searxng,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: appInputDecoration(context,
                    hint: 'http://192.168.1.20:8888'),
                onChanged: (v) =>
                    _hive.setSetting(AppConstants.keySearxngUrl, v.trim()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the assistant remembers about the user, to read, add to and clear.
class MemoryView extends StatefulWidget {
  const MemoryView({super.key});

  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> {
  HiveService get _hive => Get.find<HiveService>();
  late List<String> _facts = Memories.all(_hive);
  late bool _enabled = Memories.enabled(_hive);
  final _newFact = TextEditingController();

  @override
  void dispose() {
    _newFact.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final facts = await Memories.add(_hive, _newFact.text);
    _newFact.clear();
    setState(() => _facts = facts);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Memory'.tr),
      body: ListView(
        padding: kPagePadding,
        children: [
          Text(
            'Say "Remember that…" in a chat, or add a fact here: the assistant knows it in every conversation. Nothing is remembered without being asked, and it stays on the phone.'
                .tr,
            style: t.caption,
          ),
          const SizedBox(height: 12),
          AppGroup(children: [
            AppRow(
              icon: Icons.psychology_outlined,
              title: 'Use the memory'.tr,
              trailing: Switch(
                value: _enabled,
                onChanged: (v) async {
                  await _hive.setSetting(Memories.enabledKey, v);
                  setState(() => _enabled = v);
                },
              ),
            ),
          ]),
          SectionHeader('Add a fact'.tr),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newFact,
                decoration: appInputDecoration(context,
                    hint: 'I am vegetarian'.tr),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 10),
            PillButton(label: 'Add'.tr, onPressed: _add),
          ]),
          SectionHeader(
              'Remembered · @count'.trParams({'count': '${_facts.length}'})),
          if (_facts.isEmpty)
            EmptyState(
                icon: Icons.psychology_alt_outlined,
                title: 'Nothing remembered yet'.tr)
          else ...[
            AppGroup(dividerIndent: 16, children: [
              for (final fact in _facts)
                AppRow(
                  title: fact,
                  trailing: IconButton(
                    tooltip: 'Forget'.tr,
                    icon: Icon(Icons.close_rounded, color: t.muted),
                    onPressed: () async {
                      final facts = await Memories.remove(_hive, fact);
                      setState(() => _facts = facts);
                    },
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Center(
              child: PillButton(
                label: 'Forget everything'.tr,
                destructive: true,
                onPressed: () async {
                  final ok = await confirmSheet(
                    context,
                    title: 'Forget everything?'.tr,
                    confirmLabel: 'Forget everything'.tr,
                    destructive: true,
                  );
                  if (!ok) return;
                  await Memories.clear(_hive);
                  setState(() => _facts = const []);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
