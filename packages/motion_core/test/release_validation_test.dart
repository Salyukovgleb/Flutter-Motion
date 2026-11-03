import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('invalid parameters are rejected without assertions enabled', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/spring_validation.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
