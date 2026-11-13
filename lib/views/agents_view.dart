import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/chat_controller.dart';
import '../controllers/model_controller.dart';
import '../core/ui.dart';
import '../services/agents/agent_profiles.dart';
import '../services/agents/agent_tools.dart';
import '../services/hive_service.dart';

AgentStore get _store => AgentStore(Get.find<HiveService>());

/// The name of the assistant or team [id], or null for the plain one.
String? agentName(String id) {
  if (id.isEmpty) return null;
  return _store.agent(id)?.name ?? _store.team(id)?.name;
}

/// Chooses who answers in the chat: the plain assistant, a specialised
/// assistant, or a team.
class AgentPickerSheet extends StatelessWidget {
  const AgentPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final chat = Get.find<ChatController>();
    final store = _store;
    Widget row(String id, String title, String subtitle, IconData icon) =>
        Obx(() {
          final selected = chat.activeAgent.value == id;
          return AppRow(
            icon: icon,
            title: title,
            subtitle: subtitle,
            selected: selected,
            trailing:
                selected ? Icon(Icons.check_rounded, color: t.accent) : null,
            onTap: () {
              Navigator.pop(context);
              chat.chooseAgent(id);
            },
          );
        });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppGroup(dividerIndent: 60, children: [
          row(AgentStore.none, 'Plain assistant'.tr,
              'Answers directly, without tools.'.tr, Icons.chat_bubble_outline_rounded),
        ]),
        SectionHeader('Assistants'.tr),
        AppGroup(dividerIndent: 60, children: [
          for (final a in store.agents())
            row(a.id, a.name, a.description,
                a.usesTools ? Icons.smart_toy_outlined : Icons.person_outline_rounded),
        ]),
        SectionHeader('Teams'.tr),
        AppGroup(dividerIndent: 60, children: [
          for (final team in store.teams())
            row(team.id, team.name,
                store.membersOf(team).map((m) => m.name).join(' → '),
                Icons.groups_outlined),
        ]),
        const SizedBox(height: 14),
        Center(
          child: PillButton(
            label: 'Manage agents'.tr,
            icon: Icons.tune_rounded,
            onPressed: () {
              Navigator.pop(context);
              Get.to(() => const AgentsView());
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Agents with tools work in several steps: they are slower, and work best with a model of 4B or more, or one running on a computer.'
              .tr,
          style: t.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The assistants and teams, to read, create, copy and edit.
class AgentsView extends StatefulWidget {
  const AgentsView({super.key});

  @override
  State<AgentsView> createState() => _AgentsViewState();
}

class _AgentsViewState extends State<AgentsView> {
  Future<void> _open(Widget page) async {
    await Get.to(() => page);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final store = _store;
    String toolsLine(AgentProfile a) => a.usesTools
        ? a.tools.map(AgentToolbox.title).join(', ')
        : 'No tools'.tr;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'Agents'.tr),
      body: ListView(
        padding: kPagePadding,
        children: [
          Text(
            'An assistant has a role and, if you want, tools it decides to use on its own (web, pages, documents, calculator). A team passes a request from one assistant to the next. Choose them in the chat from the + menu.'
                .tr,
            style: t.caption,
          ),
          SectionHeader('Assistants'.tr),
          AppGroup(dividerIndent: 60, children: [
            for (final a in store.agents())
              AppRow(
                icon: a.usesTools
                    ? Icons.smart_toy_outlined
                    : Icons.person_outline_rounded,
                title: a.name,
                subtitle: '${a.description}\n${toolsLine(a)}',
                chevron: true,
                onTap: () => _open(AgentEditorView(profile: a)),
              ),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton(
              label: 'New assistant'.tr,
              icon: Icons.add_rounded,
              onPressed: () => _open(const AgentEditorView()),
            ),
          ),
          SectionHeader('Teams'.tr),
          AppGroup(dividerIndent: 60, children: [
            for (final team in store.teams())
              AppRow(
                icon: Icons.groups_outlined,
                title: team.name,
                subtitle: store.membersOf(team).map((m) => m.name).join(' → '),
                chevron: true,
                onTap: () => _open(TeamEditorView(team: team)),
              ),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton(
              label: 'New team'.tr,
              icon: Icons.add_rounded,
              onPressed: () => _open(const TeamEditorView()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Creates or edits an assistant. A built-in one is shown read-only, with
/// a way to copy it into an editable one.
class AgentEditorView extends StatefulWidget {
  final AgentProfile? profile;
  const AgentEditorView({super.key, this.profile});

  @override
  State<AgentEditorView> createState() => _AgentEditorViewState();
}

class _AgentEditorViewState extends State<AgentEditorView> {
  late final AgentProfile? _source = widget.profile;
  late final bool _readOnly = _source?.builtIn ?? false;
  late final _name = TextEditingController(text: _source?.name ?? '');
  late final _description =
      TextEditingController(text: _source?.description ?? '');
  late final _instructions =
      TextEditingController(text: _source?.instructions ?? '');
  late final Set<String> _tools = {...?_source?.tools};
  late String _model = _source?.model ?? '';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _instructions.text.trim().isEmpty) {
      showToast('Missing information'.tr,
          'Give the assistant a name and instructions.'.tr,
          tone: ToastTone.warning);
      return;
    }
    await _store.saveAgent(AgentProfile(
      id: _source == null || _readOnly ? AgentStore.newId('agent') : _source.id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      instructions: _instructions.text.trim(),
      tools: [for (final tool in AgentToolbox.all) if (_tools.contains(tool)) tool],
      model: _model,
    ));
    Get.back();
  }

  Future<void> _delete() async {
    final ok = await confirmSheet(context,
        title: 'Delete this assistant?'.tr,
        confirmLabel: 'Delete'.tr,
        destructive: true);
    if (!ok) return;
    await _store.deleteAgent(_source!.id);
    if (Get.isRegistered<ChatController>() &&
        Get.find<ChatController>().activeAgent.value == _source.id) {
      Get.find<ChatController>().activeAgent.value = AgentStore.none;
    }
    Get.back();
  }

  void _copy() {
    Get.off(() => AgentEditorView(
          profile: _source!.copyWith(
            id: '',
            name: '@name (copy)'.trParams({'name': _source.name}),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final models = Get.isRegistered<ModelController>()
        ? Get.find<ModelController>()
            .displayedModels
            .where((m) =>
                Get.find<ModelController>().isDownloaded(m.filename) &&
                !Get.find<ModelController>().isImageModel(m))
            .toList()
        : const [];
    final isNew = _source == null || _source.id.isEmpty;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context,
          title: _readOnly
              ? _source!.name
              : isNew
                  ? 'New assistant'.tr
                  : 'Edit assistant'.tr),
      body: ListView(
        padding: kPagePadding,
        children: [
          if (_readOnly) ...[
            AppNotice(
              'This assistant comes with the app. Copy it to change it.'.tr,
            ),
            const SizedBox(height: 12),
          ],
          AppField(
            label: 'Name'.tr,
            child: TextField(
              controller: _name,
              enabled: !_readOnly,
              decoration: appInputDecoration(context, hint: 'Travel planner'.tr),
            ),
          ),
          const SizedBox(height: 14),
          AppField(
            label: 'Description'.tr,
            child: TextField(
              controller: _description,
              enabled: !_readOnly,
              decoration: appInputDecoration(context,
                  hint: 'Plans trips day by day'.tr),
            ),
          ),
          const SizedBox(height: 14),
          AppField(
            label: 'Instructions'.tr,
            helper:
                'Its role and how it should work, as you would explain it to someone.'
                    .tr,
            child: TextField(
              controller: _instructions,
              enabled: !_readOnly,
              minLines: 4,
              maxLines: 12,
              decoration: appInputDecoration(context,
                  hint:
                      'You plan trips. Ask for the dates and budget, then give a day-by-day plan.'
                          .tr),
            ),
          ),
          SectionHeader('Tools it may use'.tr),
          AppGroup(dividerIndent: 16, children: [
            for (final tool in AgentToolbox.all)
              AppRow(
                title: AgentToolbox.title(tool),
                trailing: Checkbox(
                  value: _tools.contains(tool),
                  onChanged: _readOnly
                      ? null
                      : (on) => setState(() =>
                          on == true ? _tools.add(tool) : _tools.remove(tool)),
                ),
              ),
          ]),
          SectionFootnote(
              'With tools, it decides on its own when to use them, in several steps.'
                  .tr),
          if (models.isNotEmpty) ...[
            SectionHeader('Model'.tr),
            AppGroup(dividerIndent: 16, children: [
              for (final option in ['', ...models.map((m) => m.filename)])
                AppRow(
                  title: option.isEmpty ? 'The model in use'.tr : option,
                  selected: _model == option,
                  trailing: _model == option
                      ? Icon(Icons.check_rounded, color: t.accent)
                      : null,
                  onTap: _readOnly ? null : () => setState(() => _model = option),
                ),
            ]),
            SectionFootnote(
                'A model of its own is loaded when you choose the assistant.'.tr),
          ],
          const SizedBox(height: 20),
          if (_readOnly)
            PrimaryButton(
                label: 'Copy and edit'.tr,
                icon: Icons.copy_rounded,
                onPressed: _copy)
          else ...[
            PrimaryButton(label: 'Save'.tr, onPressed: _save),
            if (!isNew) ...[
              const SizedBox(height: 10),
              Center(
                child: PillButton(
                    label: 'Delete'.tr, destructive: true, onPressed: _delete),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Creates or edits a team: a name and assistants in the order they work.
class TeamEditorView extends StatefulWidget {
  final TeamProfile? team;
  const TeamEditorView({super.key, this.team});

  @override
  State<TeamEditorView> createState() => _TeamEditorViewState();
}

class _TeamEditorViewState extends State<TeamEditorView> {
  late final TeamProfile? _source = widget.team;
  late final bool _readOnly = _source?.builtIn ?? false;
  late final _name = TextEditingController(text: _source?.name ?? '');
  late final _description =
      TextEditingController(text: _source?.description ?? '');
  late final List<String> _members = [...?_source?.members];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    final id = await showAppSheet<String>(
      context,
      title: 'Add an assistant'.tr,
      builder: (ctx) => AppGroup(dividerIndent: 16, children: [
        for (final a in _store.agents())
          AppRow(
            title: a.name,
            subtitle: a.description,
            onTap: () => Navigator.pop(ctx, a.id),
          ),
      ]),
    );
    if (id != null) setState(() => _members.add(id));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _members.length < 2) {
      showToast('Missing information'.tr,
          'Give the team a name and at least two assistants.'.tr,
          tone: ToastTone.warning);
      return;
    }
    await _store.saveTeam(TeamProfile(
      id: _source == null || _readOnly ? AgentStore.newId('team') : _source.id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      members: List.of(_members),
    ));
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final store = _store;
    final isNew = _source == null || _source.id.isEmpty;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context,
          title: _readOnly
              ? _source!.name
              : isNew
                  ? 'New team'.tr
                  : 'Edit team'.tr),
      body: ListView(
        padding: kPagePadding,
        children: [
          if (_readOnly) ...[
            AppNotice(
                'This team comes with the app. Copy it to change it.'.tr),
            const SizedBox(height: 12),
          ],
          AppField(
            label: 'Name'.tr,
            child: TextField(
              controller: _name,
              enabled: !_readOnly,
              decoration: appInputDecoration(context, hint: 'Article team'.tr),
            ),
          ),
          const SizedBox(height: 14),
          AppField(
            label: 'Description'.tr,
            child: TextField(
              controller: _description,
              enabled: !_readOnly,
              decoration: appInputDecoration(context),
            ),
          ),
          SectionHeader('In this order'.tr),
          if (_members.isEmpty)
            Text('No assistant yet.'.tr, style: t.caption)
          else
            AppGroup(dividerIndent: 60, children: [
              for (var i = 0; i < _members.length; i++)
                AppRow(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: t.accent.withValues(alpha: 0.12),
                    child: Text('${i + 1}',
                        style: t.small.copyWith(color: t.accent)),
                  ),
                  title: store.agent(_members[i])?.name ?? '?',
                  subtitle: i == _members.length - 1
                      ? 'Writes the final answer'.tr
                      : null,
                  trailing: _readOnly
                      ? null
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (i > 0)
                            IconButton(
                              tooltip: 'Move up'.tr,
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              onPressed: () => setState(() {
                                final m = _members.removeAt(i);
                                _members.insert(i - 1, m);
                              }),
                            ),
                          IconButton(
                            tooltip: 'Remove'.tr,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _members.removeAt(i)),
                          ),
                        ]),
                ),
            ]),
          if (!_readOnly) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton(
                  label: 'Add an assistant'.tr,
                  icon: Icons.add_rounded,
                  onPressed: _addMember),
            ),
          ],
          SectionFootnote(
              'Each assistant reads the request and the work of the ones before it. A team makes several calls to the model: on a phone, expect a few minutes.'
                  .tr),
          const SizedBox(height: 20),
          if (_readOnly)
            PrimaryButton(
              label: 'Copy and edit'.tr,
              icon: Icons.copy_rounded,
              onPressed: () => Get.off(() => TeamEditorView(
                    team: TeamProfile(
                      id: '',
                      name: '@name (copy)'.trParams({'name': _source!.name}),
                      description: _source.description,
                      members: _source.members,
                    ),
                  )),
            )
          else ...[
            PrimaryButton(label: 'Save'.tr, onPressed: _save),
            if (!isNew) ...[
              const SizedBox(height: 10),
              Center(
                child: PillButton(
                  label: 'Delete'.tr,
                  destructive: true,
                  onPressed: () async {
                    final ok = await confirmSheet(context,
                        title: 'Delete this team?'.tr,
                        confirmLabel: 'Delete'.tr,
                        destructive: true);
                    if (!ok) return;
                    await _store.deleteTeam(_source.id);
                    if (Get.isRegistered<ChatController>() &&
                        Get.find<ChatController>().activeAgent.value ==
                            _source.id) {
                      Get.find<ChatController>().activeAgent.value =
                          AgentStore.none;
                    }
                    Get.back();
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
