import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../adaptive.dart';
import 'colors.dart';
import 'motion.dart';

/// Builds the Material 3 (Expressive-styled) theme for a preset.
abstract final class AppTheme {
  static ThemeData build({
    required ThemePreset preset,
    required Brightness brightness,
    ColorScheme? wallpaperScheme,
    bool pureBlack = false,
  }) {
    var scheme = preset == ThemePreset.wallpaper && wallpaperScheme != null
        ? wallpaperScheme
        : ColorScheme.fromSeed(
            seedColor: preset.seed,
            brightness: brightness,
            dynamicSchemeVariant: preset.variant,
          );
    if (pureBlack && brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0B0B0D),
        surfaceContainer: const Color(0xFF111114),
        surfaceContainerHigh: const Color(0xFF18181C),
        surfaceContainerHighest: const Color(0xFF212126),
      );
    }

    final text = _textTheme(scheme);
    final stadium = WidgetStatePropertyAll<OutlinedBorder>(
      const StadiumBorder(),
    );
    // Touch keeps 48 dp targets; mouse-driven desktop gets denser buttons.
    final buttonSize = WidgetStatePropertyAll(
      Size(64, AppIdiom.isDesktop ? 40 : 48),
    );
    final dark = brightness == Brightness.dark;
    final rounded16 = BorderRadius.circular(16);

    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'Rubik',
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Edge-to-edge: transparent system bars, icons following the theme.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: brightness,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: stadium,
          minimumSize: buttonSize,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: stadium,
          minimumSize: buttonSize,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: stadium,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: rounded16,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: rounded16,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: rounded16,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: rounded16,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: rounded16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      extensions: [
        StatusColors.build(scheme),
        CourseColors.build(scheme),
        AppMotion.standard(),
      ],
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final typography = Typography.material2021();
    final base =
        (scheme.brightness == Brightness.dark
                ? typography.white
                : typography.black)
            .apply(
              fontFamily: 'Rubik',
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            );
    TextStyle? w(TextStyle? s, FontWeight weight) =>
        s?.copyWith(fontWeight: weight);
    return base.copyWith(
      displayMedium: w(base.displayMedium, FontWeight.w600),
      displaySmall: w(base.displaySmall, FontWeight.w600),
      headlineLarge: w(base.headlineLarge, FontWeight.w600),
      headlineMedium: w(base.headlineMedium, FontWeight.w600),
      headlineSmall: w(base.headlineSmall, FontWeight.w600),
      titleLarge: w(base.titleLarge, FontWeight.w600),
      titleMedium: w(base.titleMedium, FontWeight.w600),
      titleSmall: w(base.titleSmall, FontWeight.w600),
      labelLarge: w(base.labelLarge, FontWeight.w600),
    );
  }
}
