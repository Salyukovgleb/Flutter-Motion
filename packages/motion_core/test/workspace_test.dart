import 'dart:io';

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test('the package entry point works in the standalone Dart VM', () {
    final (x, v) = Spring.smooth.solve(from: 3, to: 10, velocity: 5, t: 0);
    expect((x, v), (3, 5));
  });

  test('core sources only depend on Dart libraries and their own package', () {
    final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    expect(sources, isNotEmpty);
    for (final source in sources) {
      for (final match in directives.allMatches(source.readAsStringSync())) {
        final uri = Uri.parse(match.group(1)!);
        final allowed =
            !uri.hasScheme ||
            (uri.scheme == 'dart' && uri.path != 'ui') ||
            (uri.scheme == 'package' && uri.path.startsWith('motion_core/'));
        expect(allowed, isTrue, reason: '${source.path} depends on $uri');
      }
    }
  });
}
