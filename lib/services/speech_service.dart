import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

/// Reads answers aloud with the phone's own speech engine (it works
/// offline once the voice is installed).
class SpeechService extends GetxService {
  final FlutterTts _tts = FlutterTts();

  /// The message being read, or null.
  final speaking = RxnString();

  /// Android reads at most about 4000 characters at a time.
  static const _maxPiece = 3500;

  /// Reads [text] for message [id], or stops if that message is already
  /// being read. [language] is like "fr-FR".
  Future<void> toggle(String id, String text, {String language = 'fr-FR'}) async {
    if (speaking.value == id) {
      await stop();
      return;
    }
    await stop();
    speaking.value = id;
    try {
      await _tts.setLanguage(language);
      await _tts.awaitSpeakCompletion(true);
      for (final piece in pieces(plain(text))) {
        if (speaking.value != id) break;
        await _tts.speak(piece);
      }
    } catch (_) {
      // No speech engine or voice: nothing is read.
    } finally {
      if (speaking.value == id) speaking.value = null;
    }
  }

  Future<void> stop() async {
    speaking.value = null;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// [markdown] as it should sound: without code, links' addresses,
  /// formatting marks, the model's thinking or the sources list.
  static String plain(String markdown) {
    var text = markdown
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), ' ')
        .replaceAll(RegExp(r'\n\n---\n[\s\S]*$'), '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~|>]+'), '')
        .replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
  }

  /// [text] cut at sentence ends into pieces the engine accepts.
  static List<String> pieces(String text, {int max = _maxPiece}) {
    final result = <String>[];
    var rest = text.trim();
    while (rest.length > max) {
      var cut = rest.lastIndexOf(RegExp(r'[.!?\n]'), max);
      if (cut < max ~/ 2) cut = rest.lastIndexOf(' ', max);
      if (cut <= 0) cut = max;
      result.add(rest.substring(0, cut + 1).trim());
      rest = rest.substring(cut + 1).trim();
    }
    if (rest.isNotEmpty) result.add(rest);
    return result;
  }
}
