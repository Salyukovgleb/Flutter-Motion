import 'dart:math' as math;

/// Mutable frame output shared by all effects for one animation target.
///
/// Reuse one instance, resetting it before evaluating a new frame. Translation
/// and rotation accumulate by addition; scale and opacity by multiplication.
///
/// ```dart
/// final state = EffectState();
/// const Fade().apply(state, 0.5);
/// const Move(fromY: 16).apply(state, 0.5);
/// ```
final class EffectState {
  /// Creates the identity state.
  ///
  /// ```dart
  /// final state = EffectState();
  /// ```
  EffectState();

  /// Multiplied opacity, initially one.
  ///
  /// ```dart
  /// final state = EffectState()..opacity = 0.5;
  /// ```
  double opacity = 1;

  /// Horizontal translation, initially zero.
  ///
  /// ```dart
  /// final state = EffectState()..dx = 16;
  /// ```
  double dx = 0;

  /// Vertical translation, initially zero.
  ///
  /// ```dart
  /// final state = EffectState()..dy = -16;
  /// ```
  double dy = 0;

  /// Horizontal scale, initially one.
  ///
  /// ```dart
  /// final state = EffectState()..scaleX = 0.9;
  /// ```
  double scaleX = 1;

  /// Vertical scale, initially one.
  ///
  /// ```dart
  /// final state = EffectState()..scaleY = 0.9;
  /// ```
  double scaleY = 1;

  /// Rotation in radians, initially zero.
  ///
  /// ```dart
  /// final state = EffectState()..rotation = 0.5;
  /// ```
  double rotation = 0;

  /// Horizontal anchor as a fraction of target width, initially 0.5.
  ///
  /// ```dart
  /// final state = EffectState()..anchorX = 0;
  /// ```
  double anchorX = 0.5;

  /// Vertical anchor as a fraction of target height, initially 0.5.
  ///
  /// ```dart
  /// final state = EffectState()..anchorY = 0;
  /// ```
  double anchorY = 0.5;

  /// Restores every field to its identity value without replacing the state.
  ///
  /// ```dart
  /// final state = EffectState()..dx = 20;
  /// state.reset();
  /// ```
  void reset() {
    opacity = 1;
    dx = 0;
    dy = 0;
    scaleX = 1;
    scaleY = 1;
    rotation = 0;
    anchorX = 0.5;
    anchorY = 0.5;
  }

  /// Whether translation, scale, or rotation differs from identity.
  ///
  /// Opacity and anchors alone do not introduce a transformation.
  ///
  /// ```dart
  /// final transformed = (EffectState()..dx = 1).hasTransform; // true
  /// ```
  bool get hasTransform =>
      dx != 0 || dy != 0 || scaleX != 1 || scaleY != 1 || rotation != 0;
}

/// A deterministic effect that accumulates its contribution into frame state.
///
/// Implementations must not allocate objects, closures, or collections in
/// [apply]. They must not retain mutable per-frame state.
///
/// ```dart
/// const Effect effect = Fade();
/// final state = EffectState();
/// effect.apply(state, 0.5);
/// ```
abstract interface class Effect {
  /// Whether this effect may change opacity, for compositing decisions.
  ///
  /// ```dart
  /// final usesOpacity = const Fade().affectsOpacity; // true
  /// ```
  bool get affectsOpacity;

  /// Accumulates this effect at eased progress [t] without resetting [state].
  ///
  /// Progress is normally 0..1 but may overshoot when an easing curve does.
  ///
  /// ```dart
  /// const Scale().apply(EffectState(), 0.5);
  /// ```
  void apply(EffectState state, double t);
}

double _lerp(double a, double b, double t) {
  if (t == 0) return a;
  if (t == 1) return b;
  return a + (b - a) * t;
}

/// Multiplies opacity by an interpolated value.
///
/// ```dart
/// const Fade(from: 1, to: 0).apply(EffectState(), 0.5);
/// ```
final class Fade implements Effect {
  /// Creates an opacity effect, defaulting to zero through one.
  ///
  /// ```dart
  /// const effect = Fade();
  /// ```
  const Fade({this.from = 0, this.to = 1});

  /// Initial opacity multiplier.
  ///
  /// ```dart
  /// final initial = const Fade().from; // 0.0
  /// ```
  final double from;

  /// Final opacity multiplier.
  ///
  /// ```dart
  /// final target = const Fade().to; // 1.0
  /// ```
  final double to;

  /// Always true for an opacity effect.
  ///
  /// ```dart
  /// final usesOpacity = const Fade().affectsOpacity;
  /// ```
  @override
  bool get affectsOpacity => true;

  /// Multiplies the existing opacity instead of replacing it.
  ///
  /// ```dart
  /// const Fade().apply(EffectState(), 0.5);
  /// ```
  @override
  void apply(EffectState state, double t) =>
      state.opacity *= _lerp(from, to, t);
}

/// Adds translation between two points without changing layout.
///
/// ```dart
/// const Move(fromY: 16).apply(EffectState(), 0.5);
/// ```
final class Move implements Effect {
  /// Creates a translation effect, defaulting to no movement.
  ///
  /// ```dart
  /// const effect = Move(fromX: 20, toY: 10);
  /// ```
  const Move({this.fromX = 0, this.fromY = 0, this.toX = 0, this.toY = 0});

  /// Initial horizontal translation.
  ///
  /// ```dart
  /// final initial = const Move(fromX: 16).fromX;
  /// ```
  final double fromX;

  /// Initial vertical translation.
  ///
  /// ```dart
  /// final initial = const Move(fromY: 16).fromY;
  /// ```
  final double fromY;

