import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// loadLibrary verifies the empty entry point without adding a public symbol.
// ignore: unused_import
import 'package:kinetic_motion/kinetic_motion.dart' deferred as kinetic_motion;

void main() {
  testWidgets('the package loads without scheduling frames on import', (
    tester,
  ) async {
    await tester.runAsync(kinetic_motion.loadLibrary);
    expect(tester.binding.hasScheduledFrame, isFalse);

    const childKey = ValueKey('workspace-smoke-test');
    await tester.pumpWidget(const SizedBox(key: childKey));

    expect(find.byKey(childKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
