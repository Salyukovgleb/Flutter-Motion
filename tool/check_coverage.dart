import 'dart:io';

/// Checks line coverage without trusting LCOV summary counters.
///
/// ```sh
/// dart run tool/check_coverage.dart packages/motion_core/coverage/lcov.info 90
/// ```
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Usage: check_coverage.dart <lcov-file> <minimum-percent>');
    exitCode = 64;
    return;
  }

  try {
    final minimum = double.parse(arguments[1]);
    if (!minimum.isFinite || minimum < 0 || minimum > 100) {
      throw const FormatException('Minimum percentage must be in 0..100.');
    }
    final hits = <String, bool>{};
    var source = '';
    for (final line in File(arguments[0]).readAsLinesSync()) {
      if (line.startsWith('SF:')) {
        source = line.substring(3);
      } else if (line.startsWith('DA:')) {
        final fields = line.substring(3).split(',');
        if (source.isEmpty || fields.length < 2) {
          throw const FormatException('Line data must follow a source record.');
        }
        final number = int.parse(fields[0]);
        final count = int.parse(fields[1]);
        if (number <= 0 || count < 0) {
          throw const FormatException('Invalid LCOV line number or hit count.');
        }
        final key = '$source:$number';
        hits[key] = (hits[key] ?? false) || count > 0;
      } else if (line == 'end_of_record') {
        source = '';
      }
    }
    if (hits.isEmpty) {
      stderr.writeln(
        'Coverage failed: no executable lines in the LCOV report.',
      );
      exitCode = 1;
      return;
    }
    final covered = hits.values.where((hit) => hit).length;
    final percentage = 100 * covered / hits.length;
    stdout.writeln(
      'Coverage: $covered/${hits.length} lines '
      '(${percentage.toStringAsFixed(2)}%); required >= $minimum%.',
    );
    if (100 * covered < minimum * hits.length) {
      stderr.writeln('Coverage failed: line coverage is below the threshold.');
      exitCode = 1;
    }
  } on FileSystemException catch (error) {
    stderr.writeln('Coverage failed: ${error.message}');
    exitCode = 64;
  } on FormatException catch (error) {
    stderr.writeln('Coverage failed: ${error.message}');
    exitCode = 64;
  }
}
