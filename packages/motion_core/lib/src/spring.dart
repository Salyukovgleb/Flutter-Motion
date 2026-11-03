import 'dart:math' as math;

/// An analytical damped harmonic oscillator, independent of the frame rate.
///
/// Parameters are validated by [solve] and [settleTime], including in release
/// mode. Deferring validation preserves constant construction. Stiffness and
/// mass must be positive; damping must be nonnegative. All must be finite.
///
/// ```dart
/// const spring = Spring(stiffness: 180, damping: 14, mass: 1);
/// final (position, velocity) = spring.solve(
///   from: 0, to: 1, velocity: 0, t: 0.2,
/// );
/// ```
final class Spring {
  /// Creates a spring whose physical parameters are validated on evaluation.
  ///
  /// ```dart
  /// const spring = Spring(stiffness: 100, damping: 20);
  /// ```
  const Spring({this.stiffness = 180, this.damping = 14, this.mass = 1});

  /// Creates a spring from an approximate duration in seconds and bounce.
  ///
  /// [duration] must be positive and finite. A finite [bounce] is clamped to
  /// 0..0.95. Zero bounce gives critical damping: a stationary spring does not
  /// overshoot its target. Duration is a tuning parameter, not a deadline.
  /// Throws [ArgumentError] for nonfinite inputs, a nonpositive duration, or
  /// generated parameters outside the representable floating-point range.
  ///
  /// ```dart
  /// final spring = Spring.bounce(duration: 0.5, bounce: 0.3);
  /// ```
  factory Spring.bounce({double duration = 0.5, double bounce = 0.15}) {
    _requireFinite(duration, 'duration');
    _requireFinite(bounce, 'bounce');
    if (duration <= 0) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    final w = 2 * math.pi / duration;
    final b = bounce.clamp(0.0, 0.95);
    final spring = Spring(stiffness: w * w, damping: 2 * w * (1 - b));
    spring._validateParameters();
    return spring;
  }

  /// A gently damped spring for smooth value following.
  ///
  /// ```dart
  /// const spring = Spring.smooth;
  /// ```
  static const smooth = Spring(stiffness: 170, damping: 26);

  /// A stiffer spring for quick responses.
  ///
  /// ```dart
  /// const spring = Spring.snappy;
  /// ```
  static const snappy = Spring(stiffness: 300, damping: 30);

  /// A lightly damped spring with a visible overshoot.
  ///
  /// ```dart
  /// const spring = Spring.bouncy;
  /// ```
  static const bouncy = Spring(stiffness: 220, damping: 12);

  /// The positive spring stiffness.
  ///
  /// ```dart
  /// final stiffness = Spring.bouncy.stiffness; // 220.0
  /// ```
  final double stiffness;

  /// The nonnegative damping coefficient; zero permits sustained oscillation.
  ///
  /// ```dart
  /// final damping = Spring.smooth.damping; // 26.0
  /// ```
  final double damping;

  /// The positive mass of the animated value.
  ///
  /// ```dart
  /// final mass = Spring.snappy.mass; // 1.0
  /// ```
  final double mass;

  double get _w0 => math.sqrt(stiffness) / math.sqrt(mass);
  double get _zeta => (damping / math.sqrt(stiffness)) / math.sqrt(mass) / 2;

  /// Estimates seconds until practical rest, about 0.1% of initial amplitude.
  ///
  /// This estimate is not a bound for arbitrary initial velocities. An
  /// undamped spring returns [double.infinity]. Invalid physical parameters
  /// throw [ArgumentError].
  ///
  /// ```dart
  /// final seconds = Spring.bouncy.settleTime;
  /// ```
  double get settleTime {
    _validateParameters();
    final z = _zeta, w0 = _w0;
    if (z == 0) return double.infinity;
    if ((z - 1).abs() < 1e-6) return 9.2 / w0;
    if (z < 1) return 6.9 / (z * w0);
    final root = math.sqrt(z - 1) * math.sqrt(z + 1);
    // Reciprocal form avoids cancellation in z - sqrt(z * z - 1).
    return (6.9 / w0) * (z + root);
  }

  /// Returns position and velocity at [t] seconds without integrating frames.
  ///
  /// [from], [to], [velocity] and [t] must be finite. Negative time evaluates
  /// the same analytical solution backwards. At zero time the inputs are
  /// returned exactly. Invalid inputs or physical parameters throw
  /// [ArgumentError]. Floating-point overflow is possible for extreme states
  /// or backwards times; use finite, representable physical scales.
  ///
  /// ```dart
  /// final (x, v) = Spring.bouncy.solve(
  ///   from: 0, to: 100, velocity: 0, t: 0.5,
  /// );
  /// ```
  (double x, double v) solve({
    required double from,
    required double to,
    required double velocity,
    required double t,
  }) {
    _validateParameters();
    _requireFinite(from, 'from');
    _requireFinite(to, 'to');
    _requireFinite(velocity, 'velocity');
    _requireFinite(t, 't');
    if (t == 0) return (from, velocity);

    final d0 = from - to;
    final w0 = _w0, z = _zeta;
    double x, v;
    if (z == 1) {
      final k = velocity + w0 * d0;
      final e = math.exp(-w0 * t);
      x = e * (d0 + k * t);
      v = e * (velocity - w0 * k * t);
    } else if (z < 1) {
      final wd = w0 * math.sqrt(1 - z * z);
      final a = z * w0;
      final b = (velocity + a * d0) / wd;
      final e = math.exp(-a * t);
      final c = math.cos(wd * t), s = math.sin(wd * t);
      x = e * (d0 * c + b * s);
      v = e * (velocity * c - (d0 * wd + a * b) * s);
    } else {
      final root = math.sqrt(z - 1) * math.sqrt(z + 1);
      final sum = z + root;
      final r1 = -w0 / sum, r2 = -w0 * sum;
      final e1 = math.exp(r1 * t), e2 = math.exp(r2 * t);
      final gap = r1 - r2;
      final u = gap * t;
      // Stable divided difference of exponentials near critical damping.
      final divided = u.abs() < 0.001
          ? e1 *
                t *
                (1 - u / 2 + u * u / 6 - u * u * u / 24 + u * u * u * u / 120)
          : (e1 - e2) / gap;
      final coefficient = velocity - r1 * d0;
      x = d0 * e1 + coefficient * divided;
      v = r1 * x + coefficient * e2;
    }
    return (to + x, v);
  }

  void _validateParameters() {
    _requireFinite(stiffness, 'stiffness');
    _requireFinite(damping, 'damping');
    _requireFinite(mass, 'mass');
    if (stiffness <= 0) {
      throw ArgumentError.value(stiffness, 'stiffness', 'Must be positive.');
    }
    if (damping < 0) {
      throw ArgumentError.value(damping, 'damping', 'Must be nonnegative.');
    }
    if (mass <= 0) {
      throw ArgumentError.value(mass, 'mass', 'Must be positive.');
    }
    if (!_w0.isFinite || _w0 == 0 || !_zeta.isFinite) {
      throw ArgumentError('Spring parameters exceed floating-point range.');
    }
  }

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite.');
    }
  }
}
