import 'dart:async';

/// Hands a reply's tokens to the screen a few times a second instead of
/// once per token.
///
/// Each update makes the chat re-read the whole reply (Markdown, thinking
/// tags) on the UI thread. On a phone the model runs on every fast core, so
/// that work takes time away from it: the more often the screen updates,
/// the slower the model generates. A fast model produces tokens far quicker
/// than anyone reads them, so grouping them costs nothing visible.
///
/// The first token is delivered at once; the following ones are grouped
/// and delivered every [interval].
class TokenCoalescer {
  final void Function(String text) onText;
  final Duration interval;

  final _waiting = StringBuffer();
  Timer? _timer;

  TokenCoalescer({
    required this.onText,
    this.interval = const Duration(milliseconds: 80),
  });

  /// Takes the next token of the reply.
  void add(String token) {
    if (token.isEmpty) return;
    if (_timer == null) {
      // Nothing delivered lately: show it now, and group what follows.
      onText(token);
      _timer = Timer(interval, _deliver);
      return;
    }
    _waiting.write(token);
  }

  void _deliver() {
    _timer = null;
    if (_waiting.isEmpty) return;
    final text = _waiting.toString();
    _waiting.clear();
    onText(text);
    // More tokens are probably on their way: keep grouping them.
    _timer = Timer(interval, _deliver);
  }

  /// Delivers what is still waiting, right now. Call it when the reply
  /// ends or is stopped, before reading the text shown so far.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_waiting.isEmpty) return;
    final text = _waiting.toString();
    _waiting.clear();
    onText(text);
  }
}
