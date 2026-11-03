/// Pure Dart animation primitives for Flutter Motion.
///
/// Springs can be evaluated directly without Flutter or a frame scheduler.
///
/// ```dart
/// import 'package:motion_core/motion_core.dart';
///
/// final (x, v) = Spring.smooth.solve(from: 0, to: 1, velocity: 0, t: 0.2);
/// ```
library;

export 'src/spring.dart';
