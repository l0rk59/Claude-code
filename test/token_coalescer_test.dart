import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/token_coalescer.dart';

void main() {
  const tick = Duration(milliseconds: 80);

  test('the first token shows at once, the next ones are grouped', () {
    fakeAsync((async) {
      final shown = <String>[];
      final stream = TokenCoalescer(onText: shown.add, interval: tick);

      stream.add('Hello');
      expect(shown, ['Hello']);

      stream.add(' wor');
      stream.add('ld');
      stream.add('!');
      expect(shown, ['Hello'], reason: 'still within the interval');

      async.elapse(tick);
      expect(shown, ['Hello', ' world!']);
    });
  });

  test('a fast model updates the screen far less often than it speaks', () {
    fakeAsync((async) {
      var updates = 0;
      final text = StringBuffer();
      final stream = TokenCoalescer(
          onText: (t) {
            updates++;
            text.write(t);
          },
          interval: tick);

      // 40 tokens a second for two seconds.
      for (var i = 0; i < 80; i++) {
        stream.add('t$i ');
        async.elapse(const Duration(milliseconds: 25));
      }
      stream.flush();

      expect(text.toString(), [for (var i = 0; i < 80; i++) 't$i '].join());
      expect(updates, lessThanOrEqualTo(27));
      expect(updates, greaterThanOrEqualTo(20));
    });
  });

  test('a slow model still shows every token as it comes', () {
    fakeAsync((async) {
      final shown = <String>[];
      final stream = TokenCoalescer(onText: shown.add, interval: tick);
      // 4 tokens a second: each one arrives after the interval has passed.
      for (final token in ['a', 'b', 'c']) {
        stream.add(token);
        async.elapse(const Duration(milliseconds: 250));
      }
      expect(shown, ['a', 'b', 'c']);
    });
  });

  test('flush delivers what is waiting, once', () {
    fakeAsync((async) {
      final shown = <String>[];
      final stream = TokenCoalescer(onText: shown.add, interval: tick);
      stream.add('a');
      stream.add('b');
      stream.add('c');
      stream.flush();
      expect(shown, ['a', 'bc']);

      // Nothing left for the timer, and nothing delivered twice.
      async.elapse(tick * 3);
      stream.flush();
      expect(shown, ['a', 'bc']);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('no timer is left running after a reply', () {
    fakeAsync((async) {
      final stream = TokenCoalescer(onText: (_) {}, interval: tick);
      stream.add('only');
      async.elapse(tick);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
