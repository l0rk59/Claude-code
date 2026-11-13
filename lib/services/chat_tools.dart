import 'document_library.dart';
import 'web_search_service.dart';

/// Puts what the web search and the documents found into the question the
/// model reads, and lists the sources under its answer.
///
/// The context goes into the latest message, not the system prompt: the
/// engine keeps the start of the conversation computed from one turn to the
/// next, and changing the system prompt each turn would recompute it all.
class ChatTools {
  /// Titles of the sources list, in every language the app speaks, so the
  /// list can be taken off an answer before it is sent back to the model.
  static const footerTitles = [
    'Sources',
    'Excerpts used',
    'Extraits utilisés',
  ];

  /// [question] preceded by [context] and the [intro] that tells the model
  /// what to do with it.
  static String withContext(String question, String context, String intro) =>
      context.trim().isEmpty ? question : '$intro\n\n$context\n\n---\n\n$question';

  /// Everything the search found, numbered for the model: web results
  /// first, then document passages.
  static String context(List<WebResult> web, List<DocChunk> passages) => [
        if (web.isNotEmpty) WebSearchService.asContext(web),
        if (passages.isNotEmpty) DocumentLibrary.asContext(passages),
      ].join('\n\n');

  /// The list shown under the answer: links for the web, document names
  /// for the passages.
  static String footer({
    required List<WebResult> web,
    required List<DocChunk> passages,
    required String webTitle,
    required String passagesTitle,
  }) {
    final parts = <String>[];
    if (web.isNotEmpty) {
      parts.add('**$webTitle**\n${[
        for (var i = 0; i < web.length; i++)
          '${i + 1}. [${_escape(web[i].title.isEmpty ? web[i].url : web[i].title)}](${web[i].url})',
      ].join('\n')}');
    }
    if (passages.isNotEmpty) {
      final names = <String>{for (final p in passages) p.document};
      parts.add('**$passagesTitle**\n${names.map((n) => '- $n').join('\n')}');
    }
    return parts.isEmpty ? '' : '\n\n---\n${parts.join('\n\n')}';
  }

  static final _footer = RegExp(
      '\\n\\n---\\n\\*\\*(${footerTitles.map(RegExp.escape).join('|')})\\*\\*[\\s\\S]*\$');

  /// [answer] without the sources list, as it goes back to the model.
  static String stripFooter(String answer) => answer.replaceFirst(_footer, '');

  static String _escape(String title) =>
      title.replaceAll('[', '(').replaceAll(']', ')');
}
