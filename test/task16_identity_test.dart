import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_identity_session.dart';
import 'package:sulfi_hypnotherapy/services/diary_identity.dart';

class Identity16 implements DiaryIdentity {
  int calls = 0;
  Completer<DiaryIdentityResult>? pending;
  @override
  Future<DiaryIdentityResult> signIn() {
    calls++;
    return pending!.future;
  }

  @override
  Future<void> signOut() async {}
}

String token16(DateTime until) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': until.millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.signature';
void main() {
  test('single SDK login for concurrent chunks, RAM cache expiry and logout cancel pending login', () async {
    var now = DateTime.utc(2026, 11, 10);
    final identity = Identity16()..pending = Completer();
    final session = AlchemistIdentitySession(identity, clock: () => now);
    final first = session.token(), concurrent = session.token();
    expect(identity.calls, 1);
    final token = token16(now.add(const Duration(hours: 1)));
    identity.pending!.complete(
      DiaryIdentityResult(email: 'owner@example.test', idToken: token),
    );
    expect(await first, token);
    expect(await concurrent, token);
    expect(await session.token(), token);
    expect(identity.calls, 1);
    now = now.add(const Duration(hours: 2));
    identity.pending = Completer();
    final pending = session.token();
    final rejected = expectLater(pending, throwsFormatException);
    await session.logout();
    identity.pending!.complete(
      DiaryIdentityResult(
        email: 'owner@example.test',
        idToken: token16(now.add(const Duration(hours: 1))),
      ),
    );
    await rejected;
    identity.pending = Completer();
    final next = session.token();
    identity.pending!.complete(
      DiaryIdentityResult(
        email: 'owner@example.test',
        idToken: token16(now.add(const Duration(hours: 1))),
      ),
    );
    await next;
    expect(identity.calls, 3);
  });
}
