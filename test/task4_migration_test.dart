import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';

import 'support/fakes.dart';

void main() {
  sqfliteFfiInit();
  test('real SQLite v5→v6 retains every old column, payload, stable ID and audio byte', () async {
    final root = await Directory.systemTemp.createTemp('task4-migration');
    final path = '${root.path}/library.sqlite';
    var db = await openAppDatabase(path, factory: databaseFactoryFfi);
    final asset = sampleAsset();
    await SqliteLibraryRepository(db).save(asset);
    final file = await File('${root.path}/${asset.filePath}')
        .writeAsBytes([1, 2, 3, 4]);
    final now = DateTime.utc(2026, 11, 7);
    final plan = SessionPlan(
      steps: [
        SessionStep(
          id: 'step',
          kind: StepKind.audio,
          title: 'Тест',
          audioAssetId: asset.id,
          durationMs: 65000,
        ),
      ],
    );
    final template = SessionTemplate(
      id: 'template',
      name: 'Тест',
      plan: plan,
      createdAt: now,
      updatedAt: now,
    );
    final sessions = SqliteSessionRepository(db);
    await sessions.saveTemplate(template);
    await sessions.saveDraft(CurrentSessionDraft.fromTemplate(template));
    final run = await sessions.startRun((await sessions.loadDraft())!);
    await sessions.checkpoint(
      run.checkpoint(status: RunStatus.interrupted),
      event: 'interrupted',
    );
    await ModuleCatalog(db).save(
      ModuleDefinition(id: 'module', title: 'Модуль', items: plan.allSteps),
    );
    await DiaryAuthorRepository(db).save(
      DiaryEntry(
        id: 'draft',
        message: 'Черновик',
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final column in ['origin', 'contentHash', 'baseRevision', 'author']) {
      await db.execute('ALTER TABLE audio_assets DROP COLUMN $column');
    }
    await db.execute('DROP TABLE capsule_imports');
    await db.execute('PRAGMA user_version=5');
    final tables = [
      'audio_assets',
      'module_definitions',
      'session_templates',
      'current_draft',
      'session_runs',
      'run_events',
      'app_counters',
      'diary_author',
      'diary_public',
    ];
    final before = {for (final t in tables) t: await db.query(t)};
    await db.close();
    db = await openAppDatabase(path, factory: databaseFactoryFfi);
    expect(await db.getVersion(), 6);
    for (final t in tables) {
      final after = await db.query(t);
      expect(after.length, before[t]!.length);
      for (var i = 0; i < after.length; i++) {
        for (final e in before[t]![i].entries) {
          expect(after[i][e.key], e.value, reason: '$t.${e.key}');
        }
      }
    }
    expect(
      (await SqliteLibraryRepository(db).list()).single.isPersonal,
      isTrue,
    );
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(await db.query('capsule_imports'), isEmpty);
    await db.close();
    await root.delete(recursive: true);
  });
}
