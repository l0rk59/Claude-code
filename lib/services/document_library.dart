import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// A passage of one of the user's documents.
class DocChunk {
  final String document;
  final String text;
  const DocChunk(this.document, this.text);
}

/// A document of the library, cut into passages.
class LibraryDocument {
  final String id;
  final String name;
  final DateTime added;
  final List<String> chunks;

  const LibraryDocument({
    required this.id,
    required this.name,
    required this.added,
    required this.chunks,
  });

  int get characters => chunks.fold(0, (sum, c) => sum + c.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'added': added.millisecondsSinceEpoch,
        'chunks': chunks,
      };

  factory LibraryDocument.fromJson(Map<String, dynamic> json) =>
      LibraryDocument(
        id: '${json['id']}',
        name: '${json['name']}',
        added: DateTime.fromMillisecondsSinceEpoch(
            (json['added'] as num?)?.toInt() ?? 0),
        chunks: [for (final c in json['chunks'] as List? ?? const []) '$c'],
      );
}

/// The user's documents, searched on the phone to answer questions about
/// them: the passages that match a question go into it, so the model reads
/// only what matters instead of whole files that wouldn't fit.
///
/// Search is by words (BM25), which needs no extra model and works offline.
class DocumentLibrary {
  final File _file;
  final List<LibraryDocument> documents = [];

  DocumentLibrary(this._file);

  static const chunkSize = 900;
  static const _overlap = 150;

  Future<void> load() async {
    documents.clear();
    try {
      if (!await _file.exists()) return;
      final data = jsonDecode(await _file.readAsString());
      for (final d in (data as List).whereType<Map>()) {
        documents.add(LibraryDocument.fromJson(Map<String, dynamic>.from(d)));
      }
    } catch (_) {
      // A damaged library starts empty rather than blocking the chat.
    }
  }

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
        jsonEncode([for (final d in documents) d.toJson()]));
    await temp.rename(_file.path);
  }

  /// Adds [text] as a document named [name]. A document of the same name
  /// is replaced.
  Future<LibraryDocument> add(String name, String text,
      {DateTime? now}) async {
    final document = LibraryDocument(
      id: '${(now ?? DateTime.now()).microsecondsSinceEpoch}',
      name: name,
      added: now ?? DateTime.now(),
      chunks: split(text),
    );
    documents.removeWhere((d) => d.name == name);
    documents.add(document);
    await _save();
    return document;
  }

  Future<void> remove(String id) async {
    documents.removeWhere((d) => d.id == id);
    await _save();
  }

  /// Cuts [text] into passages of about [chunkSize] characters, ending on a
  /// paragraph or a sentence when possible, each overlapping the previous
  /// one a little so an idea cut in two is still found whole.
  static List<String> split(String text) {
    final clean = text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (clean.isEmpty) return const [];
    final chunks = <String>[];
    var start = 0;
    while (start < clean.length) {
      var end = math.min(start + chunkSize, clean.length);
      if (end < clean.length) {
        final window = clean.substring(start, end);
        final cut = [
          window.lastIndexOf('\n\n'),
          window.lastIndexOf('. '),
          window.lastIndexOf('\n'),
        ].firstWhere((i) => i > chunkSize ~/ 2, orElse: () => -1);
        if (cut > 0) end = start + cut + 1;
      }
      final chunk = clean.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      if (end >= clean.length) break;
      start = math.max(end - _overlap, start + 1);
      // Start the next passage at a word.
      final space = clean.indexOf(' ', start);
      if (space > 0 && space < end) start = space + 1;
    }
    return chunks;
  }

  static const _stopWords = {
    // French
    'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'd', 'l', 'et', 'ou',
    'a', 'au', 'aux', 'en', 'dans', 'par', 'pour', 'sur', 'avec', 'sans',
    'ce', 'ces', 'cet', 'cette', 'est', 'sont', 'qui', 'que', 'quoi', 'qu',
    'il', 'elle', 'ils', 'elles', 'on', 'nous', 'vous', 'je', 'tu', 'me',
    'te', 'se', 'ne', 'pas', 'plus', 'son', 'sa', 'ses', 'leur', 'leurs',
    'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'y', 'c', 'n', 's', 'j', 'm',
    'comment', 'quel', 'quelle', 'quels', 'quelles', 'dit', 'parle',
    // English
    'the', 'an', 'and', 'of', 'to', 'in', 'for', 'with', 'is',
    'are', 'was', 'were', 'be', 'it', 'this', 'that', 'what', 'which', 'how',
    'who', 'does', 'do', 'about', 'my', 'i', 'you',
  };

  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e',
    'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o',
    'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'ñ': 'n',
    'œ': 'oe', 'æ': 'ae',
  };

  /// Words as compared: lower case, without accents, without the plural
  /// "s"/"x", without the most common small words.
  static List<String> words(String text) {
    final lower = text.toLowerCase();
    final plain = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      plain.write(_accents[c] ?? c);
    }
    return [
      for (final w in plain.toString().split(RegExp(r'[^a-z0-9]+')))
        if (w.isNotEmpty && !_stopWords.contains(w)) _stem(w),
    ];
  }

  static String _stem(String w) {
    if (w.length > 4 && (w.endsWith('s') || w.endsWith('x'))) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  /// The [count] passages that best match [query], best first. Passages
  /// sharing no word with it are left out.
  List<DocChunk> search(String query, {int count = 4}) {
    final terms = words(query).toSet();
    if (terms.isEmpty) return const [];
    final passages = [
      for (final d in documents)
        for (final c in d.chunks) (document: d.name, text: c, words: words(c)),
    ];
    if (passages.isEmpty) return const [];

    // BM25: rare words weigh more than common ones, repeated words count
    // less and less, and long passages don't win just by being long.
    const k1 = 1.4, b = 0.75;
    final n = passages.length;
    final average =
        passages.fold<int>(0, (sum, p) => sum + p.words.length) / n;
    final containing = <String, int>{
      for (final t in terms)
        t: passages.where((p) => p.words.contains(t)).length,
    };
    final scored = <(double, int)>[];
    for (var i = 0; i < n; i++) {
      final p = passages[i];
      var score = 0.0;
      for (final t in terms) {
        final f = p.words.where((w) => w == t).length;
        if (f == 0) continue;
        final df = containing[t]!;
        final idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
        score += idf *
            (f * (k1 + 1)) /
            (f + k1 * (1 - b + b * p.words.length / math.max(average, 1)));
      }
      if (score > 0) scored.add((score, i));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [
      for (final (_, i) in scored.take(count))
        DocChunk(passages[i].document, passages[i].text),
    ];
  }

  /// The passages as the model reads them, each with its document.
  static String asContext(List<DocChunk> chunks) => [
        for (var i = 0; i < chunks.length; i++)
          '[${i + 1}] (${chunks[i].document})\n${chunks[i].text}',
      ].join('\n\n');
}
