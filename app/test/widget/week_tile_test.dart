// How week tiles fit the course name (the test font draws every character
// as a square as wide as the font size).
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/features/week/week_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const name = TextStyle(fontSize: 10, height: 1.2, letterSpacing: 0.5);
  const detail = TextStyle(fontSize: 10, height: 1.2);

  TileLayout layout(
    String course, {
    String shortName = '',
    String room = 'Taub 2',
    bool badge = false,
    required double width,
    required double height,
  }) => layoutTile(
    name: course,
    shortName: shortName,
    time: '10:00',
    room: room,
    badge: badge,
    nameStyle: name,
    detailStyle: detail,
    size: Size(width, height),
    scaler: TextScaler.noScaling,
    direction: TextDirection.ltr,
  );

  test('the status icon makes way for the name instead of cutting it', () {
    // "Linear" fills the first line and the room the last, so the icon goes
    // after the time (the third line).
    final tile = layout('Linear Algebra', badge: true, width: 70, height: 60);
    expect(tile.name, 'Linear Algebra');
    expect(tile.nameLines, 2);
    expect(tile.nameInset, 0);
    expect(tile.showTime, isTrue);
    expect(tile.showRoom, isTrue);
    expect(tile.badgeTop, 24 + (12 - tileBadgeSize) / 2);
  });

  test('a wide tile keeps the icon after the first line', () {
    final tile = layout('Calculus', badge: true, width: 200, height: 60);
    expect(tile.nameLines, 1);
    expect(tile.badgeTop, lessThan(12));
  });

  test('a word too wide for the tile shrinks to fit', () {
    // 10 characters: 105 px with letter spacing, 100 without.
    expect(
      layout('Structures', width: 100, height: 60).nameStyle,
      name.copyWith(letterSpacing: 0),
    );
    expect(layout('Structures', width: 95, height: 60).nameStyle.fontSize, 9.5);
  });

  test('the short name is used only when the full name does not fit', () {
    expect(
      layout(
        'Infinitesimal Calculus',
        shortName: 'Calc 1',
        width: 60,
        height: 60,
      ).name,
      'Calc 1',
    );
    expect(
      layout(
        'Infinitesimal Calculus',
        shortName: 'Calc 1',
        width: 250,
        height: 60,
      ).name,
      'Infinitesimal Calculus',
    );
    // Without a short name, the full name is shown as well as it can be.
    expect(
      layout('Infinitesimal Calculus', width: 60, height: 60).name,
      'Infinitesimal Calculus',
    );
  });

  test('a short tile drops the start time before the room', () {
    final tile = layout('Calc', width: 100, height: 26);
    expect(tile.showRoom, isTrue);
    expect(tile.showTime, isFalse);
    expect(layout('Calc', room: '', width: 100, height: 26).showTime, isTrue);
  });
}
