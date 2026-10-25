import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/time_slots.dart';

void main() {
  // 8:00–18:00, 60 px per hour: 1 px = 1 minute.
  const grid = GridTimes(startHour: 8, endHour: 18, hourHeight: 60);

  test('a tap: an hour from the half hour it falls in', () {
    expect(grid.tapped(0), (start: 480, end: 540));
    expect(grid.tapped(50), (start: 510, end: 570)); // 8:50 → 8:30
    expect(grid.tapped(125, length: 120), (start: 600, end: 720));
    // Near the end the slot stops at the grid's last hour.
    expect(grid.tapped(585), (start: 1050, end: 1080));
  });

  test('a drag: snapped to 15 minutes, either direction, inside the grid', () {
    expect(grid.between(60, 180), (start: 540, end: 660));
    expect(grid.between(180, 60), (start: 540, end: 660));
    // 9:07 → 9:00, 10:55 → 11:00.
    expect(grid.between(67, 175), (start: 540, end: 660));
    // Too short: one step.
    expect(grid.between(60, 62), (start: 540, end: 555));
    // Past the edges.
    expect(grid.between(-40, 900), (start: 480, end: 1080));
  });

  test('moving keeps the length and stays inside the grid', () {
    expect(grid.moved(127, 90), (start: 600, end: 690)); // 10:07 → 10:00
    expect(grid.moved(-30, 90), (start: 480, end: 570));
    expect(grid.moved(590, 90), (start: 990, end: 1080));
  });

  test('resizing: at least 15 minutes, at most the grid end', () {
    expect(grid.resized(600, 183), 660); // 11:03 → 11:00
    expect(grid.resized(600, 100), 615);
    expect(grid.resized(600, 900), 1080);
  });

  test('other zooms', () {
    const tall = GridTimes(startHour: 0, endHour: 24, hourHeight: 120);
    expect(tall.minutesAt(240), 120);
    expect(tall.between(240, 300), (start: 120, end: 150));
  });
}
