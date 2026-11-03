import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the coverage gate accepts exactly the required threshold', () async {
    final result = await _runGate(_report(10, 9));
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('9/10 lines (90.00%)'));
  });

  test('the coverage gate rejects coverage below the threshold', () async {
    final result = await _runGate(_report(10, 8));
    expect(result.exitCode, 1);
    expect(result.stdout, contains('8/10 lines (80.00%)'));
  });

  test('the coverage gate rejects empty and missing reports', () async {
    expect((await _runGate('')).exitCode, 1);
    expect((await _runGate(null)).exitCode, 64);
  });

  test(
    'the coverage gate merges repeated source lines and ignores summaries',
    () async {
      final result = await _runGate('''SF:lib/a.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/a.dart
DA:2,1
end_of_record
SF:lib/b.dart
DA:1,0
LF:1
LH:1
end_of_record
''');
      expect(result.exitCode, 1);
      expect(result.stdout, contains('2/3 lines (66.67%)'));
    },
  );

  test('the coverage gate rejects invalid input', () async {
    for (final report in [
      'DA:1,1',
      'SF:lib/a.dart\nDA:0,1',
      'SF:lib/a.dart\nDA:1,-1',
      'SF:lib/a.dart\nDA:one,1',
      'SF:lib/a.dart\nDA:1',
    ]) {
      expect((await _runGate(report)).exitCode, 64);
    }
    for (final minimum in ['NaN', '-1', '101', 'invalid']) {
      expect((await _runGate(_report(1, 1), minimum: minimum)).exitCode, 64);
    }
  });
}

String _report(int total, int covered) => [
  'SF:lib/spring.dart',
  for (var line = 1; line <= total; line++)
    'DA:$line,${line <= covered ? 1 : 0}',
  'end_of_record',
].join('\n');

Future<ProcessResult> _runGate(String? report, {String minimum = '90'}) async {
  final directory = await Directory.systemTemp.createTemp(
    'motion-coverage-test-',
  );
  try {
    final file = File('${directory.path}/lcov.info');
    if (report != null) await file.writeAsString(report);
    return await Process.run(Platform.resolvedExecutable, [
      Directory.current.parent.parent.uri
          .resolve('tool/check_coverage.dart')
          .toFilePath(),
      file.path,
      minimum,
    ]);
  } finally {
    await directory.delete(recursive: true);
  }
}
