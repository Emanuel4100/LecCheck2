import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/schedule_types.dart';

/// Built-in color themes. [wallpaper] uses Material You colors where the
/// platform provides them and falls back to [ocean].
enum ThemePreset {
  wallpaper(Color(0xFF2A7BCC), DynamicSchemeVariant.tonalSpot),
  ocean(Color(0xFF2A7BCC), DynamicSchemeVariant.tonalSpot),
  sunset(Color(0xFFF0623A), DynamicSchemeVariant.vibrant),
  forest(Color(0xFF2E7D4F), DynamicSchemeVariant.tonalSpot),
  grape(Color(0xFF7B4FD6), DynamicSchemeVariant.expressive),
  rose(Color(0xFFD9467A), DynamicSchemeVariant.tonalSpot),
  mono(Color(0xFF5F6368), DynamicSchemeVariant.monochrome);

  const ThemePreset(this.seed, this.variant);
  final Color seed;
  final DynamicSchemeVariant variant;

  static ThemePreset fromName(String? name) => ThemePreset.values.firstWhere(
    (p) => p.name == name,
    orElse: () => ThemePreset.ocean,
  );
}

/// Accent / container / on-container triple for one semantic color.
@immutable
class ToneSet {
  const ToneSet(this.accent, this.container, this.onContainer);
  final Color accent;
  final Color container;
  final Color onContainer;

  static ToneSet lerp(ToneSet a, ToneSet b, double t) => ToneSet(
    Color.lerp(a.accent, b.accent, t)!,
    Color.lerp(a.container, b.container, t)!,
    Color.lerp(a.onContainer, b.onContainer, t)!,
  );
}

ToneSet _toneSet(int argb, Brightness brightness, int primary) {
  final harmonized = Blend.harmonize(argb, primary);
  final hct = Hct.fromInt(harmonized);
  final dark = brightness == Brightness.dark;
  Color tone(double chroma, double t) =>
      Color(Hct.from(hct.hue, chroma, t).toInt());
  final chroma = hct.chroma.clamp(16.0, 56.0);
  return dark
      ? ToneSet(tone(chroma, 78), tone(chroma * 0.6, 30), tone(16, 92))
      : ToneSet(tone(chroma, 42), tone(chroma * 0.5, 90), tone(chroma, 18));
}

/// One status color set used everywhere: cards, grid, charts, widget
/// (v1 used different colors for the same status on each screen).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors(this._tones);

  factory StatusColors.build(ColorScheme scheme) {
    final primary = scheme.primary.toARGB32();
    ToneSet t(int argb) => _toneSet(argb, scheme.brightness, primary);
    return StatusColors({
      AttendanceStatus.attended: t(0xFF2E9D4F),
      AttendanceStatus.watched: t(0xFF1E88B8),
      AttendanceStatus.missed: t(0xFFD3363A),
      AttendanceStatus.skipped: t(0xFFC98A12),
      AttendanceStatus.canceled: ToneSet(
        scheme.outline,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      AttendanceStatus.pending: ToneSet(
        scheme.primary,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    });
  }

  final Map<AttendanceStatus, ToneSet> _tones;

  ToneSet operator [](AttendanceStatus status) => _tones[status]!;

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors({
      for (final s in AttendanceStatus.values)
        s: ToneSet.lerp(this[s], other[s], t),
    });
  }
}

/// Curated course colors, keyed by stable names stored in the database.
const coursePaletteSeeds = <String, int>{
  'ocean': 0xFF2A7BCC,
  'sky': 0xFF1FA2DB,
  'teal': 0xFF0F9E8E,
  'mint': 0xFF35A86A,
  'lime': 0xFF84A824,
  'sun': 0xFFE2A013,
  'orange': 0xFFEE7B25,
  'coral': 0xFFE85A4A,
  'rose': 0xFFD9467A,
  'berry': 0xFFB23A9E,
  'grape': 0xFF7B52D3,
  'indigo': 0xFF4858D6,
  'steel': 0xFF3D7E9A,
  'olive': 0xFF6F7C35,
  'cocoa': 0xFF8B5A43,
  'slate': 0xFF5C6B7A,
};

@immutable
class CourseColors extends ThemeExtension<CourseColors> {
  const CourseColors(this._tones);

  factory CourseColors.build(ColorScheme scheme) {
    final primary = scheme.primary.toARGB32();
    return CourseColors({
      for (final e in coursePaletteSeeds.entries)
        e.key: _toneSet(e.value, scheme.brightness, primary),
    });
  }

  final Map<String, ToneSet> _tones;

  Iterable<String> get keys => _tones.keys;

  ToneSet tone(String key) => _tones[key] ?? _tones['ocean']!;

  static CourseColors of(BuildContext context) =>
      Theme.of(context).extension<CourseColors>()!;

  @override
  CourseColors copyWith() => this;

  @override
  CourseColors lerp(CourseColors? other, double t) {
    if (other == null) return this;
    return CourseColors({
      for (final k in _tones.keys) k: ToneSet.lerp(tone(k), other.tone(k), t),
    });
  }
}
