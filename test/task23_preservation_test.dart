// Real FFI SQLite / files and existing domain controllers on synthetic data.
// Not an Android install/upgrade, real Google identity, or owner-data recovery.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;
import 'task23_repro_test.dart' show manifest23;

Future<Map<String, String>> media23(Directory root) async => {
  for (final f in await root.list(recursive: true, followLinks: false).toList())
    if (f is File && !f.path.contains('/db'))
      f.path.substring(root.path.length):
          (await sha256.bind(f.openRead()).first).toString(),
};

Future<void> copy23(Directory src, Directory dst) async {
  await dst.create();
  await for (final entity in src.list(recursive: true, followLinks: false)) {
    final target = '${dst.path}${entity.path.substring(src.path.length)}';
    if (entity is Directory) await Directory(target).create(recursive: true);
    if (entity is File) await entity.copy(target);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final version in [6, 7, 8, 9]) {
    test(
      '23 schema$version→9 and second cold start retain full synthetic graph and exact frozen payloads',
      () async {
        final f = await Fixture15.open();
        final parent = await Directory.systemTemp.createTemp('task23-upgrade-');
        final clone = Directory('${parent.path}/new-install-same-data');
        Database? reopened;
        try {
          final module = await seed15(f);
          final phase = await f.c.createPhase('work');
          await f.c.addModule(phase, module);
          await f.c.saveAsTemplate('Личная программа', 'Точное описание');
          await f.c.setText(topic: 'Запрос', notes: 'Личная заметка');
          final sessions = SqliteSessionRepository(f.db);
          final run = await sessions.startRun(await f.c.snapshotForStart());
          await sessions.checkpoint(
            run.checkpoint(status: RunStatus.interrupted, elapsedMs: 12345),
          );
          final now = DateTime.utc(2026);
          await DiaryAuthorRepository(f.db).save(
            DiaryEntry(
              id: 'offline-local',
              message: 'Личный офлайн-черновик',
              createdAt: now,
              updatedAt: now,
              extra: {'_alchemistScope': 'local-device'},
            ),
          );
          await f.db.insert('app_settings', {
            'name': 'alchemist_identity_hint',
            'value': '{malformed',
          });
          await File('${f.root.path}/unknown-owner.keep')
              .writeAsString('SYNTHETIC DO NOT GC');
          await f.c.capsules!.export(moduleId: module.id);
          await f.c.flush();
          if (version < 9) await f.db.execute('DROP TABLE content_revisions');
          if (version < 8) await f.db.execute('DROP TABLE history_attachments');
          if (version < 7) {
            await f.db.execute('DROP TABLE app_settings');
            await f.db.execute(
              'ALTER TABLE audio_assets DROP COLUMN authorManaged',
            );
          }
          await f.db.execute('PRAGMA user_version=$version');
          final tables = [
            'audio_assets',
            'module_definitions',
            'session_templates',
            'current_draft',
            'session_runs',
            'run_events',
            'app_counters',
            'diary_author',
            'capsule_imports',
          ];
          final before = {
            for (final table in tables) table: await f.db.query(table),
          };
          final files = await media23(f.root);
          f.c.dispose();
          await f.player.close();
          await f.db.close();
          await copy23(f.root, clone);
          for (var cold = 0; cold < 2; cold++) {
            reopened = await openAppDatabase(
              '${clone.path}/db',
              factory: databaseFactoryFfi,
            );
            expect(await reopened.getVersion(), 9);
            expect(await reopened.rawQuery('PRAGMA integrity_check'), [
              {'integrity_check': 'ok'},
            ]);
            for (final table in tables) {
              final after = await reopened.query(table);
              expect(after.length, before[table]!.length, reason: table);
              for (var i = 0; i < after.length; i++) {
                for (final entry in before[table]![i].entries) {
                  expect(
                    after[i][entry.key],
                    entry.value,
                    reason: '$table.${entry.key}',
                  );
                }
              }
            }
            expect((await SqliteLibraryRepository(reopened).list()).length, 3);
            final catalog = ModuleCatalog(reopened);
            await catalog.load();
            expect(catalog.entries.single.title, module.title);
            expect(
              (await SqliteSessionRepository(reopened).loadDraft())!.topicText,
              'Запрос',
            );
            final diary = DiaryController(
              DiaryRepository(reopened),
              policy: AccessPolicy(database: reopened),
              authorRepository: DiaryAuthorRepository(reopened),
            );
            await diary.load();
            expect(diary.drafts.map((e) => e.id), ['offline-local']);
            diary.dispose();
            expect(await media23(clone), files);
            await reopened.close();
            reopened = null;
          }
          expect(
            await media23(f.root),
            files,
            reason: 'original copy never mutated',
          );
        } finally {
          await reopened?.close();
          if (f.db.isOpen)
            await f.close();
          else if (await f.root.exists())
            await f.root.delete(recursive: true);
          await parent.delete(recursive: true);
        }
      },
    );
  }

  test('23 wrong-path duplicate SQLite alias never creates empty replacement or selects owner by filename', () async {
    final root = await Directory.systemTemp.createTemp('task23-alias-');
    try {
      final db = await openAppDatabase(
        '${root.path}/legacy.sqlite',
        factory: databaseFactoryFfi,
      );
      await db.insert('module_definitions', {
        'id': 'kept',
        'payload': '{"id":"kept"}',
      });
      await db.close();
      final original = await File('${root.path}/legacy.sqlite').readAsBytes();
      await expectLater(
        openAppDatabase(
          '${root.path}/library.sqlite',
          factory: databaseFactoryFfi,
        ),
        throwsFormatException,
      );
      expect(await File('${root.path}/library.sqlite').exists(), false);
      expect(await File('${root.path}/legacy.sqlite').readAsBytes(), original);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('23 background rejects old schema before opening source RW or modifying journal', () async {
    final f = await Fixture15.open();
    try {
      await f.db.execute('DROP TABLE content_revisions');
      await f.db.execute('PRAGMA user_version=8');
      await f.db.close();
      final file = File('${f.root.path}/db'), before = await file.readAsBytes();
      await expectLater(
        openAppDatabase(
          file.path,
          factory: databaseFactoryFfi,
          allowMigrations: false,
        ),
        throwsFormatException,
      );
      expect(await file.readAsBytes(), before);
    } finally {
      f.c.dispose();
      await f.player.close();
      if (f.db.isOpen) await f.db.close();
      await f.root.delete(recursive: true);
    }
  });

  test('23 existing verified same-owner aliases export only A then only B; logout/malformed hint preserve local data', () async {
    final f = await Fixture15.open();
    var subject = 'subject-a';
    final api = AlchemistDiaryApi(
      Uri.parse('https://script.google.com/macros/s/SYNTHETIC/exec'),
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async => DiaryResponse(
        200,
        jsonEncode({
          'ok': true,
          'status': 200,
          'result': {
            'subject': subject,
            'role': 'MASTER',
            'expiresAt':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        }),
      ),
    );
    f.c.capsules!.canReadAuthorDraftScope = api.canReadAuthorDraftScope;
    f.c.capsules!.exportOwnerBinding = () => api.readerScope;
    final author = DiaryAuthorRepository(f.db);
    final d = DiaryController(
      AlchemistDiaryRepository(f.db, scope: () => api.readerScope),
      api: api,
      policy: f.c.policy,
      authorRepository: author,
    );
    try {
      Future<void> verify() async {
        await api.authenticateReader('controlled-no-google-token');
        f.c.policy.applyVerifiedServerRole(api.verifiedRole);
      }

      await verify();
      final scopeA = api.readerScope, now = DateTime.utc(2026);
      for (final pair in {
        'a-legacy': 'google:subject-a',
        'a-current': scopeA,
        'b-legacy': 'google:subject-b',
        'local': 'local-device',
      }.entries) {
        await author.save(
          DiaryEntry(
            id: pair.key,
            message: 'Synthetic',
            createdAt: now,
            updatedAt: now,
            extra: {'_alchemistScope': pair.value},
          ),
        );
      }
      final before = await f.db.query('diary_author', orderBy: 'id');
      Future<Set<String>> exported() async =>
          ((await manifest23(
                    await f.c.capsules!.export(),
                  ))['records']['diary_author']
                  as List)
              .map((r) => r['id'] as String)
              .toSet();
      expect(await exported(), {'a-legacy', 'a-current', 'local'});
      subject = 'subject-b';
      await verify();
      await d.load();
      expect(d.drafts.map((e) => e.id).toSet(), {'b-legacy', 'local'});
      expect(await exported(), {'b-legacy', 'local'});
      api.clearSession();
      f.c.policy.applyVerifiedServerRole(null);
      await f.db.update(
        'app_settings',
        {'value': '{malformed'},
        where: 'name=?',
        whereArgs: ['alchemist_identity_hint'],
      );
      await api.loadLocalIdentityHint();
      await d.load();
      expect(d.drafts.map((e) => e.id).toSet(), {'local'});
      expect(await exported(), {'local'});
      expect(await f.db.query('diary_author', orderBy: 'id'), before);
    } finally {
      d.dispose();
      await f.close();
    }
  });

  test('23 mutation at transaction hook rolls back every row and newly materialized file', () async {
    final a = await Fixture15.open(), b = await Fixture15.open();
    CapsulePreview? preview;
    try {
      await seed15(a);
      preview = await b.c.capsules!.inspect(
        await a.c.capsules!.export(moduleId: 'portable-module'),
      );
      final before = await media23(b.root);
      await expectLater(
        b.c.capsules!.restore(
          preview,
          beforeCommit: () async {
            preview!.manifest['id'] = 'mutated-during-transaction';
          },
        ),
        throwsFormatException,
      );
      expect(await b.db.query('audio_assets'), isEmpty);
      expect(await b.db.query('module_definitions'), isEmpty);
      expect(await b.db.query('capsule_imports'), isEmpty);
      expect(await media23(b.root), before);
    } finally {
      await preview?.close();
      await a.close();
      await b.close();
    }
  });

  test(
    '23 already-imported preview cannot mask later DB or audio mutation',
    () async {
      final a = await Fixture15.open(), b = await Fixture15.open();
      CapsulePreview? initial, stale;
      try {
        await seed15(a);
        final zip = await a.c.capsules!.export(moduleId: 'portable-module');
        initial = await b.c.capsules!.inspect(zip);
        await b.c.capsules!.restore(initial);
        stale = await b.c.capsules!.inspect(zip);
        expect(stale.alreadyImported, true);
        final row = (await b.db.query('audio_assets')).first;
        final path = File('${b.c.library.directory.path}/${row['filePath']}');
        await path.writeAsString('CHANGED BY SYNTHETIC TEST');
        await expectLater(b.c.capsules!.restore(stale), throwsFormatException);
        expect(
          await path.readAsString(),
          'CHANGED BY SYNTHETIC TEST',
          reason: 'no silent repair/overwrite',
        );
      } finally {
        await stale?.close();
        await initial?.close();
        await a.close();
        await b.close();
      }
    },
  );
}
