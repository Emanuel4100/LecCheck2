import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/sync/hlc.dart';

void main() {
  test('packs to a fixed width that sorts like compareTo', () {
    final a = Hlc(1759570000000, 2, 'aaaa');
    final b = Hlc(1759570000000, 10, 'aaaa');
    final c = Hlc(1759570000001, 0, 'aaaa');
    expect(a.pack().length, b.pack().length);
    final packed = [c.pack(), b.pack(), a.pack()]..sort();
    expect(packed, [a.pack(), b.pack(), c.pack()]);
    expect(Hlc.parse(b.pack()), b);
  });

  test('tick is monotonic even when the wall clock goes back', () {
    var wall = 1000;
    final clock = HlcClock(node: 'n1', wallClock: () => wall);
    final t1 = clock.tick();
    wall = 500; // clock jumped backwards
    final t2 = clock.tick();
    wall = 2000;
    final t3 = clock.tick();
    expect(t2.compareTo(t1), greaterThan(0));
    expect(t3.compareTo(t2), greaterThan(0));
    expect(t3.millis, 2000);
  });

  test('receive moves past remote timestamps', () {
    var wall = 1000;
    final clock = HlcClock(node: 'n1', wallClock: () => wall);
    clock.tick();
    clock.receive(Hlc(5000, 3, 'n2'));
    final next = clock.tick();
    expect(next.compareTo(Hlc(5000, 3, 'n2')), greaterThan(0));
    wall = 6000;
    expect(clock.tick().millis, 6000);
  });

  test('correct adopts server time and steps back from a runaway clock', () {
    var wall = 10 * 60 * 1000; // The device runs 10 minutes fast.
    final clock = HlcClock(node: 'n1', wallClock: () => wall);
    final runaway = clock.tick();
    const serverNow = 0;
    clock.correct(serverNow);
    final next = clock.tick();
    // Within the server's 5-minute limit, and still after anything it took.
    expect(next.millis, lessThanOrEqualTo(serverNow + 5 * 60 * 1000));
    expect(next.millis, greaterThan(serverNow));
    expect(next.compareTo(runaway), lessThan(0));
    // Later ticks follow server time.
    wall += 60 * 60 * 1000;
    expect(clock.tick().millis, serverNow + 60 * 60 * 1000);
  });

  test('a full counter moves on to the next millisecond', () {
    final clock = HlcClock(
      node: 'n1',
      last: const Hlc(1000, 0xffff, 'n1'),
      wallClock: () => 0,
    );
    final next = clock.tick();
    expect((next.millis, next.counter), (1001, 0));
    expect(next.pack().length, const Hlc(1000, 0, 'n1').pack().length);
    clock.receive(const Hlc(5000, 0xffff, 'n2'));
    expect((clock.last.millis, clock.last.counter), (5001, 0));
  });
}
