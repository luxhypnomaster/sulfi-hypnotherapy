import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/foreground_transfer_retry.dart';

void main() {
  Map<String, dynamic> row(String phase, int due, {bool auto = true}) => {
    '_work': {
      'phase': phase,
      'retryAtMs': due,
      'executor': 'android18',
      'autoResume': auto,
    },
  };
  Duration? delay(
    List<Map<String, dynamic>> rows, {
    int now = 1000,
    int budget = 90000,
  }) => foregroundTransferRetryDelay(
    rows,
    nowMs: now,
    remaining: Duration(milliseconds: budget),
  );

  test('network retry keeps durable due time, no immediate HTTP retry', () {
    expect(delay([row('waiting_network', 31000)]), const Duration(seconds: 30));
    expect(
      delay([row('retry_scheduled', 61000), row('waiting_network', 31000)]),
      const Duration(seconds: 30),
    );
  });
  test('manual pause, auth, policy, cancel and terminal work never wake', () {
    for (final phase in [
      'paused',
      'waiting_auth',
      'waiting_policy',
      'cancelled',
      'complete',
      'failed',
      'failed_permanent',
    ]) {
      expect(delay([row(phase, 1001)]), isNull, reason: phase);
    }
    expect(delay([row('waiting_network', 1001, auto: false)]), isNull);
    final paused = row('waiting_network', 1001);
    (paused['_work'] as Map)['pauseReason'] = 'USER_PAUSED';
    expect(delay([paused]), isNull);
  });
  test(
    'window exhausted or backoff beyond window yields to OS, never shortens',
    () {
      expect(delay([row('waiting_network', 31000)], budget: 0), isNull);
      expect(delay([row('waiting_network', 31000)], budget: 29999), isNull);
      expect(
        delay([row('waiting_network', 31000)], budget: 30000),
        const Duration(seconds: 30),
      );
      expect(delay([row('waiting_network', 901001)]), isNull);
    },
  );
  test('unknown, legacy and malformed records cannot create a retry loop', () {
    expect(delay([]), isNull);
    expect(
      delay([
        {'_work': null},
      ]),
      isNull,
    );
    expect(
      delay([
        {
          '_work': {'phase': 'waiting_network'},
        },
      ]),
      isNull,
    );
    expect(delay([row('waiting_network', 0)]), const Duration(milliseconds: 1));
  });
}
