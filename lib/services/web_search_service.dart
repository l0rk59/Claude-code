import 'dart:convert';

import 'package:http/http.dart' as http;

/// One search result: what the model reads, and the source shown to the
/// user.
class WebResult {
  final String title;
  final String url;
  final String snippet;
  const WebResult({required this.title, required this.url, this.snippet = ''});
}

/// Where searches go.
enum WebSearchProvider {
  /// No account needed. Reads DuckDuckGo's plain HTML page, which can turn
  /// searches away when it suspects a robot.
  duckDuckGo,

  /// Brave Search API: needs a key (a free plan exists), dependable.
  brave,

  /// A SearXNG server the user runs, for instance on their computer: the
  /// search engines see that server, not the phone.
  searxng;

  static WebSearchProvider fromName(String? name) =>
      values.firstWhere((p) => p.name == name, orElse: () => duckDuckGo);
}

/// Why a search gave nothing, in words for the user.
class WebSearchException implements Exception {
  final String message;
  const WebSearchException(this.message);
  @override
  String toString() => message;
}

/// Looks up the web for the chat: the results go into the question, so any
/// model, even small and offline, can answer from current pages and name
/// its sources.
class WebSearchService {
  final http.Client _client;
  WebSearchService({http.Client? client}) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 12);
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0 Mobile Safari/537.36';

  /// The first [count] results for [query]. Throws a [WebSearchException]
  /// saying what went wrong.
  Future<List<WebResult>> search(
    String query, {
    WebSearchProvider provider = WebSearchProvider.duckDuckGo,
    String braveKey = '',
    String searxngUrl = '',
    int count = 5,
    String language = 'fr',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    late http.Response response;
    try {
      switch (provider) {
        case WebSearchProvider.duckDuckGo:
          response = await _client.post(
            Uri.https('html.duckduckgo.com', '/html/'),
            headers: {'User-Agent': _userAgent},
            body: {'q': q, 'kl': language == 'fr' ? 'fr-fr' : 'wt-wt'},
          ).timeout(_timeout);
        case WebSearchProvider.brave:
          if (braveKey.trim().isEmpty) {
            throw const WebSearchException('brave-key');
          }
          response = await _client.get(
            Uri.https('api.search.brave.com', '/res/v1/web/search',
                {'q': q, 'count': '$count', 'search_lang': language}),
            headers: {
              'Accept': 'application/json',
              'X-Subscription-Token': braveKey.trim(),
            },
          ).timeout(_timeout);
        case WebSearchProvider.searxng:
          final base = Uri.tryParse(searxngUrl.trim());
          if (base == null || !base.hasScheme || base.host.isEmpty) {
            throw const WebSearchException('searxng-url');
          }
          response = await _client.get(
            base.replace(
              path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/search',
              queryParameters: {'q': q, 'format': 'json', 'language': language},
            ),
            headers: {'Accept': 'application/json'},
          ).timeout(_timeout);
      }
    } on WebSearchException {
      rethrow;
    } catch (_) {
      throw const WebSearchException('unreachable');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw WebSearchException(
          provider == WebSearchProvider.searxng ? 'searxng-json' : 'refused');
    }
    if (response.statusCode == 429) throw const WebSearchException('busy');
    if (response.statusCode >= 400) {
      throw const WebSearchException('unreachable');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final results = switch (provider) {
      WebSearchProvider.duckDuckGo => parseDuckDuckGo(body),
      WebSearchProvider.brave => parseBrave(body),
      WebSearchProvider.searxng => parseSearxng(body),
    };
    if (results.isEmpty &&
        provider == WebSearchProvider.duckDuckGo &&
        _isChallenge(body)) {
      throw const WebSearchException('busy');
    }
    return results.take(count).toList();
  }

  /// DuckDuckGo answered with its robot check instead of results.
  static bool _isChallenge(String html) =>
      html.contains('anomaly-modal') || html.contains('challenge-form');

  static List<WebResult> parseDuckDuckGo(String html) {
    final results = <WebResult>[];
    // Each result: <a class="result__a" href="…">title</a>, followed (before
    // the next result's link) by <a class="result__snippet" …>snippet</a>.
    final link = RegExp(
        r'''class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>''',
        dotAll: true);
    final snippet = RegExp(
        r'''class="result__snippet"[^>]*>(.*?)</(?:a|div)>''',
        dotAll: true);
    final links = link.allMatches(html).toList();
    for (var i = 0; i < links.length; i++) {
      final l = links[i];
      final url = _ddgTarget(_unescape(l[1]!));
      // Ads point back to DuckDuckGo's own click tracker.
      if (url == null ||
          url.contains('duckduckgo.com/y.js') ||
          results.any((r) => r.url == url)) {
        continue;
      }
      final end = i + 1 < links.length ? links[i + 1].start : html.length;
      results.add(WebResult(
        title: _text(l[2]!),
        url: url,
        snippet: _text(snippet.firstMatch(html.substring(l.end, end))?[1] ?? ''),
      ));
    }
    return results;
  }

  /// DuckDuckGo wraps links: "//duckduckgo.com/l/?uddg=<target>&rut=…".
  static String? _ddgTarget(String href) {
    final uri = Uri.tryParse(href.startsWith('//') ? 'https:$href' : href);
    if (uri == null) return null;
    final wrapped = uri.queryParameters['uddg'];
    final target = wrapped ?? href;
    return target.startsWith('http') ? target : null;
  }

  static List<WebResult> parseBrave(String body) {
    final data = _json(body);
    final web = data is Map ? data['web'] : null;
    final list = web is Map ? web['results'] : null;
    if (list is! List) return const [];
    return [
      for (final r in list.whereType<Map>())
        if (r['url'] is String)
          WebResult(
            title: _text('${r['title'] ?? ''}'),
            url: r['url'] as String,
            snippet: _text('${r['description'] ?? ''}'),
          ),
    ];
  }

  static List<WebResult> parseSearxng(String body) {
    final data = _json(body);
    final list = data is Map ? data['results'] : null;
    if (list is! List) return const [];
    return [
      for (final r in list.whereType<Map>())
        if (r['url'] is String)
          WebResult(
            title: _text('${r['title'] ?? ''}'),
            url: r['url'] as String,
            snippet: _text('${r['content'] ?? ''}'),
          ),
    ];
  }

  /// The results as the model reads them: numbered, so it can cite them.
  static String asContext(List<WebResult> results) => [
        for (var i = 0; i < results.length; i++)
          '[${i + 1}] ${results[i].title}\n${results[i].url}\n'
              '${results[i].snippet}',
      ].join('\n\n');

  static Object? _json(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Plain text from an HTML fragment.
  static String _text(String html) => _unescape(html
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' '))
      .trim();

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
