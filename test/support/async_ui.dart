import 'package:flutter_test/flutter_test.dart';

/// Native filesystem/SQLite work needs real event-loop turns as well as frames.
/// Await observable completion rather than assuming the runner's disk latency.
Future<void> pumpUntilIo(
  WidgetTester tester,
  bool Function() finished, {
  required String reason,
}) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (finished()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finished(), isTrue, reason: reason);
}
