import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

import 'support/fakes.dart';

void main() {
  sqfliteFfiInit();
  test('G01 P05: SQLite v3 to v4 adds diary only; audio bytes, catalog, draft, template, frozen history/events identical', () async {
    final dir = await Directory.systemTemp.createTemp('sulfi_v3_migration');
    final path = '${dir.path}/library.sqlite';
    var db = await openAppDatabase(path, factory: databaseFactoryFfi);
    final audio = SqliteLibraryRepository(db),
        runs = SqliteSessionRepository(db);
    final catalog = ModuleCatalog(db);
    final library = LibraryService(
      repository: audio,
      directory: Directory('${dir.path}/audio'),
      pick: () async => null,
      probe: (_) async => const Duration(seconds: 65),
    );
    await library.initialize();
    await audio.save(sampleAsset());
    final file = library.fileFor(sampleAsset());
    await file.writeAsBytes([1, 2, 3, 4]);
    final c = SessionController(
      repository: runs,
      library: library,
      modules: catalog,
    );
    await c.initialize();
    final phase = await c.createPhase('work');
    final m = ModuleDefinition(
      id: 'legacy-module',
      title: 'Существующий модуль',
      items: const [
        SessionStep(
          id: 'a',
          kind: StepKind.audio,
          title: 'Аудио',
          audioAssetId: 'sample',
          durationMs: 65000,
        ),
        SessionStep(
          id: 'silence',
          kind: StepKind.silence,
          title: 'Старая тишина',
          durationMs: 12000,
        ),
        SessionStep(
          id: 'work',
          kind: StepKind.freeWork,
          title: 'Старая работа',
          durationMs: null,
        ),
      ],
    );
    await catalog.save(m);
    await c.addModule(phase, m);
    await c.saveAsTemplate('Личный шаблон', 'Описание');
    await c.setText(topic: 'Тема', notes: 'Заметка');
    final run = await runs.startRun(await c.snapshotForStart());
    await runs.checkpoint(
      run.checkpoint(status: RunStatus.interrupted, elapsedMs: 17000),
    );
    final tables = [
      'audio_assets',
      'module_definitions',
      'current_draft',
      'session_templates',
      'session_runs',
      'run_events',
      'app_counters',
    ];
    final before = {for (final table in tables) table: await db.query(table)};
    // Fixture exactly representing the preceding schema: no diary tables.
    for (final table in ['diary_public', 'diary_author', 'diary_sync']) {
      await db.execute('DROP TABLE $table');
    }
    await db.execute('PRAGMA user_version=3');
    c.dispose();
    await db.close();
    db = await openAppDatabase(path, factory: databaseFactoryFfi);
    for (final table in tables) {
      expect(await db.query(table), before[table], reason: table);
    }
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    final restored = (await SqliteSessionRepository(
      db,
    ).loadDraft())!.plan.steps;
    expect(restored.map((s) => s.kind), [
      StepKind.audio,
      StepKind.silence,
      StepKind.freeWork,
    ]);
    expect(restored.map((s) => s.durationMs), [65000, 12000, null]);
    expect(await db.query('diary_public'), isEmpty);
    expect(await db.query('diary_author'), isEmpty);
    await db.close();
    await dir.delete(recursive: true);
  });
}
