/// Text from files and pages, whatever their encoding, and the readable
/// text of HTML.
library;

import 'dart:convert';

/// Text from a file: UTF-8 (a leading byte-order mark dropped), or else
/// Windows' Western code page, in which Excel in France saves CSV files and
/// many older text files are written ("é" would otherwise come out as "�").
String decodeText(List<int> bytes) {
  try {
    final text = utf8.decode(bytes);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  } on FormatException {
    return String.fromCharCodes([
      for (final b in bytes) b >= 0x80 && b < 0xA0 ? _cp1252[b - 0x80] : b,
    ]);
  }
}

/// Windows-1252 from 0x80 to 0x9F (the rest is Latin-1); unused codes keep
/// their value.
const _cp1252 = [
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178, //
];

/// The readable text of an HTML page: its title, then its text without
/// scripts, styles, menus or footers.
String htmlText(String html) {
  final title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
          .firstMatch(html)?[1] ??
      '';
  var text = html
      .replaceAll(
          RegExp(
              r'<(head|title|script|style|noscript|svg|nav|header|footer|form|aside)\b[\s\S]*?</\1>',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
      .replaceAll(
          RegExp(r'<(br|p|div|li|h[1-6]|tr|section|article)\b[^>]*>',
              caseSensitive: false),
          '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = _entities(text)
      .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
      .replaceAll(RegExp(r'\s*\n\s*'), '\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  final heading = _entities(title).replaceAll(RegExp(r'\s+'), ' ').trim();
  return heading.isEmpty ? text : '$heading\n\n$text';
}

/// Named entities of French and everyday text; numbered ones are decoded
/// from their code.
const _named = {
  'nbsp': '\u00A0',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
  'eacute': 'é',
  'egrave': 'è',
  'ecirc': 'ê',
  'euml': 'ë',
  'agrave': 'à',
  'acirc': 'â',
  'auml': 'ä',
  'ccedil': 'ç',
  'icirc': 'î',
  'iuml': 'ï',
  'ocirc': 'ô',
  'ouml': 'ö',
  'ugrave': 'ù',
  'ucirc': 'û',
  'uuml': 'ü',
  'oelig': 'œ',
  'aelig': 'æ',
  'Eacute': 'É',
  'Egrave': 'È',
  'Ecirc': 'Ê',
  'Agrave': 'À',
  'Ccedil': 'Ç',
  'OElig': 'Œ',
  'laquo': '«',
  'raquo': '»',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'euro': '€',
  'deg': '°',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'times': '×',
  'middot': '·',
  'bull': '•',
};

String _entities(String s) =>
    s.replaceAllMapped(RegExp(r'&(#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z]+);'), (m) {
      final name = m[1]!;
      if (name.startsWith('#')) {
        final hex = name.length > 1 && (name[1] == 'x' || name[1] == 'X');
        final code =
            int.tryParse(name.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
        return code == null || code > 0x10FFFF
            ? m[0]!
            : String.fromCharCode(code);
      }
      if (name == 'amp') return '&';
      return _named[name] ?? m[0]!;
    });
