// Real disposable SQLite/files and the existing importer/session state machine.
// TestTransport is controlled; this is NOT Android/audio/OAuth acceptance.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/services/session_engine.dart';

import 'support/session_transport_fake.dart';
import 'support/task15_fixture.dart';
import 'support/task21_server.dart';
import 'task15_export_test.dart' show seed15;

Future<Map<String, String>> media25(Directory root) async => {
  await for (final f in root.list(recursive: true, followLinks: false))
    if (f is File)
      f.path.substring(root.path.length): sha256
          .convert(await f.readAsBytes())
          .toString(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('25 installed program keeps exact module/media after author edit; offline execution, history and paused queue survive cold reopen', () async {
    final author = await Fixture15.open();
    final client = await Fixture15.open(client: true);
    LocalCatalogSource? source;
    SessionEngine? engine;
    AlchemistWorkQueue? queue;
    Database? reopened;
    final coldRoot = await Directory.systemTemp.createTemp('task25-cold-');
    try {
      final module = await seed15(author);
      final phase = await author.c.createPhase('induction');
      await author.c.addModule(phase, module);
      final program = await author.c.saveAsTemplate(
        'Программа 25',
        'Три трека',
      );
      final now = DateTime.utc(2026);
      await DiaryAuthorRepository(author.db).save(
        DiaryEntry(
          id: 'author-private',
          message: 'Не входит в выборочную установку',
          createdAt: now,
          updatedAt: now,
          extra: {'_alchemistScope': 'google:synthetic-author'},
        ),
      );
      source = await LocalCatalogSource.open(
        client.c.capsules!,
        await author.c.capsules!.export(templateId: program.id),
      );
      final root = source.revisions.singleWhere(
        (r) => r.key.content.type == ContentType.template,
      );
      await source.install(await source.plan(root.key));
      await client.c.reload();
      expect(client.c.assets, hasLength(3));
      expect(client.c.templates.single.id, program.id);
      expect(await client.db.query('diary_author'), isEmpty);
      final originalMedia = await media25(client.c.library.directory);
      await author.c.modules.save(
        ModuleDefinition(
          id: module.id,
          title: module.title,
          version: 2,
          items: const [
            SessionStep(
              id: 'new',
              kind: StepKind.silence,
              title: 'Новая пауза',
              durationMs: 1000,
            ),
          ],
        ),
      );
      expect(client.c.modules.entries.single.version, 1);
      expect(client.c.modules.entries.single.items, hasLength(5));
      await client.c.loadTemplate(client.c.templates.single);
      final transport = TestTransport();
      var clock = 0;
      engine = SessionEngine(
        controller: client.c,
        transport: transport,
        nowMs: () => clock,
      );
      await engine.start();
      final frozen = jsonEncode(engine.run!.snapshot.toMap());
      while (engine.active) {
        if (engine.run!.phase == 'audio') {
          transport.completed = true;
        } else {
          clock += engine.phaseDurationMs ?? 0;
        }
        engine.tick();
        await engine.flush();
      }
      expect(engine.run!.status, RunStatus.completed);
      expect(transport.loaded, hasLength(3));
      expect(engine.run!.completedStepIds, hasLength(5));
      expect(engine.run!.skippedStepIds, isEmpty);
      expect(jsonEncode(engine.run!.snapshot.toMap()), frozen);
      await engine.close();
      engine = null;

      const job = 'alchemist_download:synthetic-client:resume';
      queue = AlchemistWorkQueue(
        db: client.db,
        owner: () => 'synthetic-client',
        dispatch: () async {},
        send: (_, _, _, _, _) async => fail('A user-paused task must not run'),
      );
      await queue.enqueueDownload(job, {
        'kind': 'media',
        'checkpoint': {'offset': 8192, 'sha256': 'a' * 64},
      });
      await queue.pause(job);
      await queue.runPending();
      queue.dispose();
      queue = null;
      await client.c.flush();
      final tables = [
        'audio_assets',
        'module_definitions',
        'session_templates',
        'current_draft',
        'session_runs',
        'run_events',
        'app_settings',
        'capsule_imports',
      ];
      final rows = {for (final t in tables) t: await client.db.query(t)};
      client.c.dispose();
      await client.player.close();
      await client.db.close();
      final copy = await File('${client.root.path}/db')
          .copy('${coldRoot.path}/db');
      reopened = await openAppDatabase(
        copy.path,
        factory: databaseFactoryFfi,
        allowMigrations: false,
      );
      expect(await reopened.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      for (final t in tables) {
        expect(await reopened.query(t), rows[t], reason: 'cold retained $t');
      }
      final history = await SqliteSessionRepository(reopened).history();
      expect(jsonEncode(history.single.snapshot.toMap()), frozen);
      final stored = jsonDecode(
        (await reopened.query(
              'app_settings',
              where: 'name=?',
              whereArgs: [job],
            )).single['value']
            as String,
      );
      expect(stored['ownerBinding'], 'synthetic-client');
      expect(stored['_work']['pauseReason'], 'USER_PAUSED');
      expect(stored['download']['checkpoint']['offset'], 8192);
      expect(await media25(client.c.library.directory), originalMedia);
      expect(client.c.metadataEnabled, false);
      expect(client.c.project22Enabled, false);
    } finally {
      queue?.dispose();
      await engine?.close();
      await reopened?.close();
      await source?.close();
      await author.close();
      // The test deliberately closed the original DB before opening a COPY.
      if (client.db.isOpen) {
        await client.close();
      } else {
        await client.root.delete(recursive: true);
      }
      await coldRoot.delete(recursive: true);
    }
  });

  for (final client in [false, true]) {
    test(
      '25 ${client ? 'CLIENT' : 'MASTER'} ignores available candidate22 backend when both feature flags are OFF',
      () async {
        final server = await Server21.open(
          script: 'server/alchemist/test/support/project22-fixture.cjs',
        );
        final app = await App21.open(server, client: client, enabled: false);
        try {
          final before = await server.call('control.state', {});
          final original = await app.f.db.query('app_settings');
          expect(app.c.metadata, null);
          expect(app.c.project22, null);
          await app.c.reload();
          expect(app.c.metadata, null);
          expect(app.c.project22, null);
          final after = await server.call('control.state', {});
          for (final op in [
            'catalog.head',
            'catalog.snapshot',
            'project.overview',
            'ratings.head',
            'ratings.snapshot',
          ]) {
            expect(after['counts'][op], before['counts'][op], reason: op);
          }
          expect(await app.f.db.query('app_settings'), original);
        } finally {
          await app.close();
          await server.close();
        }
      },
    );
  }
}
