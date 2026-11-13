import 'dart:io';

/// Big GGUF models are published in parts: "name-00001-of-00003.gguf",
/// "name-00002-of-00003.gguf"… llama.cpp loads the whole model from the
/// first part, as long as the others sit next to it under these exact
/// names. So the app downloads, counts and deletes the parts together, and
/// shows the model once, under its first part.
class GgufSplit {
  // The engine builds part names with "%s-%05d-of-%05d.gguf".
  static final _pattern =
      RegExp(r'^(.+)-(\d{5})-of-(\d{5})\.gguf$', caseSensitive: false);

  final String prefix;

  /// 1 for the first part.
  final int index;
  final int count;

  const GgufSplit._(this.prefix, this.index, this.count);

  /// The split [filename] belongs to, or null when it is a whole model.
  static GgufSplit? parse(String filename) {
    final name = filename.split('/').last;
    final match = _pattern.firstMatch(name);
    if (match == null) return null;
    final index = int.parse(match[2]!);
    final count = int.parse(match[3]!);
    if (count < 2 || index < 1 || index > count) return null;
    return GgufSplit._(match[1]!, index, count);
  }

  static String _pad(int n) => n.toString().padLeft(5, '0');

  /// Every part, first to last.
  List<String> get names => [
        for (var i = 1; i <= count; i++)
          '$prefix-${_pad(i)}-of-${_pad(count)}.gguf',
      ];

  /// A part other than the first: it is part of a model, not one itself.
  static bool isLaterPart(String filename) =>
      (parse(filename)?.index ?? 1) > 1;

  /// The files a model is made of: all its parts, or just itself.
  static List<String> filesOf(String filename) {
    final split = parse(filename);
    return split == null ? [filename] : split.names;
  }

  /// Where [part] downloads from, next to [url] (parts share a folder).
  static String urlOf(String url, String part) {
    final slash = url.lastIndexOf('/');
    return slash < 0 ? part : '${url.substring(0, slash + 1)}$part';
  }

  /// The size of the model whose first file is at [path]: the sum of its
  /// parts on disk. Missing parts count as nothing.
  static Future<int> bytesOnDisk(String path) async {
    final slash = path.lastIndexOf('/');
    final dir = slash < 0 ? '' : path.substring(0, slash + 1);
    var total = 0;
    for (final name in filesOf(path.substring(slash + 1))) {
      final file = File('$dir$name');
      if (await file.exists()) total += await file.length();
    }
    return total;
  }
}
