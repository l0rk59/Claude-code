import 'hive_service.dart';

/// What the assistant remembers about the user from one conversation to
/// the next: short facts the user asked it to keep ("remember that I am
/// vegetarian"), given to the model at the start of every conversation.
///
/// Kept on the phone and edited by the user; nothing is remembered without
/// being asked.
class Memories {
  static const key = 'memories';
  static const enabledKey = 'memories_enabled';

  /// Facts given to the model at most: each costs room in its context.
  static const maxFacts = 40;

  static List<String> all(HiveService hive) => [
        for (final m in hive.getSetting<List>(key, defaultValue: const []) ??
            const [])
          if (m is String && m.trim().isNotEmpty) m,
      ];

  static bool enabled(HiveService hive) =>
      hive.getSetting<bool>(enabledKey, defaultValue: true) ?? true;

  /// Keeps [fact], unless it is already known. The newest facts are kept
  /// when there are too many.
  static Future<List<String>> add(HiveService hive, String fact) async {
    final clean = _tidy(fact);
    final facts = all(hive);
    if (clean.isEmpty ||
        facts.any((f) => f.toLowerCase() == clean.toLowerCase())) {
      return facts;
    }
    final updated = [...facts, clean];
    final kept = updated.length > maxFacts
        ? updated.sublist(updated.length - maxFacts)
        : updated;
    await hive.setSetting(key, kept);
    return kept;
  }

  static Future<List<String>> remove(HiveService hive, String fact) async {
    final kept = all(hive).where((f) => f != fact).toList();
    await hive.setSetting(key, kept);
    return kept;
  }

  static Future<void> clear(HiveService hive) => hive.setSetting(key, <String>[]);

  static final _asks = [
    RegExp(
        r"^\s*(?:s'il te pla[iî]t,?\s*)?(?:souviens[- ]toi|rappelle[- ]toi|retiens|m[ée]morise|n'oublie pas|garde en m[ée]moire)\s*(?:bien\s*)?(?:que\s+|qu'|de\s+|:\s*)?(.+)$",
        caseSensitive: false,
        dotAll: true),
    RegExp(
        r'^\s*(?:please,?\s*)?(?:remember|keep in mind|note|don.t forget)\s*(?:that\s+|:\s*)?(.+)$',
        caseSensitive: false,
        dotAll: true),
  ];

  /// The fact a message asks to remember ("Souviens-toi que je suis
  /// végétarien" → "je suis végétarien"), or null when it asks nothing.
  static String? requested(String message) {
    for (final pattern in _asks) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final fact = _tidy(match[1]!);
        if (fact.length >= 3) return fact;
      }
    }
    return null;
  }

  static String _tidy(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.!]+$'), '');

  /// What is added to the system prompt, or '' when there is nothing to
  /// remember. [intro] is the sentence in the user's language.
  static String forSystemPrompt(List<String> facts, String intro) {
    if (facts.isEmpty) return '';
    return '$intro\n${facts.map((f) => '- $f').join('\n')}';
  }
}
