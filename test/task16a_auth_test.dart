// Local regressions only. These fixtures are never evidence of real Google login.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_identity.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

class FixtureIdentity16A implements DiaryIdentity {
  String token = 'client-fixture';
  @override
  Future<DiaryIdentityResult> signIn() async => DiaryIdentityResult(
    // Deliberately misleading local email: server role remains authoritative.
    email: 'luxhypnomaster@gmail.com',
    idToken: token,
  );
  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('server CLIENT in master edition cannot become author using email or local toggle; owner in client edition retains server MASTER', () async {
    for (final clientEdition in [false, true]) {
      final f = await Fixture15.open(client: clientEdition),
          identity = FixtureIdentity16A();
      final api = AlchemistDiaryApi(
        Uri.parse('https://script.google.com/macros/s/UNIT/exec'),
        capsules: f.c.capsules!,
        media: DiaryMediaStore(
          Directory('${f.root.path}/diary'),
          pick: (_) async => null,
          probe: (_) async => null,
        ),
        connection: (_, _, _, body) async {
          final request = jsonDecode(body!), op = request['operation'];
          final master = request['credential'] == 'master-fixture';
          return DiaryResponse(
            200,
            jsonEncode({
              'ok': true,
              'status': 200,
              'result': op == 'auth.whoami'
                  ? {
                      'subject': master ? 'owner-unit' : 'reader-unit',
                      'role': master ? 'MASTER' : 'CLIENT',
                      'roles': [master ? 'owner' : 'client'],
                      'expiresAt':
                          DateTime.now()
                              .add(const Duration(hours: 1))
                              .millisecondsSinceEpoch ~/
                          1000,
                    }
                  : {
                      'entries': [],
                      'revision': 1,
                      'items': [],
                      'version': 0,
                      'readerState': {'entries': [], 'etag': '0'},
                      'nextPage': null,
                    },
            }),
          );
        },
      );
      final d = DiaryController(
        AlchemistDiaryRepository(f.db, scope: () => api.readerScope),
        api: api,
        policy: f.c.policy,
        authorRepository: DiaryAuthorRepository(f.db),
        identity: identity,
      );
      try {
        expect(f.c.policy.isAuthor, false);
        await d.signInAuthor();
        expect(d.error, isNull);
        expect(d.authenticated, true);
        expect(api.verifiedRole, 'CLIENT');
        expect(d.authorWorkspace, false);
        expect(f.c.policy.isAuthor, false);
        await expectLater(
          f.c.policy.setMode(LocalMode.author),
          throwsA(isA<Exception>()),
        );
        identity.token = 'master-fixture';
        await d.signInAuthor();
        expect(api.verifiedRole, 'MASTER');
        expect(d.authenticated, true);
        expect(f.c.policy.isAuthor, !clientEdition);
        expect(d.authorWorkspace, !clientEdition);
        await d.logout();
        expect(d.authenticated, false);
        expect(api.verifiedRole, isNull);
        expect(d.authorWorkspace, false);
        expect(f.c.policy.isAuthor, false);
        await expectLater(
          api.verifiedIdentityToken(),
          throwsA(isA<DiaryApiException>()),
        );
      } finally {
        d.dispose();
        await f.close();
      }
    }
  });
  test('account switch while HTTP is pending discards the response, with no retry or stale body exposure', () async {
    var scope = 'account-a', calls = 0;
    final pending = Completer<DiaryResponse>();
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/UNIT/exec'),
      identityScope: () => scope,
      credential: () async => 'UNIT',
      connection: (_, _, _, _) {
        calls++;
        return pending.future;
      },
    );
    final request = api.call('catalog.list', {});
    final rejected = expectLater(request, throwsA(isA<DiaryApiException>()));
    await Future<void>.delayed(Duration.zero);
    scope = 'account-b';
    pending.complete(
      const DiaryResponse(
        200,
        '{"ok":true,"status":200,"result":{"private":"ACCOUNT_A"}}',
      ),
    );
    await rejected;
    expect(calls, 1);
  });
  test('official catalog provenance survives reload without changing canonical revisions; personal copy remains editable and local export needs no API', () async {
    final f = await Fixture15.open();
    try {
      final module = await seed15(f),
          before = (await LocalCatalogSource.currentIndex(f.c.capsules!))
              .singleWhere((r) => r.key.content.id == module.id);
      await f.c.policy.registerCatalogOriginals(
        [before.key.toMap()],
        'https://script.google.com/macros/s/UNIT/exec',
        'published-card',
      );
      f.c.policy.applyVerifiedServerRole('CLIENT');
      await f.c.policy.load();
      expect(f.c.policy.isCatalogOriginal('module', module.id), true);
      expect(
        (await LocalCatalogSource.currentIndex(f.c.capsules!))
            .singleWhere((r) => r.key.content.id == module.id)
            .key
            .digest,
        before.key.digest,
      );
      await expectLater(f.c.modules.save(module), throwsA(isA<Exception>()));
      final copy = ModuleDefinition(
        id: 'personal-copy',
        title: 'Моя копия',
        items: module.items,
        parentRevision: before.key,
      );
      await f.c.modules.save(copy);
      expect(f.c.policy.isCatalogOriginal('module', copy.id), false);
      final now = DateTime.now().toUtc();
      await DiaryAuthorRepository(f.db).save(
        DiaryEntry(
          id: 'private-author',
          title: 'Private',
          message: 'SECRET_MASTER_DRAFT',
          body: 'MASTER_ONLY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final file = await f.c.capsules!.export();
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content),
      );
      expect(jsonEncode(manifest).contains('SECRET_MASTER_DRAFT'), false);
      expect(await f.db.query('diary_author'), hasLength(1));
      expect(f.c.assets, hasLength(3));
      expect(
        (await f.c.capsules!.export(moduleId: copy.id)).existsSync(),
        true,
      );
    } finally {
      await f.close();
    }
  });
}
