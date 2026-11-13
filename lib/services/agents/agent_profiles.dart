import 'package:get/get.dart';

import '../hive_service.dart';
import 'agent_tools.dart';

/// A specialised assistant: a role, instructions, the tools it may use
/// and, optionally, the model it works best with.
class AgentProfile {
  final String id;
  final String name;

  /// One line for the user.
  final String description;

  /// What the model is told it is and how to work. English for the
  /// built-in ones (small models follow English best); the user writes
  /// theirs in any language.
  final String instructions;

  /// Tool names (see [AgentToolbox]). Empty: it only writes.
  final List<String> tools;

  /// A downloaded model to load when it is chosen; '' keeps the current
  /// one.
  final String model;

  /// Comes with the app (read-only, but can be copied).
  final bool builtIn;

  const AgentProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    this.tools = const [],
    this.model = '',
    this.builtIn = false,
  });

  bool get usesTools => tools.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'instructions': instructions,
        'tools': tools,
        'model': model,
      };

  factory AgentProfile.fromMap(Map<dynamic, dynamic> m) => AgentProfile(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        description: '${m['description'] ?? ''}',
        instructions: '${m['instructions'] ?? ''}',
        tools: [
          for (final t in (m['tools'] as List? ?? const []))
            if (AgentToolbox.all.contains(t)) '$t',
        ],
        model: '${m['model'] ?? ''}',
      );

  AgentProfile copyWith({
    String? id,
    String? name,
    String? description,
    String? instructions,
    List<String>? tools,
    String? model,
  }) =>
      AgentProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        instructions: instructions ?? this.instructions,
        tools: tools ?? this.tools,
        model: model ?? this.model,
      );
}

/// Assistants working in turn on a request.
class TeamProfile {
  final String id;
  final String name;
  final String description;

  /// Assistant ids, in the order they work.
  final List<String> members;
  final bool builtIn;

  const TeamProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    this.builtIn = false,
  });

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'description': description, 'members': members};

  factory TeamProfile.fromMap(Map<dynamic, dynamic> m) => TeamProfile(
        id: '${m['id']}',
        name: '${m['name'] ?? ''}',
        description: '${m['description'] ?? ''}',
        members: [for (final a in (m['members'] as List? ?? const [])) '$a'],
      );
}

/// The app's assistants and teams, and the user's own.
class AgentStore {
  static const _agentsKey = 'agents_custom';
  static const _teamsKey = 'agent_teams_custom';
  static const _activeKey = 'agent_active';

  /// The plain assistant: no special role, no tools.
  static const none = '';

  static List<AgentProfile> builtInAgents() => [
        AgentProfile(
          id: 'builtin:researcher',
          name: 'Researcher'.tr,
          description: 'Searches the web, reads pages, cites its sources.'.tr,
          instructions:
              'You are a careful researcher. Search the web for anything recent or uncertain, read the most relevant pages, compare sources, and give a precise answer with its sources. Say clearly when sources disagree or when you could not find the answer.',
          tools: const [
            AgentToolbox.webSearch,
            AgentToolbox.readPage,
            AgentToolbox.calculator,
            AgentToolbox.dateTime,
          ],
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:librarian',
          name: 'Librarian'.tr,
          description: 'Answers from your documents, and says where.'.tr,
          instructions:
              "You answer questions using the user's own documents. Search them, possibly several times with different words, quote the relevant passages, and name the document they come from. If the documents don't contain the answer, say so.",
          tools: const [AgentToolbox.searchDocuments, AgentToolbox.calculator],
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:analyst',
          name: 'Analyst'.tr,
          description: 'Numbers, budgets, conversions: computed exactly.'.tr,
          instructions:
              'You are an analyst. Work step by step, use the calculator for every calculation, and present results clearly, with a short table when it helps. State your assumptions.',
          tools: const [AgentToolbox.calculator, AgentToolbox.dateTime],
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:planner',
          name: 'Planner'.tr,
          description: 'Breaks a request down into clear steps.'.tr,
          instructions:
              'You are a planner. Break the request down into a short numbered list of concrete steps, and say what information each step needs. Do not answer the request itself.',
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:writer',
          name: 'Writer'.tr,
          description: 'Writes clear, well-organised text.'.tr,
          instructions:
              'You are a writer. Write clear, well-organised, engaging text for the reader, with headings or lists when they help. Keep the facts you are given; do not invent any.',
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:reviewer',
          name: 'Reviewer'.tr,
          description: 'Checks a draft, fixes errors, fills gaps.'.tr,
          instructions:
              'You are a demanding reviewer. Check the work for factual errors, contradictions, missing points and unclear passages, fix them, and give the improved final version. Keep the sources it cites.',
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:translator',
          name: 'Translator'.tr,
          description: 'Faithful, natural translations.'.tr,
          instructions:
              'You are a professional translator. Translate faithfully and naturally, keep the formatting, and ask which language to translate into when it is not clear. Give only the translation unless asked for more.',
          builtIn: true,
        ),
        AgentProfile(
          id: 'builtin:coach',
          name: 'Coach'.tr,
          description: 'Encouraging, practical plans and habits.'.tr,
          instructions:
              'You are a supportive, practical coach. Ask about the goal and constraints when needed, then give a realistic plan with small steps, and encourage without exaggerating.',
          builtIn: true,
        ),
      ];

