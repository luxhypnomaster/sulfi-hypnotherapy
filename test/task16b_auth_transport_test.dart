// Controlled SDK/HTTP regressions. Not real Google users or physical Android.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diagnostics.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_identity.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'support/task15_fixture.dart';

final endpoint16b = Uri.parse('https://script.google.com/macros/s/UNIT/exec');
DiaryResponse ok16b(Map<String, dynamic> result) => DiaryResponse(
  200,
  jsonEncode({'ok': true, 'status': 200, 'result': result}),
);

class Restore16b implements DiaryIdentity, RestorableDiaryIdentity {
  String token = 'first';
  int interactive = 0, restores = 0, logouts = 0;
  @override
  Future<DiaryIdentityResult> signIn() async {
    interactive++;
    return DiaryIdentityResult(email: 'opaque@example.test', idToken: token);
  }

  @override
  Future<DiaryIdentityResult?> restore() async {
    restores++;
    return DiaryIdentityResult(email: 'opaque@example.test', idToken: token);
  }

  @override
  Future<void> signOut() async {
    logouts++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('G1 official restore shares refreshed RAM identity; offline is not logout; wrong restored account fails closed', () async {
    final f = await Fixture15.open();
    var now = DateTime.now().toUtc();
    var offline = false, subject = 'synthetic-owner';
    final sdk = Restore16b();
    final api = AlchemistDiaryApi(
      endpoint16b,
      capsules: f.c.capsules!,
      clock: () => now,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async {
        if (offline) {
          throw const SocketException(
            'Failed host lookup PRIVATE_EMAIL_OR_URL',
          );
        }
        final q = jsonDecode(body!);
        if (q['operation'] == 'auth.whoami') {
          return ok16b({
            'subject': subject,
            'role': 'MASTER',
            'expiresAt':
                now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
          });
        }
        return ok16b({'credentialWasRefreshed': q['credential'] == 'fresh'});
      },
    );
    api.bindIdentity(sdk);
    try {
      await api.authenticateReader((await sdk.signIn()).idToken);
      final scope = api.readerScope;
      expect(scope, startsWith('account:'));
      expect(scope.contains(subject), false);
      now = now.add(const Duration(hours: 2));
      sdk.token = 'fresh';
      final concurrent = await Future.wait([
        api.verifiedIdentityToken(),
        api.verifiedIdentityToken(),
      ]);
      expect(concurrent, ['fresh', 'fresh']);
      expect(sdk.interactive, 1);
      expect(sdk.restores, 1);
      expect(
        (await api.author.call('feed.list', {}))['credentialWasRefreshed'],
        true,
      );
      now = now.add(const Duration(hours: 2));
      offline = true;
      await expectLater(
        api.verifiedIdentityToken(),
        throwsA(isA<AlchemistApiException>()),
      );
      expect(api.readerScope, scope);
      expect(api.verifiedRole, 'MASTER');
      expect(sdk.logouts, 0);
      offline = false;
      subject = 'other-synthetic-owner';
      await expectLater(
        api.verifiedIdentityToken(),
        throwsA(
          isA<AlchemistFailure>().having(
            (e) => e.code,
            'code',
            'ACCOUNT_CHANGED',
          ),
        ),
      );
      expect(api.readerScope, scope);
      expect(sdk.logouts, 0);
    } finally {
      await f.close();
    }
  });
  test('G1-G2 DNS/abort/5xx safely retry keyed writes, never unknown unsafe POST; sanitized telemetry', () async {
    for (final fault in [
      const SocketException('private@example.test'),
      const HttpException(
        'Software caused connection abort https://private.example',
      ),
      TimeoutException('private@example.test'),
    ]) {
      var n = 0;
      final d = AlchemistDiagnostics();
      final api = AlchemistApi(
        endpoint16b,
        diagnostics: d,
        delay: (_) async {},
        connection: (_, _, _, _) async {
          if (++n < 3) throw fault;
          return ok16b({'done': true});
        },
      );
      expect(
        (await api.call('catalog.publish', {
          'requestId': 'stable-fixture',
        }))['done'],
        true,
      );
      expect(n, 3);
      expect(jsonEncode(d.events).contains('private'), false);
      expect(d.events.where((x) => x['phase'] == 'retry'), hasLength(2));
      n = 0;
      await expectLater(
        api.call('unknown.mutation', {}),
        throwsA(isA<AlchemistApiException>()),
      );
      expect(n, 1);
    }
    final denied = AlchemistFailure.server(403, 'ACCESS_DENIED'),
        expired = AlchemistFailure.server(401, 'TOKEN_EXPIRED');
    expect(denied.kind, DiaryFailure.blocked);
    expect(expired.kind, DiaryFailure.authorization);
  });
  test('G1-G2 retry cannot send old task after account switch during backoff; 401 refresh is bounded', () async {
    var scope = 'account:a', n = 0;
    final api = AlchemistApi(
      endpoint16b,
      identityScope: () => scope,
      delay: (_) async {
        scope = 'account:b';
      },
      connection: (_, _, _, _) async {
        n++;
        throw const HttpException('abort');
      },
    );
    await expectLater(
      api.call('catalog.publish', {'requestId': 'stable'}),
      throwsA(
        isA<AlchemistApiException>().having(
          (e) => e.code,
          'code',
          'ACCOUNT_CHANGED',
        ),
      ),
    );
    expect(n, 1);
    var refresh = 0;
    n = 0;
    final rejected = AlchemistApi(
      endpoint16b,
      onUnauthorized: () async {
        refresh++;
        return true;
      },
      connection: (_, _, _, _) async {
        n++;
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': false,
            'status': 401,
            'error': {'code': 'AUTHENTICATION_FAILED'},
          }),
        );
      },
    );
    await expectLater(
      rejected.call('feed.list', {}),
      throwsA(isA<AlchemistApiException>()),
    );
    expect(refresh, 1);
    expect(n, 2);
  });
}
