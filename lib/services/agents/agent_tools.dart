import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../document_library.dart';
import '../lan_server_finder.dart';
import '../web_search_service.dart';
import 'calculator.dart';

/// Something an agent can do. Every tool only reads: an agent can't change
/// or delete anything, so a web page that slips instructions to the model
/// can't make it do harm.
class AgentTool {
  /// What the model writes to call it.
  final String name;

  /// What the model reads about it (English: small models follow English
  /// instructions best).
  final String description;

  /// Its arguments: name → what to put there.
  final Map<String, String> parameters;

  /// What the user sees while it runs ("Searching the web: …").
  final String Function(Map<String, dynamic> args) label;

  /// Does it. Returns what the model reads back; throws to report a
  /// failure.
  final Future<String> Function(Map<String, dynamic> args) run;

  const AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.label,
    required this.run,
  });

  /// How the tool is presented to the model.
  String get signature {
    final args = parameters.entries
        .map((e) => '"${e.key}": ${e.value}')
        .join(', ');
    return '- $name: $description Arguments: {$args}';
  }
}

/// The tools of one run, and what they found (shown as sources under the
/// answer).
class AgentToolbox {
  static const webSearch = 'web_search';
  static const readPage = 'read_page';
  static const searchDocuments = 'search_documents';
  static const calculator = 'calculator';
  static const dateTime = 'current_datetime';

  /// Every tool, in the order they are offered.
  static const all = [webSearch, readPage, searchDocuments, calculator, dateTime];

  /// For the agent editor: the tool's name for the user.
  static String title(String tool) => switch (tool) {
        webSearch => 'Search the web'.tr,
        readPage => 'Read a web page'.tr,
        searchDocuments => 'Search my documents'.tr,
        calculator => 'Calculator'.tr,
        dateTime => 'Date and time'.tr,
        _ => tool,
      };

  final List<WebResult> webSources = [];
  final List<DocChunk> passages = [];

  final Future<List<WebResult>> Function(String query) searchWeb;
  final Future<String> Function(String url) fetchPage;
  final List<DocChunk> Function(String query) searchDocs;
  final DateTime Function() now;

  /// Longest tool result given to the model, in characters: a phone's
  /// context is small.
  final int maxResultChars;

  AgentToolbox({
    required this.searchWeb,
    required this.fetchPage,
    required this.searchDocs,
    DateTime Function()? now,
    this.maxResultChars = 2000,
  }) : now = now ?? DateTime.now;

  String _cut(String text) => text.length <= maxResultChars
      ? text
      : '${text.substring(0, maxResultChars)}…';

  static String _arg(Map<String, dynamic> args, String key) =>
      '${args[key] ?? args.values.firstOrNull ?? ''}'.trim();

  /// The tools named in [names], in the usual order.
  List<AgentTool> tools(Iterable<String> names) => [
        for (final name in all)
          if (names.contains(name)) _tool(name),
      ];

  AgentTool _tool(String name) => switch (name) {
        webSearch => AgentTool(
            name: webSearch,
            description:
                'Searches the web. Use it for recent facts, prices, news, or anything you are unsure of.',
            parameters: {'query': 'the search, a few words'},
            label: (a) =>
                'Searching the web: “@query”'.trParams({'query': _arg(a, 'query')}),
            run: (a) async {
              final query = _arg(a, 'query');
              if (query.isEmpty) throw const FormatException('No query');
              final results = await searchWeb(query);
              if (results.isEmpty) return 'No results.';
              // Numbered after the ones already found, so citations stay
              // unique over the whole run.
              final first = webSources.length;
              webSources.addAll(results);
              return _cut([
                for (var i = 0; i < results.length; i++)
                  '[${first + i + 1}] ${results[i].title}\n${results[i].url}\n${results[i].snippet}',
              ].join('\n\n'));
            },
          ),
        readPage => AgentTool(
            name: readPage,
            description:
                'Reads the text of a web page, for details a search result only hints at.',
            parameters: {'url': 'the address, starting with https://'},
            label: (a) => 'Reading @site'.trParams(
                {'site': Uri.tryParse(_arg(a, 'url'))?.host ?? _arg(a, 'url')}),
            run: (a) async => _cut(await fetchPage(_arg(a, 'url'))),
          ),
        searchDocuments => AgentTool(
            name: searchDocuments,
            description:
                "Searches the user's own documents (their files) for passages about something.",
            parameters: {'query': 'what to look for, a few words'},
            label: (a) => 'Searching your documents: “@query”'
                .trParams({'query': _arg(a, 'query')}),
            run: (a) async {
              final found = searchDocs(_arg(a, 'query'));
              if (found.isEmpty) return 'Nothing found in the documents.';
              passages.addAll(found);
              return _cut(DocumentLibrary.asContext(found));
            },
          ),
        calculator => AgentTool(
            name: calculator,
            description:
                'Computes arithmetic exactly. Always use it for calculations instead of doing them yourself.',
            parameters: {
              'expression': 'e.g. "(1250 * 0.2) + 35" (+ - * / % ^ sqrt round)'
            },
            label: (a) => 'Calculating @expression'
                .trParams({'expression': _arg(a, 'expression')}),
            run: (a) async {
              final expression = _arg(a, 'expression');
              return '$expression = ${Calculator.format(Calculator.evaluate(expression))}';
            },
          ),
        dateTime => AgentTool(
            name: dateTime,
            description: 'Gives the current date, time and day of the week.',
            parameters: const {},
            label: (_) => 'Checking the date'.tr,
            run: (_) async {
              final t = now();
              const days = [
                'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
                'Saturday', 'Sunday'
              ];
              String two(int n) => n.toString().padLeft(2, '0');
              return '${days[t.weekday - 1]} ${t.year}-${two(t.month)}-${two(t.day)} '
                  '${two(t.hour)}:${two(t.minute)}';
            },
          ),
        _ => throw ArgumentError('Unknown tool $name'),
      };

  /// Reads a web page as plain text. Addresses of the local network are
  /// refused: a page read by the agent must not lead it to the user's own
  /// devices.
  static Future<String> readWebPage(String url, {http.Client? client}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const FormatException('Not a web address');
    }
    if (LanServerFinder.isLocal(uri.toString())) {
      throw const FormatException('Addresses of the local network are not read');
    }
    final c = client ?? http.Client();
    try {
      final response = await c.get(uri, headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,text/plain;q=0.9,*/*;q=0.5',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        throw HttpExceptionText('The page answered ${response.statusCode}');
      }
      final type = response.headers['content-type'] ?? '';
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (!type.contains('html')) return body;
      return pageText(body);
    } finally {
      if (client == null) c.close();
    }
  }

  /// The readable text of an HTML page: its title, then its text without
  /// scripts, styles, menus or footers.
  static String pageText(String html) {
    final title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
            .firstMatch(html)?[1] ??
        '';
    var text = html
        .replaceAll(
            RegExp(r'<(head|title|script|style|noscript|svg|nav|header|footer|form|aside)\b[\s\S]*?</\1>',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
        .replaceAll(
            RegExp(r'<(br|p|div|li|h[1-6]|tr|section|article)\b[^>]*>',
                caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _entities(text)
        .replaceAll(RegExp(r'[ \t ]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    final heading = _entities(title).replaceAll(RegExp(r'\s+'), ' ').trim();
    return heading.isEmpty ? text : '$heading\n\n$text';
  }

  static String _entities(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.tryParse(m[1]!) ?? 32));
}

/// A failure to show the model as text.
class HttpExceptionText implements Exception {
  final String message;
  const HttpExceptionText(this.message);
  @override
  String toString() => message;
}
