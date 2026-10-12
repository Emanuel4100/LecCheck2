import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Curve that follows a spring from 0 to 1, so implicit animations
/// (AnimatedContainer, AnimatedScale, …) get Material 3 Expressive bounce.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {this.duration = 0.5})
    : _sim = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;

  /// Seconds the curve's 0..1 range covers.
  final double duration;
  final SpringSimulation _sim;

  @override
  double transformInternal(double t) => _sim.x(t * duration);
}

/// Motion tokens. Spatial springs bounce slightly (things that move or
/// resize); effect springs don't (color, opacity).
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.fast,
    required this.medium,
    required this.slow,
    required this.spatialFast,
    required this.spatial,
    required this.spatialSlow,
    required this.effects,
    this.reduced = false,
  });

  /// For the system's "remove animations" setting: everything is instant.
  const AppMotion.none()
    : fast = Duration.zero,
      medium = Duration.zero,
      slow = Duration.zero,
      spatialFast = Curves.linear,
      spatial = Curves.linear,
      spatialSlow = Curves.linear,
      effects = Curves.linear,
      reduced = true;

  factory AppMotion.standard() {
    SpringCurve spring(int ms, double bounce) => SpringCurve(
      SpringDescription.withDurationAndBounce(
        duration: Duration(milliseconds: ms),
        bounce: bounce,
      ),
      duration: ms / 1000 * 1.6,
    );
    return AppMotion(
      fast: const Duration(milliseconds: 200),
      medium: const Duration(milliseconds: 350),
      slow: const Duration(milliseconds: 550),
      spatialFast: spring(300, 0.22),
      spatial: spring(450, 0.2),
      spatialSlow: spring(650, 0.15),
      effects: Curves.easeOutCubic,
    );
  }

  final Duration fast;
  final Duration medium;
  final Duration slow;
  final Curve spatialFast;
  final Curve spatial;
  final Curve spatialSlow;
  final Curve effects;

  /// The system asks for less motion ([AppMotion.none]).
  final bool reduced;

  /// [standard] for an animation the tokens don't cover; nothing with
  /// reduced motion.
  Duration duration(Duration standard) => reduced ? Duration.zero : standard;

  /// Items appearing one after another, [step] apart.
  Duration staggered(
    int index, {
    Duration step = const Duration(milliseconds: 40),
  }) => reduced ? Duration.zero : medium + step * index;

  /// The theme's motion, or none when the system asks to remove animations
  /// (Android's accessibility setting, reduced motion elsewhere).
  static AppMotion of(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? const AppMotion.none()
      : Theme.of(context).extension<AppMotion>() ?? AppMotion.standard();

  @override
  AppMotion copyWith() => this;

  @override
  AppMotion lerp(AppMotion? other, double t) => other ?? this;
}
