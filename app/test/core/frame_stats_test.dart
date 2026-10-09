import 'dart:ui' show FrameTiming;

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/dev/frame_stats.dart';

/// A frame starting at [start] µs, building for [build] and rastering for
/// [raster] µs.
FrameTiming _frame(int start, {int build = 2000, int raster = 3000}) =>
    FrameTiming(
      vsyncStart: start,
      buildStart: start,
      buildFinish: start + build,
      rasterStart: start + build,
      rasterFinish: start + build + raster,
      rasterFinishWallTime: start + build + raster,
    );

void main() {
  test('60 fps on a 100 Hz display (Flutter on Linux), idle gaps ignored', () {
    final frames = [
      for (var i = 0; i < 30; i++) _frame(i * 16667),
      // Two seconds of nothing, then another animation.
      for (var i = 0; i < 30; i++) _frame(2500000 + i * 16667),
    ];
    final summary = FrameSummary.of(frames, refreshRate: 100);
    expect(summary.fps!.round(), 60);
    expect(summary.overBudget, 0);
    expect(summary.build.p50, 2000);
  });

  test('counts frames slower than one refresh', () {
    final frames = [
      for (var i = 0; i < 9; i++) _frame(i * 10000),
      _frame(90000, raster: 15000), // over the 10 ms budget at 100 Hz
    ];
    final summary = FrameSummary.of(frames, refreshRate: 100);
    expect(summary.overBudget, closeTo(0.1, 1e-9));
    expect(summary.raster.max, 15000);
    expect(summary.fps!.round(), 100);
  });
}
