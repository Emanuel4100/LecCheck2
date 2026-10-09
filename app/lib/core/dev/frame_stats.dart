import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';

/// How smooth the app has been: frame timings since start (the last 600
/// frames), for Settings → Developer → Rendering and diagnostics. Flutter
/// reports them in batches (about once a second in release builds), so
/// watching costs next to nothing.
class FrameStats {
  FrameStats._();

  static final instance = FrameStats._();

  static const _keep = 600;
  final _frames = ListQueue<FrameTiming>();
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(add);
  }

  /// Records frames (the timings callback; also for tests).
  void add(List<FrameTiming> timings) {
    _frames.addAll(timings);
    while (_frames.length > _keep) {
      _frames.removeFirst();
    }
  }

  void reset() => _frames.clear();

  /// Null until there are enough frames to say anything.
  FrameSummary? summary({required double refreshRate}) {
    if (_frames.length < 10) return null;
    return FrameSummary.of(_frames.toList(), refreshRate: refreshRate);
  }
}

/// Frame timings in numbers.
class FrameSummary {
  const FrameSummary({
    required this.frames,
    required this.refreshRate,
    required this.interval,
    required this.build,
    required this.raster,
    required this.overBudget,
  });

  factory FrameSummary.of(
    List<FrameTiming> frames, {
    required double refreshRate,
  }) {
    // Frames come only while something moves: the time between frames of
    // one animation shows the real frame rate (idle gaps don't count).
    final starts = [
      for (final f in frames) f.timestampInMicroseconds(FramePhase.vsyncStart),
    ];
    final gaps = <int>[
      for (var i = 1; i < starts.length; i++)
        if (starts[i] - starts[i - 1] case final gap
            when gap > 0 && gap < 100000)
          gap,
    ];
    final budget = refreshRate > 0 ? 1e6 / refreshRate : 1e6 / 60;
    final over = frames
        .where(
          (f) =>
              f.buildDuration.inMicroseconds > budget ||
              f.rasterDuration.inMicroseconds > budget,
        )
        .length;
    return FrameSummary(
      frames: frames.length,
      refreshRate: refreshRate,
      interval: gaps.isEmpty
          ? null
          : Duration(microseconds: _percentile(gaps, 0.5)),
      build: TimingSpread.of([
        for (final f in frames) f.buildDuration.inMicroseconds,
      ]),
      raster: TimingSpread.of([
        for (final f in frames) f.rasterDuration.inMicroseconds,
      ]),
      overBudget: over / frames.length,
    );
  }

  final int frames;

  /// What the display reports (Hz).
  final double refreshRate;

  /// The usual time between two frames of an animation; null without one.
  final Duration? interval;
  final TimingSpread build;
  final TimingSpread raster;

  /// Share of frames whose build or raster took longer than one refresh.
  final double overBudget;

  /// Frames per second while animating.
  double? get fps => interval == null ? null : 1e6 / interval!.inMicroseconds;

  @override
  String toString() {
    final rate = fps;
    return [
      '${refreshRate.round()} Hz display',
      if (rate != null) '${rate.round()} fps while animating',
      'build $build',
      'raster $raster',
      '${(overBudget * 100).toStringAsFixed(1)}% over budget',
      '$frames frames',
    ].join(', ');
  }
}

/// p50 / p90 / max of a timing, in ms.
class TimingSpread {
  const TimingSpread(this.p50, this.p90, this.max);

  factory TimingSpread.of(List<int> micros) => TimingSpread(
    _percentile(micros, 0.5),
    _percentile(micros, 0.9),
    micros.reduce(math.max),
  );

  final int p50;
  final int p90;
  final int max;

  static String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

  @override
  String toString() => 'p50 ${_ms(p50)} / p90 ${_ms(p90)} / max ${_ms(max)} ms';
}

int _percentile(List<int> values, double p) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * p).round()];
}
