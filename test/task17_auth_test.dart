import 'dart:async';

import 'package:sulfi_hypnotherapy/services/diary_identity.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diagnostics.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'support/task15_fixture.dart';
import 'task16b_auth_transport_test.dart' show Restore16b, ok16b, endpoint16b;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('17 G1 same-owner cold/expiry restore without chooser; logout intent blocks SDK restore and private hints', () async {
    final f = await Fixture15.open();
    final sdk = Restore16b();
    var now = DateTime.now().toUtc();
    AlchemistDiaryApi make() => AlchemistDiaryApi(
      endpoint16b,
      capsules: f.c.capsules!,
      clock: () => now,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async {
        final q = jsonDecode(body!);
        return ok16b(
          q['operation'] == 'auth.whoami'
              ? {
                  'subject': 'controlled-owner',
                  'role': 'MASTER',
                  'expiresAt':
                      now
                          .add(const Duration(hours: 1))
                          .millisecondsSinceEpoch ~/
                      1000,
                }
              : {'entries': [], 'revision': 0, 'items': []},
        );
      },
    )..bindIdentity(sdk);
    final api = make();
    final d = DiaryController(
      DiaryRepository(f.db),
      api: api,
      identity: sdk,
      policy: f.c.policy,
      authorRepository: DiaryAuthorRepository(f.db),
    );
    try {
      await d.signInAuthor(); // restore of a previously authorized SDK account
      expect(sdk.interactive, 0);
      expect(d.authenticated, true);
      final scope = api.readerScope;
      final cold = make();
      await cold.loadLocalIdentityHint();
      expect(cold.readerScope, scope);
      expect(cold.verifiedRole, isNull);
      expect(cold.canReadAuthorDraftScope(scope), true);
      now = now.add(const Duration(hours: 2));
      sdk.token = 'fresh';
      await d.signInAuthor();
      expect(sdk.interactive, 0);
      expect(api.readerScope, scope);
      await d.logout();
      final afterLogout = make();
      await afterLogout.loadLocalIdentityHint();
      expect(afterLogout.readerScope, 'public');
      final restores = sdk.restores;
      await expectLater(
        afterLogout.verifiedIdentityToken(),
        throwsA(isA<DiaryApiException>()),
      );
      expect(sdk.restores, restores);
      expect(afterLogout.canReadAuthorDraftScope(scope), false);
      final rows = await f.db.query('app_settings');
      expect(jsonEncode(rows), isNot(contains('fresh')));
    } finally {
      d.dispose();
      await f.close();
    }
  });
  test('17 G1 offline local author draft before Google does not reveal or rescope other account draft', () async {
    final f = await Fixture15.open();
    final repo = DiaryAuthorRepository(f.db);
    final api = AlchemistDiaryApi(
      endpoint16b,
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, _) async =>
          throw const SocketException('CONTROLLED_OFFLINE'),
    );
    final d = DiaryController(
      DiaryRepository(f.db),
      api: api,
      identity: Restore16b(),
      policy: f.c.policy,
      authorRepository: repo,
    );
    final now = DateTime.now().toUtc();
    final private = DiaryEntry(
      id: 'other',
      title: 'Private',
      message: 'Private text',
      createdAt: now,
      updatedAt: now,
      extra: {'_alchemistScope': 'account:other'},
    );
    try {
      await repo.save(private);
      await d.load();
      expect(d.authorWorkspace, true);
      expect(d.drafts, isEmpty);
      final local = DiaryEntry(
        id: 'local',
        title: 'Local',
        message: 'Short only',
        createdAt: now,
        updatedAt: now,
      );
      await d.saveDraft(local);
      expect(d.drafts.single.id, 'local');
      expect(d.drafts.single.extra['_alchemistScope'], 'local-device');
      await expectLater(
        d.saveDraft(private),
        throwsA(isA<DiaryApiException>()),
      );
      expect(
        (await repo.entries())
            .singleWhere((e) => e.id == 'other')
            .extra['_alchemistScope'],
        'account:other',
      );
      await expectLater(
        d.publish(d.drafts.single, published: true),
        throwsA(isA<Exception>()),
      );
    } finally {
      d.dispose();
      await f.close();
    }
  });

  test('17 G1 explicit logout invalidates pending chooser without clearing a newer login busy state', () async {
    final f = await Fixture15.open();
    final sdk = Deferred17();
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
    try {
      final first = d.signInAuthor();
      while (sdk.requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await d.logout();
      expect(d.authorBusy, false);
      final second = d.signInAuthor();
      while (sdk.requests.length < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      sdk.requests[0].complete(
        const DiaryIdentityResult(
          email: 'old@example.test',
          idToken: 'old-controlled',
        ),
      );
      await first;
      expect(d.authorBusy, true);
      expect(api.verifiedRole, isNull);
      sdk.requests[1].complete(
        const DiaryIdentityResult(
          email: 'new@example.test',
          idToken: 'new-controlled',
        ),
      );
      await second;
      expect(d.authenticated, true);
      expect(d.authorBusy, false);
    } finally {
      d.dispose();
      await f.close();
    }
  });
  test(
    '17 G0 trace opt-in, bounded TTL, safe codes and explicit redacted export',
    () async {
      final off = AlchemistDiagnostics();
      off.stage('SESSION_RESTORE_START');
      expect(off.events, isEmpty);
      final on = AlchemistDiagnostics(
        enabled: true,
        ttl: const Duration(milliseconds: 40),
      );
      on.stage('QUEUE_OWNER_MATCH', ownerEqual: true);
      on.stage('https://secret@example.test');
      expect(on.events.length, 1);
      expect(on.events.single['ownerEqual'], true);
      expect(on.export(), isNot(contains('secret')));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(on.events, isEmpty);
      off.dispose();
      on.dispose();
    },
  );
}

class Deferred17 implements DiaryIdentity {
  final requests = <Completer<DiaryIdentityResult>>[];
  @override
  Future<DiaryIdentityResult> signIn() {
    final c = Completer<DiaryIdentityResult>();
    requests.add(c);
    return c.future;
  }

  @override
  Future<void> signOut() async {}
}
