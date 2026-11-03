import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'polynomial curves have the documented endpoint and midpoint values',
    () {
      for (final curve in <EaseFn>[
        Ease.linear,
        Ease.outCubic,
        Ease.inOutCubic,
        Ease.outBack,
      ]) {
        expect(curve(0), closeTo(0, 1e-15));
        expect(curve(1), 1);
      }
      expect(Ease.linear(0.5), 0.5);
      expect(Ease.outCubic(0.5), 0.875);
      expect(Ease.inOutCubic(0.25), 0.0625);
      expect(Ease.inOutCubic(0.5), 0.5);
      expect(Ease.inOutCubic(0.75), 0.9375);
      expect(Ease.outBack(0.7), greaterThan(1));
    },
  );

  test('non-overshooting curves are monotonic and in range', () {
    for (final curve in <EaseFn>[Ease.linear, Ease.outCubic, Ease.inOutCubic]) {
      var previous = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final value = curve(i / 1000);
        expect(value, inInclusiveRange(previous, 1));
        previous = value;
      }
    }
  });

  test('the cubic ease-in-out is symmetric and continuous at its midpoint', () {
    final random = math.Random(20261103);
    for (var i = 0; i < 100; i++) {
      final t = random.nextDouble();
      expect(Ease.inOutCubic(t), closeTo(1 - Ease.inOutCubic(1 - t), 1e-14));
    }
    expect(Ease.inOutCubic(0.5 - 1e-8), closeTo(0.5, 1e-7));
    expect(Ease.inOutCubic(0.5 + 1e-8), closeTo(0.5, 1e-7));
  });

  group('spring curve', () {
    test('returns exactly zero and one at and beyond the endpoints', () {
      for (final bounce in [-1.0, 0.0, 1e-16, 1e-12, 0.15, 0.3, 0.95, 2.0]) {
        final curve = Ease.spring(bounce: bounce);
        expect(curve(-10), 0.0);
        expect(curve(0), 0.0);
        expect(curve(1), 1.0);
        expect(curve(10), 1.0);
      }
    });

    test('reuses the curve for the same bounce value', () {
      expect(identical(Ease.spring(), Ease.spring()), isTrue);
      expect(identical(Ease.spring(), Ease.spring(bounce: 0.3)), isTrue);
      expect(identical(Ease.spring(bounce: 0), Ease.spring(bounce: 0)), isTrue);
    });

    test(
      'matches the analytical spring without a per-sample result record',
      () {
        final random = math.Random(307);
        for (final bounce in [
          -1.0,
          0.0,
          1e-16,
          1e-12,
          0.01,
          0.15,
          0.3,
          0.95,
          2.0,
        ]) {
          final curve = Ease.spring(bounce: bounce);
          final spring = Spring.bounce(duration: 1, bounce: bounce);
          for (var i = 0; i < 100; i++) {
            final t = random.nextDouble();
            final expected = spring
                .solve(from: 0, to: 1, velocity: 0, t: t * spring.settleTime)
                .$1;
            expect(
              curve(t),
              closeTo(expected, 1e-12),
              reason: 'bounce=$bounce, t=$t',
            );
          }
        }
      },
    );

    test('zero bounce is monotonic while a bouncy curve overshoots', () {
      final calm = Ease.spring(bounce: 0);
      final bouncy = Ease.spring(bounce: 0.35);
      var previous = 0.0, maximum = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final t = i / 1000;
        final value = calm(t);
        expect(value, inInclusiveRange(previous, 1));
        previous = value;
        maximum = math.max(maximum, bouncy(t));
      }
      expect(maximum, greaterThan(1.05));
    });

    test('scrubbing and reverse evaluation have no historical state', () {
      final curve = Ease.spring();
      final expected = curve(0.25);
      curve(0.9);
      curve(0.1);
      expect(curve(0.25), expected);
    });

    test('rejects nonfinite bounce without poisoning the cache', () {
      final valid = Ease.spring();
      for (final bounce in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => Ease.spring(bounce: bounce), throwsArgumentError);
      }
      expect(identical(Ease.spring(), valid), isTrue);
    });
  });

  test(
    'damped sine starts and ends at zero and decays within unit amplitude',
    () {
      for (final cycles in [0.0, 0.5, 2.0, 4.0, 7.25]) {
        expect(Ease.dampedSine(0, cycles: cycles), 0);
        expect(Ease.dampedSine(1, cycles: cycles), 0);
        for (var i = 0; i <= 1000; i++) {
          final t = i / 1000;
          expect(
            Ease.dampedSine(t, cycles: cycles).abs(),
            lessThanOrEqualTo(1 - t + 1e-15),
          );
        }
      }
      expect(Ease.dampedSine(0.0625), closeTo(0.9375, 1e-15));
      expect(Ease.dampedSine(0.1875), closeTo(-0.8125, 1e-15));
    },
  );
}
