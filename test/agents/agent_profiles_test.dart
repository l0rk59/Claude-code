import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:privatelm/controllers/chat_controller.dart';
import 'package:privatelm/services/agents/agent_profiles.dart';
import 'package:privatelm/services/agents/agent_runner.dart';
import 'package:privatelm/services/agents/agent_tools.dart';
import 'package:privatelm/services/hive_service.dart';

void main() {
  late Directory dir;
  late AgentStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agents');
    Hive.init(dir.path);
    store = AgentStore(await HiveService().init());
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('the built-in assistants and teams hold together', () {
    final agents = AgentStore.builtInAgents();
    final ids = agents.map((a) => a.id).toSet();
    expect(ids, hasLength(agents.length));
    for (final a in agents) {
      expect(a.instructions, isNotEmpty, reason: a.id);
      expect(a.tools.every(AgentToolbox.all.contains), isTrue, reason: a.id);
    }
    for (final team in AgentStore.builtInTeams()) {
      expect(team.members.length, greaterThanOrEqualTo(2), reason: team.id);
      expect(team.members.every(ids.contains), isTrue, reason: team.id);
    }
    // The researcher can look things up; the reviewer only writes.
    expect(store.agent('builtin:researcher')!.tools, contains(AgentToolbox.webSearch));
    expect(store.agent('builtin:reviewer')!.usesTools, isFalse);
  });

  test("the user's assistants and teams are kept, edited and deleted",
      () async {
    const mine = AgentProfile(
      id: 'agent:1',
      name: 'Voyages',
      description: 'Prépare des voyages',
      instructions: 'Tu organises des voyages.',
      tools: [AgentToolbox.webSearch, 'format_disk'],
    );
    await store.saveAgent(mine);
    final saved = store.agent('agent:1')!;
    expect(saved.name, 'Voyages');
    // A tool the app doesn't have is dropped.
    expect(saved.tools, [AgentToolbox.webSearch]);
    expect(saved.builtIn, isFalse);

    await store.saveAgent(saved.copyWith(name: 'Voyages en train'));
    expect(store.customAgents(), hasLength(1));
    expect(store.agent('agent:1')!.name, 'Voyages en train');

    await store.saveTeam(const TeamProfile(
        id: 'team:1',
        name: 'Équipe voyage',
        description: '',
        members: ['builtin:planner', 'agent:1', 'builtin:reviewer']));
    expect(store.membersOf(store.team('team:1')!).map((a) => a.name),
        ['Planner', 'Voyages en train', 'Reviewer']);

    await store.setActive('agent:1');
    await store.deleteAgent('agent:1');
    expect(store.agent('agent:1'), isNull);
    // The team loses the member, the chat goes back to the plain assistant.
    expect(store.team('team:1')!.members,
        ['builtin:planner', 'builtin:reviewer']);
    expect(store.active, AgentStore.none);

    await store.setActive('team:1');
    await store.deleteTeam('team:1');
    expect(store.team('team:1'), isNull);
    expect(store.active, AgentStore.none);
  });

  test('the steps are listed for the user, team work quoted', () {
    expect(ChatController.agentStepsMarkdown(const []), '');
    final text = ChatController.agentStepsMarkdown(const [
      AgentStep(agent: 'Planner', label: 'Planner', result: '1. Chercher.\n2. Conclure.'),
      AgentStep(agent: 'Researcher', label: 'Searching the web: “tarif”'),
      AgentStep(label: 'Calculating 1/0', failed: true),
    ]);
    expect(
        text,
        '1. **Planner**\n> 1. Chercher.\n> 2. Conclure.\n'
        '2. **Researcher** · Searching the web: “tarif”\n'
        '3. Calculating 1/0 ⚠️');
  });
}
