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
}
