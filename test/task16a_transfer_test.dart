// Local regression evidence only: no real Google user or phone is simulated.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_store_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_export_test.dart' show seed15;

class SignedIn16 extends DiaryApi {
  SignedIn16()
    : super(Uri.parse('https://script.google.com/macros/s/UNIT/exec'));
  bool signedIn = true;
  @override
  bool get supportsServerIdentity => true;
  @override
  bool get readerAuthenticated => signedIn;
  @override
  String get readerScope => signedIn ? 'google:fixture-reader' : 'public';
  @override
  String? get verifiedRole => signedIn ? 'CLIENT' : null;
  @override
  void clearSession() {
    signedIn = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'catalog reflects existing verified login and logout instead of showing a second login',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!, api = SignedIn16();
      final d = DiaryController(
        DiaryRepository(f.db),
        api: api,
        policy: f.c.policy,
      );
      final c = SessionController(
        repository: f.c.repository,
        library: f.c.library,
        modules: f.c.modules,
        capsules: f.c.capsules,
        diary: d,
      );
      try {
        await show15(t, f, AlchemistStoreScreen(controller: c));
        await io15(t);
        expect(find.text('Выйти из Google'), findsOneWidget);
        expect(find.text('Войти для личных материалов'), findsNothing);
        await t.runAsync(d.logout);
        await io15(t);
        expect(find.text('Выйти из Google'), findsNothing);
        expect(find.text('Войти для личных материалов'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      } finally {
        c.dispose();
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
  test('capsule retains official provenance, exact revisions and client rights; malformed metadata cannot grant MASTER', () async {
    final a = await Fixture15.open(), b = await Fixture15.open(client: true);
    try {
      final m = await seed15(a),
          source = await LocalCatalogSource.currentIndex(a.c.capsules!);
      await a.c.policy.registerCatalogOriginals(
        source.map((r) => r.key.toMap()),
        'https://script.google.com/macros/s/UNIT/exec',
        'published-module',
      );
      final zip = await a.c.capsules!.export(moduleId: m.id),
          preview = await b.c.capsules!.inspect(zip);
      try {
        expect(preview.manifest['catalogOrigins'], hasLength(4));
        await b.c.capsules!.restore(preview);
        await b.c.reload();
        expect(b.c.policy.isCatalogOriginal('module', m.id), true);
        expect(b.c.policy.isAuthor, false);
        expect(
          await LocalCatalogSource.installedRevision(
            b.c.capsules!,
            source.singleWhere((r) => r.key.content.id == m.id),
          ),
          true,
        );
        await expectLater(
          b.c.modules.save(b.c.modules.entries.single),
          throwsA(isA<Exception>()),
        );
        final records = await b.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_origin:%'],
        );
        expect(records, hasLength(4));
        expect(jsonEncode(records).contains('MASTER'), false);
      } finally {
        await preview.close();
      }
      expect(
        () => AccessPolicy.validateCatalogOrigin({
          'origin': 'official',
          'key': source.first.key.toMap(),
          'sourceEndpoint': 'file:///private/secret',
          'catalogItemId': 'card',
          'role': 'MASTER',
        }),
        throwsFormatException,
      );
      final safe = AccessPolicy.validateCatalogOrigin({
        'origin': 'official',
        'key': source.first.key.toMap(),
        'sourceEndpoint': 'https://script.google.com/macros/s/UNIT/exec',
        'catalogItemId': 'card',
        'role': 'MASTER',
        'credential': 'NOT_A_TOKEN',
      });
      expect(safe.containsKey('role'), false);
      expect(safe.containsKey('credential'), false);
    } finally {
      await a.close();
      await b.close();
    }
  });
}
