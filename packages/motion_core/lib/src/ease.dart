import 'dart:math' as math;

import 'spring.dart';

/// Maps normalized progress to eased progress, which may overshoot 0..1.
///
/// ```dart
/// EaseFn ease = Ease.outCubic;
/// final progress = ease(0.5);
/// ```
typedef EaseFn = double Function(double t);

/// Frame-independent easing functions for normalized progress.
///
/// Obtain spring curves during setup and reuse them when evaluating frames.
///
/// ```dart
/// final curve = Ease.spring(bounce: 0.3);
/// final progress = curve(0.5);
/// ```
abstract final class Ease {
  /// Returns progress unchanged.
  ///
  /// ```dart
  /// final progress = Ease.linear(0.5); // 0.5
  /// ```
  static double linear(double t) => t;

  /// Decelerates toward one with a cubic curve.
  ///
  /// ```dart
  /// final progress = Ease.outCubic(0.5); // 0.875
  /// ```
  static double outCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  /// Accelerates and then decelerates with symmetric cubic segments.
  ///
  /// ```dart
  /// final progress = Ease.inOutCubic(0.5); // 0.5
  /// ```
  static double inOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = -2 * t + 2;
    return 1 - u * u * u / 2;
  }

  /// Overshoots one before returning to its endpoint.
  ///
  /// ```dart
  /// final progress = Ease.outBack(0.7); // Greater than 1.
  /// ```
  static double outBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  static final _springCache = <double, EaseFn>{};

  /// Returns a cached, fixed-duration spring curve with exact endpoints.
  ///
  /// Finite [bounce] is clamped to 0..0.95 by [Spring.bounce]. Nonfinite
  /// bounce throws [ArgumentError]. Progress at or below zero returns exactly
  /// zero; progress at or above one returns exactly one. Interior samples use
  /// the analytical spring at its estimated settling time, allowing overshoot.
  ///
  /// ```dart
  /// final curve = Ease.spring(bounce: 0.3);
  /// final end = curve(1); // Exactly 1.0.
  /// ```
  static EaseFn spring({double bounce = 0.3}) =>
      _springCache.putIfAbsent(bounce, () {
        final spring = Spring.bounce(duration: 1, bounce: bounce);
        final w0 = math.sqrt(spring.stiffness);
        final rate = spring.damping / 2;
        final critical = rate >= w0;
        final frequency = critical
            ? 0.0
            : w0 * math.sqrt(1 - (rate / w0) * (rate / w0));
        return _SpringEase(
          spring.settleTime,
          rate,
          frequency,
          critical ? 0 : rate / frequency,
          critical,
        ).call;
      });

  /// Returns a sine wave with a linearly decaying amplitude on 0..1.
  ///
  /// [cycles] controls the number of oscillations. The default range is -1..1.
  ///
  /// ```dart
  /// final displacement = Ease.dampedSine(0.125, cycles: 2);
  /// ```
  static double dampedSine(double t, {double cycles = 4}) =>
      math.sin(t * cycles * 2 * math.pi) * (1 - t);
}

// Only the position of a unit-mass, 0 -> 1 spring is needed by easing. Preparing
// these coefficients once avoids the public solve() result record per sample.
final class _SpringEase {
  const _SpringEase(
    this._duration,
    this._rate,
    this._frequency,
    this._coefficient,
    this._critical,
  );

  final double _duration, _rate, _frequency, _coefficient;
  final bool _critical;

  double call(double t) {
    if (t >= 1) return 1;
    if (t <= 0) return 0;
    final time = t * _duration;
    final decay = math.exp(-_rate * time);
    if (_critical) return 1 - decay * (1 + _rate * time);
    final phase = _frequency * time;
    return 1 - decay * (math.cos(phase) + _coefficient * math.sin(phase));
  }
}