  /// Final horizontal translation.
  ///
  /// ```dart
  /// final target = const Move(toX: 16).toX;
  /// ```
  final double toX;

  /// Final vertical translation.
  ///
  /// ```dart
  /// final target = const Move(toY: 16).toY;
  /// ```
  final double toY;

  /// Always false; translation does not change opacity.
  ///
  /// ```dart
  /// final usesOpacity = const Move().affectsOpacity; // false
  /// ```
  @override
  bool get affectsOpacity => false;

  /// Adds translation to the existing frame state.
  ///
  /// ```dart
  /// const Move(fromY: 16).apply(EffectState(), 0.5);
  /// ```
  @override
  void apply(EffectState state, double t) {
    state.dx += _lerp(fromX, toX, t);
    state.dy += _lerp(fromY, toY, t);
  }
}

/// Multiplies both scale axes by the same interpolated factor.
///
/// ```dart
/// const Scale(from: 0.9, to: 1).apply(EffectState(), 0.5);
/// ```
final class Scale implements Effect {
  /// Creates a uniform scale effect, defaulting to 0.9 through one.
  ///
  /// ```dart
  /// const effect = Scale();
  /// ```
  const Scale({this.from = 0.9, this.to = 1});

  /// Initial scale multiplier.
  ///
  /// ```dart
  /// final initial = const Scale().from; // 0.9
  /// ```
  final double from;

  /// Final scale multiplier.
  ///
  /// ```dart
  /// final target = const Scale().to; // 1.0
  /// ```
  final double to;

  /// Always false; scaling does not change opacity.
  ///
  /// ```dart
  /// final usesOpacity = const Scale().affectsOpacity; // false
  /// ```
  @override
  bool get affectsOpacity => false;

  /// Multiplies both existing scale axes by the interpolated factor.
  ///
  /// ```dart
  /// const Scale().apply(EffectState(), 0.5);
  /// ```
  @override
  void apply(EffectState state, double t) {
    final factor = _lerp(from, to, t);
    state.scaleX *= factor;
    state.scaleY *= factor;
  }
}

/// Adds an interpolated rotation measured in radians.
///
/// ```dart
/// const Rotate().apply(EffectState(), 0.5);
/// ```
final class Rotate implements Effect {
  /// Creates a rotation effect, defaulting to one full turn.
  ///
  /// ```dart
  /// const effect = Rotate();
  /// ```
  const Rotate({this.from = 0, this.to = 2 * math.pi});

  /// Initial rotation in radians.
  ///
  /// ```dart
  /// final initial = const Rotate().from; // 0.0
  /// ```
  final double from;

  /// Final rotation in radians.
  ///
  /// ```dart
  /// final target = const Rotate().to;
  /// ```
  final double to;

  /// Always false; rotation does not change opacity.
  ///
  /// ```dart
  /// final usesOpacity = const Rotate().affectsOpacity; // false
  /// ```
  @override
  bool get affectsOpacity => false;

  /// Adds rotation to the existing frame state.
  ///
  /// ```dart
  /// const Rotate().apply(EffectState(), 0.5);
  /// ```
  @override
  void apply(EffectState state, double t) =>
      state.rotation += _lerp(from, to, t);
}

/// Adds a horizontal sine wave whose amplitude decays to zero.
///
/// ```dart
/// const Shake(amplitude: 6, cycles: 4).apply(EffectState(), 0.5);
/// ```
final class Shake implements Effect {
  /// Creates a shake effect for linear progress.
  ///
  /// ```dart
  /// const effect = Shake();
  /// ```
  const Shake({this.amplitude = 6, this.cycles = 4});

  /// Initial maximum displacement.
  ///
  /// ```dart
  /// final distance = const Shake().amplitude; // 6.0
  /// ```
  final double amplitude;

  /// Number of oscillations across the full progress interval.
  ///
  /// ```dart
  /// final oscillations = const Shake().cycles; // 4.0
  /// ```
  final double cycles;

  /// Always false; shaking does not change opacity.
  ///
  /// ```dart
  /// final usesOpacity = const Shake().affectsOpacity; // false
  /// ```
  @override
  bool get affectsOpacity => false;

  /// Adds the current horizontal displacement without replacing translation.
  ///
  /// ```dart
  /// const Shake().apply(EffectState(), 0.125);
  /// ```
  @override
  void apply(EffectState state, double t) =>
      state.dx += amplitude * math.sin(t * cycles * 2 * math.pi) * (1 - t);
}

/// Multiplies scale along a single pulse, returning to identity at the end.
///
/// ```dart
/// const Pulse().apply(EffectState(), 0.5);
/// ```
final class Pulse implements Effect {
  /// Creates a pulse that reaches one plus [amount] at its midpoint.
  ///
  /// ```dart
  /// const effect = Pulse(amount: 0.08);
  /// ```
  const Pulse({this.amount = 0.08});

  /// Added midpoint scale relative to one.
  ///
  /// ```dart
  /// final growth = const Pulse().amount; // 0.08
  /// ```
  final double amount;

  /// Always false; a pulse does not change opacity.
  ///
  /// ```dart
  /// final usesOpacity = const Pulse().affectsOpacity; // false
  /// ```
  @override
  bool get affectsOpacity => false;

  /// Multiplies the existing scale axes, preserving exact neutral endpoints.
  ///
  /// ```dart
  /// const Pulse().apply(EffectState(), 0.5);
  /// ```
  @override
  void apply(EffectState state, double t) {
    if (t == 0 || t == 1) return;
    final factor = 1 + amount * math.sin(t * math.pi);
    state.scaleX *= factor;
    state.scaleY *= factor;
  }
}
