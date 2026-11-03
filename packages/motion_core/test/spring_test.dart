import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  const regimes = <String, Spring>{
    'underdamped': Spring(stiffness: 100, damping: 8),
    'critical': Spring(stiffness: 100, damping: 20),
    'overdamped': Spring(stiffness: 100, damping: 35),
    'undamped': Spring(stiffness: 100, damping: 0),
    'non-unit mass': Spring(stiffness: 140, damping: 12, mass: 3),
  };

  test('defaults and presets match the specification', () {
    const spring = Spring();
    expect((spring.stiffness, spring.damping, spring.mass), (180, 14, 1));
    expect((Spring.smooth.stiffness, Spring.smooth.damping), (170, 26));
    expect((Spring.snappy.stiffness, Spring.snappy.damping), (300, 30));
    expect((Spring.bouncy.stiffness, Spring.bouncy.damping), (220, 12));
  });

  for (final entry in regimes.entries) {
    group(entry.key, () {
      final spring = entry.value;

      test('returns exact initial position and velocity at zero', () {
        expect(spring.solve(from: 3.25, to: 10, velocity: -5.5, t: 0), (
          3.25,
          -5.5,
        ));
      });

      test('matches independent Runge-Kutta integration', () {
        final expected = _integrate(spring, 3, -2, 5, 0.7);
        final actual = spring.solve(from: 3, to: -2, velocity: 5, t: 0.7);
        expect(actual.$1, closeTo(expected.$1, 1e-7));
        expect(actual.$2, closeTo(expected.$2, 1e-7));
      });

      test('velocity agrees with the derivative of position', () {
        const h = 1e-6;
        for (final t in [0.05, 0.2, 0.7, 1.5]) {
          final before = spring.solve(from: 0, to: 2, velocity: 3, t: t - h);
          final after = spring.solve(from: 0, to: 2, velocity: 3, t: t + h);
          final actual = spring.solve(from: 0, to: 2, velocity: 3, t: t);
          expect(actual.$2, closeTo((after.$1 - before.$1) / (2 * h), 1e-7));
        }
      });

      test('is independent of evaluation order and frame subdivision', () {
        final end = spring.solve(from: 0, to: 100, velocity: -4, t: 0.6);
        final middle = spring.solve(from: 0, to: 100, velocity: -4, t: 0.2);
        final resumed = spring.solve(
          from: middle.$1,
          to: 100,
          velocity: middle.$2,
          t: 0.4,
        );
        expect(resumed.$1, closeTo(end.$1, 1e-10));
        expect(resumed.$2, closeTo(end.$2, 1e-10));
        expect(spring.solve(from: 0, to: 100, velocity: -4, t: 0.6), end);
      });

      test('supports backward analytical evaluation', () {
        final forward = spring.solve(from: 2, to: 4, velocity: 3, t: 0.1);
        final back = spring.solve(
          from: forward.$1,
          to: 4,
          velocity: forward.$2,
          t: -0.1,
        );
        expect(back.$1, closeTo(2, 1e-10));
        expect(back.$2, closeTo(3, 1e-10));
      });
    });
  }

  test('damped presets converge even after a long pause', () {
    for (final spring in [Spring.smooth, Spring.snappy, Spring.bouncy]) {
      final (x, v) = spring.solve(from: 0, to: 100, velocity: 5, t: 10);
      expect(x, closeTo(100, 0.01));
      expect(v, closeTo(0, 0.01));
      expect(spring.solve(from: 0, to: 100, velocity: 5, t: 1e6), (100, 0));
    }
  });

  test('critical and overdamped springs do not overshoot from rest', () {
    for (final spring in [regimes['critical']!, regimes['overdamped']!]) {
      var previous = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final (x, v) = spring.solve(from: 0, to: 1, velocity: 0, t: i / 100);
        expect(x, inInclusiveRange(previous - 1e-12, 1 + 1e-12));
        expect(v, greaterThanOrEqualTo(-1e-12));
        previous = x;
      }
    }
  });

  test('the bouncy preset overshoots', () {
    var maximum = 0.0;
    for (var i = 0; i < 400; i++) {
      final (x, _) = Spring.bouncy.solve(
        from: 0,
        to: 1,
        velocity: 0,
        t: i / 200,
      );
      maximum = math.max(maximum, x);
    }
    expect(maximum, greaterThan(1.05));
  });

  test('undamped motion conserves energy and never claims to settle', () {
    const spring = Spring(stiffness: 16, damping: 0, mass: 4);
    expect(spring.settleTime, double.infinity);
    for (var i = 0; i < 1000; i++) {
      final (x, v) = spring.solve(from: 2, to: 0, velocity: 3, t: i / 100);
      expect(
        0.5 * spring.mass * v * v + 0.5 * spring.stiffness * x * x,
        closeTo(50, 1e-10),
      );
    }
  });

  test('settle time covers all damped regimes', () {
    expect(regimes['critical']!.settleTime, closeTo(0.92, 1e-12));
    expect(regimes['underdamped']!.settleTime, closeTo(6.9 / 4, 1e-12));
    expect(regimes['overdamped']!.settleTime, greaterThan(0));
    const heavy = Spring(stiffness: 1, damping: 2e10);
    expect(heavy.settleTime.isFinite, isTrue);
    expect(heavy.settleTime, closeTo(1.38e11, 1));
    final (x, v) = heavy.solve(from: 0, to: 1, velocity: 0, t: 2e10);
    expect(x, closeTo(1 - math.exp(-1), 1e-10));
    expect(v.isFinite, isTrue);
  });

  test('near-critical parameters stay continuous', () {
    const critical = Spring(stiffness: 100, damping: 20);
    for (final delta in [-1e-7, 1e-7, -1e-4, 1e-4]) {
      final spring = Spring(stiffness: 100, damping: 20 * (1 + delta));
      final expected = critical.solve(from: 0, to: 1, velocity: 0, t: 0.3);
      final actual = spring.solve(from: 0, to: 1, velocity: 0, t: 0.3);
      expect(actual.$1, closeTo(expected.$1, 1e-4));
      expect(actual.$2, closeTo(expected.$2, 1e-3));
    }
  });

  test(
    'near-critical solutions match integration without a critical approximation',
    () {
      for (final delta in [-1e-7, 1e-7, -1e-12, 1e-12, -2e-16, 2e-16]) {
        final spring = Spring(stiffness: 100, damping: 20 * (1 + delta));
        final actual = spring.solve(from: 0, to: 1, velocity: 0, t: 0.3);
        final expected = _integrate(spring, 0, 1, 0, 0.3);
        expect(actual.$1, closeTo(expected.$1, 1e-10));
        expect(actual.$2, closeTo(expected.$2, 1e-9));
      }
    },
  );

  group('bounce', () {
    test('defaults use the documented parameterization', () {
      final spring = Spring.bounce();
      final w = 2 * math.pi / 0.5;
      expect(spring.stiffness, closeTo(w * w, 1e-12));
      expect(spring.damping, closeTo(2 * w * 0.85, 1e-12));
      expect(spring.mass, 1);
    });

    test('zero bounce never overshoots in either direction', () {
      for (final duration in [0.05, 0.5, 5.0]) {
        final spring = Spring.bounce(duration: duration, bounce: 0);
        for (var i = 0; i <= 1000; i++) {
          final t = duration * i / 100;
          final up = spring.solve(from: -3, to: 2, velocity: 0, t: t);
          final down = spring.solve(from: 10, to: -4, velocity: 0, t: t);
          expect(up.$1, inInclusiveRange(-3 - 1e-12, 2 + 1e-12));
          expect(down.$1, inInclusiveRange(-4 - 1e-12, 10 + 1e-12));
        }
      }
    });

    test('finite bounce is clamped to the documented range', () {
      expect(
        Spring.bounce(bounce: -1).damping,
        Spring.bounce(bounce: 0).damping,
      );
      expect(
        Spring.bounce(bounce: 2).damping,
        Spring.bounce(bounce: 0.95).damping,
      );
    });

    test('invalid factory inputs are rejected', () {
      for (final duration in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        1e-300,
        1e300,
      ]) {
        expect(() => Spring.bounce(duration: duration), throwsArgumentError);
      }
      for (final bounce in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => Spring.bounce(bounce: bounce), throwsArgumentError);
      }
    });
  });

  test('invalid physical parameters are rejected on evaluation', () {
    final invalid = <Spring>[
      const Spring(stiffness: 0),
      const Spring(stiffness: -1),
      const Spring(stiffness: double.nan),
      const Spring(stiffness: double.infinity),
      const Spring(damping: -1),
      const Spring(damping: double.nan),
      const Spring(damping: double.infinity),
      const Spring(mass: 0),
      const Spring(mass: -1),
      const Spring(mass: double.nan),
      const Spring(mass: double.infinity),
      const Spring(stiffness: 1e308, mass: 1e-320),
      const Spring(stiffness: double.minPositive, damping: 1e308),
    ];
    for (final spring in invalid) {
      expect(() => spring.settleTime, throwsArgumentError);
      expect(
        () => spring.solve(from: 0, to: 1, velocity: 0, t: 1),
        throwsArgumentError,
      );
    }
  });

  test('nonfinite states and times are rejected', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => Spring.smooth.solve(from: value, to: 1, velocity: 0, t: 1),
        throwsArgumentError,
      );
      expect(
        () => Spring.smooth.solve(from: 0, to: value, velocity: 0, t: 1),
        throwsArgumentError,
      );
      expect(
        () => Spring.smooth.solve(from: 0, to: 1, velocity: value, t: 1),
        throwsArgumentError,
      );
      expect(
        () => Spring.smooth.solve(from: 0, to: 1, velocity: 0, t: value),
        throwsArgumentError,
      );
    }
  });

  test(
    'seeded positive parameters stay finite, converge, and match integration',
    () {
      final random = math.Random(20261103);
      for (var i = 0; i < 100; i++) {
        final mass = 0.2 + random.nextDouble() * 5;
        final stiffness = 1 + random.nextDouble() * 1000;
        final ratio = 0.05 + random.nextDouble() * 3;
        final spring = Spring(
          stiffness: stiffness,
          damping: 2 * ratio * math.sqrt(stiffness * mass),
          mass: mass,
        );
        final from = random.nextDouble() * 20 - 10;
        final to = random.nextDouble() * 20 - 10;
        final velocity = random.nextDouble() * 10 - 5;
        final actual = spring.solve(
          from: from,
          to: to,
          velocity: velocity,
          t: 0.4,
        );
        final expected = _integrate(spring, from, to, velocity, 0.4);
        expect(actual.$1, closeTo(expected.$1, 1e-6), reason: 'seed case $i');
        expect(actual.$2, closeTo(expected.$2, 1e-5), reason: 'seed case $i');
        final settled = spring.solve(
          from: from,
          to: to,
          velocity: velocity,
          t: spring.settleTime * 4,
        );
        expect(settled.$1.isFinite && settled.$2.isFinite, isTrue);
        expect(settled.$1, closeTo(to, 1e-5));
        expect(settled.$2, closeTo(0, 1e-5));
      }
    },
  );
}

(double, double) _integrate(
  Spring spring,
  double from,
  double to,
  double velocity,
  double duration,
) {
  final steps = (duration / 0.0001).ceil();
  final h = duration / steps;
  final k = spring.stiffness / spring.mass;
  final d = spring.damping / spring.mass;
  var x = from, v = velocity;
  for (var i = 0; i < steps; i++) {
    final ax = v, av = -k * (x - to) - d * v;
    final bx = v + h * av / 2;
    final bv = -k * (x + h * ax / 2 - to) - d * bx;
    final cx = v + h * bv / 2;
    final cv = -k * (x + h * bx / 2 - to) - d * cx;
    final dx = v + h * cv;
    final dv = -k * (x + h * cx - to) - d * dx;
    x += h * (ax + 2 * bx + 2 * cx + dx) / 6;
    v += h * (av + 2 * bv + 2 * cv + dv) / 6;
  }
  return (x, v);
}
