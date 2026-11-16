import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/auth19/auth_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('task19_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    '19 default OFF never invokes a platform method or opens credentials',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (c) async {
        calls++;
        return {};
      });
      final auth = AuthCoordinator(channel: channel);
      await auth.initialize(projectRef: '', publishableKey: '');
      await auth.restore();
      await auth.logout();
      expect(await auth.beginGoogleSignIn(), isNull);
      expect(await auth.workerLease('A'), isNull);
      expect(calls, 0);
      await auth.dispose();
    },
  );
  test('19 startup gate, deduplicated restores and explicit errors contain no token', () async {
    final events = StreamController<dynamic>();
    var restores = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'restore') {
        restores++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return {'state': 'AUTHENTICATED', 'uid': 'controlled-A', 'epoch': 3};
    });
    final auth = AuthCoordinator(
      enabled: true,
      channel: channel,
      events: events.stream,
    );
    expect(auth.snapshot.ready, false);
    await auth.initialize(projectRef: '', publishableKey: '');
    expect(auth.snapshot.ready, true);
    await Future.wait(List.generate(20, (_) => auth.restore()));
    expect(restores, 1);
    events.addError(StateError('synthetic sensitive SDK exception'));
    await Future<void>.delayed(Duration.zero);
    expect(auth.snapshot.state, Auth19State.backendUnavailable);
    expect(auth.snapshot.toString(), isNot(contains('controlled-A')));
    await auth.dispose();
    await events.close();
  });
  test('19 restore never invokes interactive method; lease uses exact requested owner', () async {
    final methods = <String>[];
    Map<dynamic, dynamic>? lease;
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'lease') lease = call.arguments as Map;
      return {'state': 'SIGNED_OUT'};
    });
    final auth = AuthCoordinator(
      enabled: true,
      channel: channel,
      events: const Stream.empty(),
    );
    await auth.initialize(projectRef: '', publishableKey: '');
    await auth.restore();
    await auth.workerLease('pinned-A');
    expect(methods, isNot(contains('beginLogin')));
    expect(lease?['expectedUid'], 'pinned-A');
    await auth.dispose();
  });
  test('19 rejected staging endpoint is not opened', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => 'https://attacker.invalid/auth/v1/authorize',
    );
    final auth = AuthCoordinator(enabled: true, channel: channel);
    await expectLater(auth.beginGoogleSignIn(), throwsFormatException);
    await auth.dispose();
  });
}
