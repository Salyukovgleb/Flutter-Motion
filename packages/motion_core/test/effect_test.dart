import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test('state starts at identity and reset restores every field', () {
    final state = EffectState();
    const identity = [1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.5, 0.5];
    expect(_values(state), identity);
    state
      ..opacity = 0.3
      ..dx = 10
      ..dy = -20
      ..scaleX = 0.4
      ..scaleY = 2
      ..rotation = 3
      ..anchorX = 0
      ..anchorY = 1;
    state.reset();
    expect(_values(state), identity);
  });

  test(
    'hasTransform checks each transform component but not opacity or anchor',
    () {
      expect(EffectState().hasTransform, isFalse);
      expect((EffectState()..opacity = 0).hasTransform, isFalse);
      expect((EffectState()..anchorX = 0).hasTransform, isFalse);
      expect((EffectState()..anchorY = 1).hasTransform, isFalse);
      expect((EffectState()..dx = 1).hasTransform, isTrue);
      expect((EffectState()..dy = 1).hasTransform, isTrue);
      expect((EffectState()..scaleX = 0.5).hasTransform, isTrue);
      expect((EffectState()..scaleY = 0.5).hasTransform, isTrue);
      expect((EffectState()..rotation = 0.5).hasTransform, isTrue);
    },
  );

  test('defaults and opacity metadata match the specification', () {
    expect((const Fade().from, const Fade().to), (0, 1));
    expect(
      (
        const Move().fromX,
        const Move().fromY,
        const Move().toX,
        const Move().toY,
      ),
      (0, 0, 0, 0),
    );
    expect((const Scale().from, const Scale().to), (0.9, 1));
    expect((const Rotate().from, const Rotate().to), (0, 2 * math.pi));
    expect((const Shake().amplitude, const Shake().cycles), (6, 4));
    expect(const Pulse().amount, 0.08);
    expect(const Fade().affectsOpacity, isTrue);
    for (final effect in const <Effect>[
      Move(),
      Scale(),
      Rotate(),
      Shake(),
      Pulse(),
    ]) {
      expect(effect.affectsOpacity, isFalse);
    }
  });

  for (final t in [0.0, 0.5, 1.0]) {
    test('fade multiplies opacity and preserves other fields at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      expected[0] *= 0.2 + 0.6 * t;
      const Fade(from: 0.2, to: 0.8).apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
    });

    test('move adds both translations and preserves other fields at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      expected[1] += 10 - 12 * t;
      expected[2] += -8 + 12 * t;
      const Move(fromX: 10, fromY: -8, toX: -2, toY: 4).apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
    });

    test('scale multiplies both existing axes at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      expected[3] *= 0.6 + 0.8 * t;
      expected[4] *= 0.6 + 0.8 * t;
      const Scale(from: 0.6, to: 1.4).apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
    });

    test('rotate adds radians and preserves other fields at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      expected[5] += -0.5 + 2 * t;
      const Rotate(from: -0.5, to: 1.5).apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
    });

    test('shake has its expected boundary and midpoint state at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      const Shake().apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
      if (t == 1) expect(state.dx, expected[1]);
    });

    test('pulse has its expected boundary and midpoint state at $t', () {
      final state = _nonIdentity();
      final expected = _values(state);
      final factor = t == 0.5 ? 1.08 : 1.0;
      expected[3] *= factor;
      expected[4] *= factor;
      const Pulse().apply(state, t);
      expect(
        _values(state),
        orderedEquals(expected.map((value) => closeTo(value, 1e-12))),
      );
      if (t == 1) {
        expect((state.scaleX, state.scaleY), (expected[3], expected[4]));
      }
    });
  }

  test('shake uses the specified amplitude and cycle count', () {
    final state = EffectState();
    const Shake().apply(state, 0.0625);
    expect(state.dx, closeTo(5.625, 1e-12));
    state.reset();
    const Shake(amplitude: 10, cycles: 2).apply(state, 0.375);
    expect(state.dx, closeTo(-6.25, 1e-12));
  });

  test(
    'pulse endpoints remain exactly neutral even at large finite amounts',
    () {
      for (final t in [0.0, 1.0]) {
        final state = _nonIdentity();
        final expected = _values(state);
        const Pulse(amount: 1e16).apply(state, t);
        expect(_values(state), expected);
      }
      final state = EffectState();
      const Pulse(amount: 0.3).apply(state, 0.5);
      expect((state.scaleX, state.scaleY), (1.3, 1.3));
    },
  );

  test(
    'interpolated effects preserve exact endpoints with disparate values',
    () {
      final state = EffectState();
      const Fade(from: 1e16, to: 0.3).apply(state, 1);
      expect(state.opacity, 0.3);
      const Move(fromX: 1e16, toX: 0.3).apply(state, 1);
      expect(state.dx, 0.3);
      const Scale(from: 1e16, to: 0.3).apply(state, 1);
      expect((state.scaleX, state.scaleY), (0.3, 0.3));
      const Rotate(from: 1e16, to: 0.3).apply(state, 1);
      expect(state.rotation, 0.3);
    },
  );

  test('effects preserve easing overshoot instead of clamping it', () {
    final t = Ease.outBack(0.7);
    final state = EffectState();
    const Fade().apply(state, t);
    const Move(toX: 10).apply(state, t);
    const Scale(from: 0.9).apply(state, t);
    const Rotate().apply(state, t);
    expect(state.opacity, greaterThan(1));
    expect(state.dx, greaterThan(10));
    expect(state.scaleX, greaterThan(1));
    expect(state.rotation, greaterThan(2 * math.pi));
  });

  test('composition is order-independent within floating-point precision', () {
    const effects = <Effect>[
      Fade(from: 0.2, to: 0.8),
      Fade(from: 0.7, to: 1),
      Move(fromX: -4, toX: 12),
      Move(fromY: 8, toY: -2),
      Scale(from: 0.9, to: 1.2),
      Scale(from: 1.1, to: 0.8),
      Rotate(to: 0.5),
      Rotate(from: -0.2, to: 1),
      Shake(),
      Pulse(),
    ];
    final random = math.Random(303);
    final shuffled = effects.toList();
    for (var i = 0; i < 100; i++) {
      final t = random.nextDouble();
      final expected = _nonIdentity();
      final actual = _nonIdentity();
      for (final effect in effects) {
        effect.apply(expected, t);
      }
      shuffled.shuffle(random);
      for (final effect in shuffled) {
        effect.apply(actual, t);
      }
      expect(
        _values(actual),
        orderedEquals(_values(expected).map((value) => closeTo(value, 1e-12))),
      );
    }
  });

  test('reset and reevaluation are deterministic while scrubbing', () {
    const effects = <Effect>[
      Fade(),
      Move(fromY: 16),
      Scale(),
      Rotate(),
      Shake(),
      Pulse(),
    ];
    final state = EffectState();
    for (final effect in effects) {
      effect.apply(state, 0.25);
    }
    final expected = _values(state);
    state.reset();
    for (final effect in effects.reversed) {
      effect.apply(state, 0.9);
    }
    state.reset();
    for (final effect in effects) {
      effect.apply(state, 0.25);
    }
    expect(_values(state), expected);
  });

  test('an external effect can implement the specified interface', () {
    const Effect effect = _Wobble();
    final state = EffectState();
    expect(effect.affectsOpacity, isFalse);
    effect.apply(state, 0.25);
    expect(state.rotation, closeTo(-0.075, 1e-15));
    expect(state.opacity, 1);
  });
}

EffectState _nonIdentity() => EffectState()
  ..opacity = 0.4
  ..dx = 3
  ..dy = 5
  ..scaleX = 2
  ..scaleY = 0.5
  ..rotation = 0.2
  ..anchorX = 0.1
  ..anchorY = 0.9;

List<double> _values(EffectState state) => [
  state.opacity,
  state.dx,
  state.dy,
  state.scaleX,
  state.scaleY,
  state.rotation,
  state.anchorX,
  state.anchorY,
];

final class _Wobble implements Effect {
  const _Wobble();
  @override
  bool get affectsOpacity => false;
  @override
  void apply(EffectState state, double t) =>
      state.rotation += 0.1 * math.sin(t * math.pi * 6) * (1 - t);
}
