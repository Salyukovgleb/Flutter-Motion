import 'package:motion_core/motion_core.dart';

/// Exercises parameter validation with assertions disabled by a normal Dart run.
///
/// ```sh
/// dart run test/fixtures/spring_validation.dart
/// ```
void main() {
  var assertionsEnabled = false;
  assert(() {
    assertionsEnabled = true;
    return true;
  }());
  if (assertionsEnabled) throw StateError('Run without --enable-asserts.');

  var rejected = 0;
  for (final spring in [
    const Spring(stiffness: 0),
    const Spring(damping: -1),
    const Spring(mass: double.nan),
  ]) {
    try {
      spring.solve(from: 0, to: 1, velocity: 0, t: 1);
    } on ArgumentError {
      rejected++;
    }
  }
  if (rejected != 3) {
    throw StateError('Release validation did not reject inputs.');
  }
}
