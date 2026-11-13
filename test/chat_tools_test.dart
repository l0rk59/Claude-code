import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/chat_tools.dart';
import 'package:privatelm/services/document_library.dart';
import 'package:privatelm/services/speech_service.dart';
import 'package:privatelm/services/web_search_service.dart';

void main() {
  const web = [
    WebResult(
        title: 'Tarifs [2026] | CRE',
        url: 'https://www.cre.fr/tarifs',
        snippet: 'Le tarif bleu baisse de 2,6 %.'),
  ];
  const passages = [
    DocChunk('bail.pdf', 'Le dépôt de garantie est d’un mois.'),
    DocChunk('bail.pdf', 'Le loyer est de 850 €.'),
  ];

  test('the question comes after what was found, untouched otherwise', () {
    final context = ChatTools.context(web, passages);
    expect(context, startsWith('[1] Tarifs [2026] | CRE'));
    expect(context, contains('[1] (bail.pdf)'));
    final prompt = ChatTools.withContext('Combien ?', context, 'Réponds :');
    expect(prompt, startsWith('Réponds :\n\n[1]'));
    expect(prompt, endsWith('---\n\nCombien ?'));
    expect(ChatTools.withContext('Combien ?', '', 'Réponds :'), 'Combien ?');
  });

  test('lists sources under the answer, and takes them off for the model', () {
    final footer = ChatTools.footer(
        web: web,
        passages: passages,
        webTitle: 'Sources',
        passagesTitle: 'Extraits utilisés');
    expect(footer,
        '\n\n---\n**Sources**\n1. [Tarifs (2026) | CRE](https://www.cre.fr/tarifs)\n\n**Extraits utilisés**\n- bail.pdf');
    const answer = 'Le tarif baisse de 2,6 % [1].';
    expect(ChatTools.stripFooter('$answer$footer'), answer);
    // Documents only, in English.
    final docsOnly = ChatTools.footer(
        web: const [],
        passages: passages,
        webTitle: 'Sources',
        passagesTitle: 'Excerpts used');
    expect(ChatTools.stripFooter('$answer$docsOnly'), answer);
    // A rule the model wrote itself is left alone.
    expect(ChatTools.stripFooter('A\n\n---\nB'), 'A\n\n---\nB');
    expect(
        ChatTools.footer(
            web: const [], passages: const [], webTitle: 'S', passagesTitle: 'E'),
        '');
  });

  test('reads an answer aloud without its formatting, links or sources', () {
    final spoken = SpeechService.plain('''
<think>let me think</think>
## Réponse
Le **tarif** baisse, voir [la CRE](https://www.cre.fr) et `code`.

```dart
print(1);
```
- premier point
https://example.com

---
**Sources**
1. [CRE](https://www.cre.fr)''');
    expect(spoken, 'Réponse\nLe tarif baisse, voir la CRE et code.\npremier point');
  });

  test('long answers are read in pieces cut at sentence ends', () {
    final text = List.filled(400, 'Une phrase assez courte.').join(' ');
    final pieces = SpeechService.pieces(text, max: 500);
    expect(pieces.length, greaterThan(10));
    for (final p in pieces) {
      expect(p.length, lessThanOrEqualTo(500));
      expect(p, endsWith('.'));
    }
    expect(pieces.join(' '), text);
    expect(SpeechService.pieces('Court.'), ['Court.']);
    expect(SpeechService.pieces('   '), isEmpty);
  });
}
