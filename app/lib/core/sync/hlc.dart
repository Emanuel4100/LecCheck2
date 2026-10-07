import 'dart:math' as math;

/// Hybrid logical clock timestamp: wall-clock millis + counter + node id.
///
/// Packed as a fixed-width string so plain string comparison (used by the
/// server's per-field merge) matches [compareTo].
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node);

  factory Hlc.parse(String packed) {
    final parts = packed.split(':');
    if (parts.length != 3) throw FormatException('Bad HLC', packed);
    return Hlc(int.parse(parts[0]), int.parse(parts[1], radix: 16), parts[2]);
  }

  static Hlc zero(String node) => Hlc(0, 0, node);

  final int millis;
  final int counter;
  final String node;

  String pack() =>
      '${millis.toString().padLeft(15, '0')}:${counter.toRadixString(16).padLeft(4, '0')}:$node';

  @override
  int compareTo(Hlc other) {
    var c = millis.compareTo(other.millis);
    if (c != 0) return c;
    c = counter.compareTo(other.counter);
    if (c != 0) return c;
    return node.compareTo(other.node);
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() => pack();
}

/// Issues monotonically increasing [Hlc]s for this device, even if the wall
/// clock jumps backwards.
class HlcClock {
  HlcClock({required this.node, Hlc? last, int Function()? wallClock})
    : _last = last ?? Hlc.zero(node),
      _wallClock = wallClock ?? _systemMillis;

  final String node;
  final int Function() _wallClock;
  Hlc _last;

  /// Added to the device clock: server time minus device time.
  int offsetMs = 0;

  Hlc get last => _last;

  static int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

  int _wall() => _wallClock() + offsetMs;

  /// Adopts the server's time. A wrong device clock would otherwise stamp
  /// edits the server refuses (too far ahead) or that lose every merge (too
  /// far behind).
  ///
  /// If this clock already ran past what the server accepts ([maxAheadMs],
  /// its skew limit), it steps back to just under that limit: still later
  /// than anything the server took, so new edits keep winning, but accepted.
  void correct(int serverNow, {int maxAheadMs = 5 * 60 * 1000}) {
    offsetMs = serverNow - _wallClock();
    if (_last.millis > serverNow + maxAheadMs) {
      _last = Hlc(serverNow + maxAheadMs - 60 * 1000, 0, node);
    }
  }

  /// Timestamp for a local change.
  Hlc tick() {
    final wall = _wall();
    _last = wall > _last.millis
        ? Hlc(wall, 0, node)
        : Hlc(_last.millis, _last.counter + 1, node);
    return _last;
  }

  /// Moves past a timestamp seen from another device, so later local edits
  /// always win over what we already received.
  void receive(Hlc remote) {
    final wall = _wall();
    final millis = math.max(wall, math.max(_last.millis, remote.millis));
    final int counter;
    if (millis == _last.millis && millis == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (millis == _last.millis) {
      counter = _last.counter + 1;
    } else if (millis == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    _last = Hlc(millis, counter, node);
  }
}
