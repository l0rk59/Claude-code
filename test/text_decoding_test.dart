import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/document_extractor_service.dart';
import 'package:privatelm/utils/text_decoding.dart';

void main() {
  test('UTF-8, with or without a byte-order mark', () {
    expect(decodeText(utf8.encode('Café')), 'Café');
    expect(decodeText([0xEF, 0xBB, 0xBF, ...utf8.encode('Prix;€')]), 'Prix;€');
  });

  test('a CSV saved by Excel in France (Windows-1252) keeps its accents', () {
    // "Café;12,50 €" in Windows-1252: é = 0xE9, € = 0x80.
    final bytes = [
      ...latin1.encode('Caf'),
      0xE9,
      ...latin1.encode(';12,50 '),
      0x80
    ];
    expect(decodeText(bytes), 'Café;12,50 €');
    expect(decodeText([0x93, 0x6F, 0x6B, 0x94, 0x20, 0x9C]), '“ok” œ');
  });

  test('HTML documents are read as text', () async {
    final dir = await Directory.systemTemp.createTemp('html_doc');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/page.html')
      ..writeAsStringSync('<html><head><title>Recette</title>'
          '<style>p{color:red}</style></head><body><nav>Menu</nav>'
          '<h1>Cr&egrave;me br&ucirc;l&eacute;e</h1><p>Sucre &amp; '
          '&#233;pices &lt;3</p><script>alert(1)</script></body></html>');
    final text = await DocumentExtractorService.extractText(file.path, 'html');
    expect(text, startsWith('Recette'));
    expect(text, contains('Crème brûlée'));
    expect(text, contains('Sucre & épices <3'));
    expect(text, isNot(contains('alert')));
    expect(text, isNot(contains('Menu')));
    expect(text, isNot(contains('color')));
  });

  test('entities: one pass, so &amp;lt; stays &lt; as written', () {
    expect(htmlText('&laquo;&nbsp;Oui&nbsp;&raquo; &amp;lt; &#x1F600; &zzz;'),
        '« Oui » &lt; 😀 &zzz;');
  });
}