  static List<TeamProfile> builtInTeams() => [
        TeamProfile(
          id: 'team:research',
          name: 'Research team'.tr,
          description: 'Plans, searches the web, then checks the answer.'.tr,
          members: const [
            'builtin:planner',
            'builtin:researcher',
            'builtin:reviewer',
          ],
          builtIn: true,
        ),
        TeamProfile(
          id: 'team:writing',
          name: 'Writing team'.tr,
          description: 'Plans, writes, then proofreads.'.tr,
          members: const ['builtin:planner', 'builtin:writer', 'builtin:reviewer'],
          builtIn: true,
        ),
        TeamProfile(
          id: 'team:documents',
          name: 'Document team'.tr,
          description: 'Finds what your documents say, then checks it.'.tr,
          members: const ['builtin:librarian', 'builtin:reviewer'],
          builtIn: true,
        ),
      ];

  final HiveService hive;
  AgentStore(this.hive);

  List<AgentProfile> customAgents() => [
        for (final m in hive.getSetting<List>(_agentsKey, defaultValue: const []) ??
            const [])
          if (m is Map && m['id'] != null) AgentProfile.fromMap(m),
      ];

  List<TeamProfile> customTeams() => [
        for (final m in hive.getSetting<List>(_teamsKey, defaultValue: const []) ??
            const [])
          if (m is Map && m['id'] != null) TeamProfile.fromMap(m),
      ];

  List<AgentProfile> agents() => [...builtInAgents(), ...customAgents()];
  List<TeamProfile> teams() => [...builtInTeams(), ...customTeams()];

  AgentProfile? agent(String id) => agents().firstWhereOrNull((a) => a.id == id);
  TeamProfile? team(String id) => teams().firstWhereOrNull((t) => t.id == id);

  /// The members of [team] that still exist, in order.
  List<AgentProfile> membersOf(TeamProfile team) => [
        for (final id in team.members)
          if (agent(id) != null) agent(id)!,
      ];

  /// Saves [profile] (new, or replacing the one with its id).
  Future<void> saveAgent(AgentProfile profile) async {
    final list = customAgents().where((a) => a.id != profile.id).toList()
      ..add(profile);
    await hive.setSetting(_agentsKey, [for (final a in list) a.toMap()]);
  }

  Future<void> deleteAgent(String id) async {
    await hive.setSetting(_agentsKey,
        [for (final a in customAgents()) if (a.id != id) a.toMap()]);
    // Teams lose the member; the active choice falls back to the plain
    // assistant.
    await hive.setSetting(_teamsKey, [
      for (final t in customTeams())
        TeamProfile(
                id: t.id,
                name: t.name,
                description: t.description,
                members: t.members.where((m) => m != id).toList())
            .toMap(),
    ]);
    if (active == id) await setActive(none);
  }

  Future<void> saveTeam(TeamProfile team) async {
    final list = customTeams().where((t) => t.id != team.id).toList()..add(team);
    await hive.setSetting(_teamsKey, [for (final t in list) t.toMap()]);
  }

  Future<void> deleteTeam(String id) async {
    await hive.setSetting(_teamsKey,
        [for (final t in customTeams()) if (t.id != id) t.toMap()]);
    if (active == id) await setActive(none);
  }

  /// The assistant or team the chat uses ('' for the plain assistant).
  String get active => hive.getSetting<String>(_activeKey) ?? none;

  Future<void> setActive(String id) => hive.setSetting(_activeKey, id);

  /// A new id for something the user creates.
  static String newId(String kind) =>
      '$kind:${DateTime.now().microsecondsSinceEpoch}';
}
