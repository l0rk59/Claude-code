import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:privatelm/services/web_search_service.dart';

void main() {
  test('reads DuckDuckGo results, without its ads, links unwrapped', () {
    final results = WebSearchService.parseDuckDuckGo(
        File('test/fixtures/ddg_results.html').readAsStringSync());
    expect(results, hasLength(2));
    expect(results[0].title, "Tarifs réglementés de vente d'électricité | CRE");
    expect(results[0].url, 'https://www.cre.fr/tarifs-electricite');
    expect(results[0].snippet,
        'Au 1er février 2026, le tarif bleu résidentiel baisse de 2,6 % & reste stable.');
    expect(results[1].url, 'https://fr.wikipedia.org/wiki/Électricité');
  });

  test('reads Brave and SearXNG answers', () {
    final brave = WebSearchService.parseBrave(jsonEncode({
      'web': {
        'results': [
          {'title': 'A <strong>b</strong>', 'url': 'https://a.example', 'description': 'd'},
          {'title': 'no url'},
        ]
      }
    }));
    expect(brave.single.title, 'A b');
    expect(brave.single.snippet, 'd');

    final searx = WebSearchService.parseSearxng(jsonEncode({
      'results': [
        {'title': 'S', 'url': 'https://s.example', 'content': 'c'},
      ]
    }));
    expect(searx.single.url, 'https://s.example');
    expect(WebSearchService.parseSearxng('<html>'), isEmpty);
  });

  test('numbers the sources for the model', () {
    final text = WebSearchService.asContext(const [
      WebResult(title: 'A', url: 'https://a', snippet: 'one'),
      WebResult(title: 'B', url: 'https://b', snippet: 'two'),
    ]);
    expect(text, '[1] A\nhttps://a\none\n\n[2] B\nhttps://b\ntwo');
  });

  test('asks each provider the right way', () async {
    final asked = <http.BaseRequest>[];
    final service = WebSearchService(
      client: MockClient((request) async {
        asked.add(request);
        if (request.url.host == 'html.duckduckgo.com') {
          return http.Response.bytes(
              utf8.encode(File('test/fixtures/ddg_results.html').readAsStringSync()),
              200);
        }
        if (request.url.host == 'api.search.brave.com') {
          return http.Response(jsonEncode({'web': {'results': []}}), 200);
        }
        return http.Response(jsonEncode({'results': []}), 200);
      }),
    );
    final ddg = await service.search('prix électricité', count: 1);
    expect(ddg.single.url, 'https://www.cre.fr/tarifs-electricite');
    expect((asked.last as http.Request).bodyFields['q'], 'prix électricité');

    await service.search('x',
        provider: WebSearchProvider.brave, braveKey: ' k ');
    expect(asked.last.headers['X-Subscription-Token'], 'k');

    await service.search('x',
        provider: WebSearchProvider.searxng,
        searxngUrl: 'http://192.168.1.20:8888/');
    expect(asked.last.url.toString(),
        'http://192.168.1.20:8888/search?q=x&format=json&language=fr');
  });

  test('says why a search failed', () async {
    Future<String> failure(http.Response answer,
        {WebSearchProvider provider = WebSearchProvider.duckDuckGo,
        String key = 'k',
        String url = 'http://s'}) async {
      final service =
          WebSearchService(client: MockClient((_) async => answer));
      try {
        await service.search('x',
            provider: provider, braveKey: key, searxngUrl: url);
        return 'no failure';
      } on WebSearchException catch (e) {
        return e.message;
      }
    }

    expect(
        await failure(http.Response(
            '<div class="anomaly-modal">Unfortunately, bots use DuckDuckGo too.</div>',
            202)),
        'busy');
    expect(await failure(http.Response('', 429)), 'busy');
    expect(await failure(http.Response('', 401), provider: WebSearchProvider.brave),
        'refused');
    expect(await failure(http.Response('', 403), provider: WebSearchProvider.searxng),
        'searxng-json');
    expect(
        await failure(http.Response('', 200),
            provider: WebSearchProvider.brave, key: ''),
        'brave-key');
    expect(
        await failure(http.Response('', 200),
            provider: WebSearchProvider.searxng, url: 'not a url'),
        'searxng-url');
    final offline = WebSearchService(
        client: MockClient((_) async => throw const SocketException('down')));
    expect(() => offline.search('x'), throwsA(isA<WebSearchException>()));
  });
}
