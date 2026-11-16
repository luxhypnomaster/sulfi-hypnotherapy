import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'support/task15_fixture.dart';
import 'task16b_auth_transport_test.dart' show Restore16b, endpoint16b, ok16b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('19 SOURCE repro: generic401 + same SDK cached ID token leaves legacy identity rejected, without proving phone cause', () async {
    final f = await Fixture15.open();
    final sdk = Restore16b()..token = 'controlled-same-token';
    final api = AlchemistDiaryApi(
      endpoint16b,
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media19'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async {
        final q = jsonDecode(body!);
        if (q['operation'] == 'auth.whoami') {
          return ok16b({
            'subject': 'controlled-A',
            'role': 'MASTER',
            'expiresAt':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          });
        }
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': false,
            'status': 401,
            'error': {'code': 'AUTH_REQUIRED'},
          }),
        );
      },
    )..bindIdentity(sdk);
    try {
      await api.authenticateReader('controlled-same-token');
      final scope = api.readerScope;
      expect(api.readerAuthenticated, true);
      await expectLater(
        api.author.call('catalog.list', {'limit': 10}),
        throwsA(isA<DiaryApiException>()),
      );
      expect(sdk.restores, 1);
      expect(sdk.interactive, 0);
      expect(api.readerAuthenticated, false);
      expect(api.readerScope, scope); // No reassignment or deletion of data.
      // A later successful whoami with the SAME token can re-establish trust:
      // therefore this is not proof that the phone must show a picker.
      expect(await api.restoreIdentity(), true);
      expect(api.readerAuthenticated, true);
      expect(sdk.interactive, 0);
    } finally {
      await f.close();
    }
  });
}
