import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/task15_fixture.dart';
import 'task16b_auth_transport_test.dart' show Restore16b, ok16b, endpoint16b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('17 G0 catalog API constructed before login must see later shared login and explicit logout', () async {
    final f = await Fixture15.open();
    final sdk = Restore16b();
    final api = AlchemistDiaryApi(
      endpoint16b,
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async => ok16b(
        jsonDecode(body!)['operation'] == 'auth.whoami'
            ? {
                'subject': 'controlled-owner',
                'role': 'MASTER',
                'expiresAt':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }
            : {'entries': [], 'items': [], 'revision': 0},
      ),
    );
    final d = DiaryController(
      DiaryRepository(f.db),
      api: api,
      identity: sdk,
      policy: f.c.policy,
      authorRepository: DiaryAuthorRepository(f.db),
    );
    final c = SessionController(
      repository: f.c.repository,
      library: f.c.library,
      capsules: f.c.capsules,
      diary: d,
    );
    try {
      final reader = c.alchemistApi(authenticated: false);
      await d.signInAuthor();
      expect(await reader.credential?.call(), sdk.token);
      await d.logout();
      expect(await reader.credential?.call(), isNull);
      expect(sdk.interactive, 0);
    } finally {
      c.dispose();
      d.dispose();
      await f.close();
    }
  });
}
