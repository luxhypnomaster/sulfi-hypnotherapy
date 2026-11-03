import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/local_dates.dart';
import 'package:sulfi_hypnotherapy/data/v4_migration.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/recorder_service.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

import 'support/fakes.dart';
import 'support/capture_fake.dart';

void main() {
  sqfliteFfiInit();
  test(
    'ten phase types, repeated modules keep independent identities and pauses',
    () {
      expect(phaseTypes, hasLength(10));
      final definition = ModuleDefinition(
        id: 'm',
        title: 'Мой модуль',
        items: [
          SessionStep(
            id: 'recipe',
            kind: StepKind.audio,
            title: 'A',
            audioAssetId: 'asset',
            durationMs: 114000,
          ),
        ],
      );
      final first = definition.instantiate('p'),
          second = definition.instantiate('p');
      expect(first.id, isNot(second.id));
      expect(first.items.single.id, isNot(second.items.single.id));
      expect(first.modified, isFalse);
      final changed = first.copyWith(
        items: [first.items.single.copyWith(delayBeforeSeconds: 30)],
      );
      expect(changed.modified, isTrue);
      expect(second.items.single.delayBeforeSeconds, 0);
      expect(definition.items.single.delayBeforeSeconds, 0);
      final p = SessionPlan(
        steps: const [],
        phases: [
          PhaseInstance(
            id: 'p',
            typeId: 'work',
            title: 'Проработка',
            children: [
              changed,
              PhaseChild(
                id: 'loose',
                title: 'Тишина',
                items: [
                  const SessionStep(
                    id: 'silence',
                    kind: StepKind.silence,
                    title: 'Тишина',
                    durationMs: 300000,
                  ),
                ],
              ),
              second,
            ],
          ),
        ],
      );
      expect(p.steps.map((s) => s.id), [
        changed.items.single.id,
        'silence',
        second.items.single.id,
      ]);
      expect(p.totalMs, 558000);
      final round = SessionPlan.fromMap(p.toMap());
      expect(round.phases!.single.children, hasLength(3));
      expect(round.fingerprint, p.fingerprint);
    },
  );
  test('disabled phase/module/item excludes its own delay without deleting its data', () {
    const a = SessionStep(
      id: 'a',
      kind: StepKind.audio,
      title: 'A',
      audioAssetId: 'x',
      durationMs: 114000,
      delayBeforeSeconds: 30,
    );
    final p = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'p',
          typeId: 'work',
          title: 'P',
          children: [
            PhaseChild(
              id: 'm',
              title: 'M',
              items: [
                a,
                a.copyWith(id: 'b', enabled: false),
              ],
            ),
          ],
        ),
      ],
    );
    expect(p.totalMs, 144000);
    expect(p.allSteps, hasLength(2));
    final disabled = p.copyWith(
      phases: [p.phases!.single.copyWith(enabled: false)],
    );
    expect(disabled.totalMs, 0);
    expect(disabled.allSteps, hasLength(2));
  });
  test('V4 total example is exactly 9:57 with interleaved items', () {
    final p = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'p',
          typeId: 'work',
          title: 'P',
          children: [
            PhaseChild(
              id: 'c',
              title: 'C',
              items: [
                const SessionStep(
                  id: 'a',
                  kind: StepKind.audio,
                  title: 'A',
                  audioAssetId: 'a',
                  durationMs: 114000,
                  delayBeforeSeconds: 30,
                ),
                const SessionStep(
                  id: 'b',
                  kind: StepKind.audio,
                  title: 'B',
                  audioAssetId: 'b',
                  durationMs: 153000,
                ),
                const SessionStep(
                  id: 'w',
                  kind: StepKind.freeWork,
                  title: 'W',
                  durationMs: 300000,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    expect(p.totalMs, 597000);
  });
  test('legacy migration is idempotent and preserves noncontiguous order and first delay', () {
    final old = SessionPlan(
      steps: [
        const SessionStep(
          id: 'a',
          kind: StepKind.audio,
          title: 'Одно имя',
          audioAssetId: 'a',
          groupId: 'g',
          durationMs: 1200,
          delayBeforeSeconds: 90,
        ),
        const SessionStep(
          id: 'b',
          kind: StepKind.silence,
          title: 'Тишина',
          durationMs: 10000,
        ),
        const SessionStep(
          id: 'c',
          kind: StepKind.audio,
          title: 'Одно имя',
          audioAssetId: 'c',
          groupId: 'g',
          durationMs: 2000,
        ),
      ],
      groups: [const StageGroup(id: 'g', name: 'Личная фаза')],
    );
    final d = CurrentSessionDraft(
      plan: old,
      updatedAt: DateTime.utc(2026),
      baseFingerprint: old.fingerprint,
    );
    final converted = migratePlanDocument(d.toMap());
    expect(migratePlanDocument(converted), converted);
    final p = CurrentSessionDraft.fromMap(converted);
    expect(p.plan.phases, hasLength(3));
    expect(p.plan.phases![1].title, 'Нераспределённые');
    expect(p.plan.steps.map((s) => s.id), ['a', 'b', 'c']);
    expect(p.plan.steps.first.delayBeforeSeconds, 90);
    expect(p.modified, isFalse);
  });
  test(
    'original weekday uses stored UTC offset rather than device timezone',
    () {
      expect(
        historicalDateLabel(DateTime.utc(2026, 11, 2, 23, 30), 120),
        startsWith('Вт, 03.11.2026'),
      );
      expect(
        historicalDateLabel(DateTime.utc(2026, 11, 2, 23, 30), -120),
        startsWith('Пн, 02.11.2026'),
      );
      expect(
        historicalDateLabel(DateTime.utc(2026), null),
        contains('неизвестен'),
      );
    },
  );
  group('real SQLite upgrade from v2', () {
    test('archives original payloads, keeps file bytes and IDs, runs only once', () async {
      final dir = await Directory.systemTemp.createTemp('sulfi_v4_migration');
      final path = '${dir.path}/db.sqlite';
      var db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, v) async {
            await db.execute(
              'CREATE TABLE audio_assets(id TEXT PRIMARY KEY,title TEXT,filePath TEXT,durationMs INTEGER,format TEXT,createdAt TEXT,category TEXT,fileSizeBytes INTEGER,description TEXT,section TEXT,tags TEXT,source TEXT)',
            );
            for (final t in ['session_templates', 'current_draft']) {
              await db.execute(
                'CREATE TABLE $t(id ${t == 'current_draft' ? 'INTEGER' : 'TEXT'} PRIMARY KEY,payload TEXT NOT NULL)',
              );
            }
            await db.execute(
              'CREATE TABLE session_runs(id TEXT PRIMARY KEY,displayNumber INTEGER,status TEXT,payload TEXT NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE run_events(id INTEGER PRIMARY KEY,runId TEXT,payload TEXT)',
            );
            await db.execute(
              'CREATE TABLE app_counters(name TEXT PRIMARY KEY,value INTEGER)',
            );
          },
        ),
      );
      final a = sampleAsset();
      await db.insert('audio_assets', a.toMap());
      final bytes = File('${dir.path}/${a.filePath}');
      await bytes.writeAsBytes([7, 8, 9]);
      final draft = CurrentSessionDraft(
        plan: SessionPlan(
          steps: [
            SessionStep(
              id: 'old',
              kind: StepKind.audio,
              title: a.title,
              audioAssetId: a.id,
              durationMs: a.durationMs,
              delayBeforeSeconds: 30,
            ),
          ],
        ),
        updatedAt: DateTime.utc(2026),
      );
      final original = jsonEncode(draft.toMap());
      await db.insert('current_draft', {'id': 1, 'payload': original});
      await db.close();
      final audio = await SqliteLibraryRepository.open(
        path,
        factory: databaseFactoryFfi,
      );
      db = audio.database;
      expect((await audio.list()).single.id, a.id);
      expect(await bytes.readAsBytes(), [7, 8, 9]);
      expect(
        (await db.query('legacy_v2_documents')).single['payload'],
        original,
      );
      final sessions = SqliteSessionRepository(db);
      expect(
        (await sessions.loadDraft())!.plan.steps.single.delayBeforeSeconds,
        30,
      );
      final after = (await db.query('current_draft')).single['payload'];
      await db.close();
      final reopened = await SqliteLibraryRepository.open(
        path,
        factory: databaseFactoryFfi,
      );
      expect(
        (await reopened.database.query('legacy_v2_documents')),
        hasLength(1),
      );
      expect(
        (await reopened.database.query('current_draft')).single['payload'],
        after,
      );
      await reopened.database.close();
      await dir.delete(recursive: true);
    });
  });
  group(
    'recorder lifecycle with injected capture/decoder and actual private files',
    () {
      late Directory dir;
      late FakeCapture native;
      late MemoryRepository repo;
      late LibraryService library;
      late RecorderService r;
      setUp(() async {
        dir = await Directory.systemTemp.createTemp('sulfi_record_test');
        native = FakeCapture();
        repo = MemoryRepository();
        library = LibraryService(
          repository: repo,
          directory: Directory('${dir.path}/audio'),
          pick: () async => null,
          probe: (_) async => const Duration(seconds: 20),
        );
        await library.initialize();
        r = RecorderService(
          backend: native,
          library: library,
          tempDirectory: Directory('${dir.path}/takes'),
        );
      });
      tearDown(() async {
        await r.close();
        await dir.delete(recursive: true);
      });
      test(
        'permission denial starts no capture/file/timer; retry works',
        () async {
          native.granted = false;
          await r.start();
          expect(native.starts, 0);
          expect(r.path, isNull);
          expect(r.duration, Duration.zero);
          expect(r.error, contains('микрофону'));
          native.granted = true;
          await r.start();
          expect(r.state, CaptureState.recording);
          expect(native.starts, 1);
        },
      );
      test('finish probes duration, saves nothing; save once creates recorded personal audio', () async {
        await r.start();
        await r.pause();
        expect(r.state, CaptureState.paused);
        expect(r.level, 0);
        await r.resume();
        expect(native.resumes, 1);
        await r.finish();
        expect(r.duration, const Duration(seconds: 20));
        expect(repo.items, isEmpty);
        final temp = r.path!;
        final values = await Future.wait([
          r.save('Мой голос', AudioCategory.induction, tags: ['мой']),
          r.save('Дубль', AudioCategory.work),
        ]);
        expect(values.whereType<AudioAsset>(), hasLength(1));
        expect(repo.items, hasLength(1));
        final a = repo.items.values.single;
        expect(a.source, 'recorded');
        expect(a.section, LibrarySection.personal);
        expect(a.tags, ['мой']);
        expect(await library.fileFor(a).readAsBytes(), [1, 2, 3, 4]);
        expect(await File(temp).exists(), isFalse);
        expect(await r.save('Ещё', AudioCategory.work), isNull);
      });
      test(
        'delete only unsaved take and retains existing library files',
        () async {
          final existing = sampleAsset();
          await repo.save(existing);
          await library.fileFor(existing).writeAsBytes([9]);
          await r.start();
          final path = r.path!;
          await r.discard();
          expect(await File(path).exists(), isFalse);
          expect(await library.fileFor(existing).readAsBytes(), [9]);
          expect(repo.items, hasLength(1));
          expect(r.state, CaptureState.idle);
        },
      );
      test(
        'failed save retains finished take for retry, without managed orphan',
        () async {
          await r.start();
          await r.finish();
          repo.failSave = true;
          await r.save('A', AudioCategory.work);
          expect(repo.items, isEmpty);
          expect(await File(r.path!).exists(), isTrue);
          expect(await library.directory.list().length, 0);
          repo.failSave = false;
          await r.finish();
          await r.discard();
        },
      );
      test('busy microphone never claims capture or nonzero signal', () async {
        native.fail = true;
        await r.start();
        expect(r.state, CaptureState.error);
        expect(r.level, 0);
        expect(r.duration, Duration.zero);
        expect(repo.items, isEmpty);
      });
      test(
        'failed native pause stops microphone without claiming saved audio',
        () async {
          await r.start();
          native.failPause = true;
          await r.pause();
          expect(native.stops, 1);
          expect(r.capturing, isFalse);
          expect(r.state, CaptureState.error);
          expect(r.error, isNotNull);
          expect(repo.items, isEmpty);
          expect(await File(r.path!).exists(), isTrue);
        },
      );
      test(
        'interruption finishes capture rather than continuing hidden recording',
        () async {
          await r.start();
          await r.interrupt();
          expect(r.capturing, isFalse);
          expect(r.canSave, isTrue);
          expect(repo.items, isEmpty);
        },
      );
    },
  );
  test('frozen plan retains disabled children and repeated modules after storage round trip', () async {
    final dir = await Directory.systemTemp.createTemp('v4_snapshot');
    final audio = await SqliteLibraryRepository.open(
      '${dir.path}/db.sqlite',
      factory: databaseFactoryFfi,
    );
    final sessions = SqliteSessionRepository(audio.database);
    final library = LibraryService(
      repository: audio,
      directory: Directory('${dir.path}/audio'),
      pick: () async => null,
      probe: (_) async => null,
    );
    await library.initialize();
    final asset = sampleAsset();
    await audio.save(asset);
    await library.fileFor(asset).writeAsBytes([1]);
    final c = SessionController(
      repository: sessions,
      library: library,
      modules: ModuleCatalog(audio.database),
    );
    await c.initialize();
    final phase = await c.createPhase('work');
    final m = ModuleDefinition(
      id: 'm',
      title: 'M',
      items: [
        SessionStep(
          id: 'recipe',
          kind: StepKind.audio,
          title: asset.title,
          audioAssetId: asset.id,
          durationMs: asset.durationMs,
        ),
      ],
    );
    await c.modules.save(m);
    await c.addModule(phase, m);
    await c.addModule(phase, m);
    await c.addLoose(
      phase,
      const SessionStep(
        id: 'disabled',
        kind: StepKind.audio,
        title: 'Недоступный выключенный',
        audioAssetId: 'missing',
        enabled: false,
        durationMs: 1000,
      ),
    );
    final template = await c.saveAsTemplate('T', '');
    await c.loadTemplate(template);
    final frozen = await c.snapshotForStart();
    expect(frozen.audioMetadata[asset.id]['format'], 'wav');
    expect(frozen.plan.allSteps, hasLength(3));
    expect(frozen.plan.steps, hasLength(2));
    final run = await sessions.startRun(frozen);
    await c.clearPlan();
    expect(
      (await sessions.history()).single.snapshot.plan.allSteps,
      hasLength(3),
    );
    await c.useRun(run);
    expect(c.draft.plan.allSteps, hasLength(3));
    expect((await sessions.templates()).single.plan.allSteps, hasLength(3));
    await c.flush();
    c.dispose();
    await audio.database.close();
    await dir.delete(recursive: true);
  });
  test(
    'catalog edits do not mutate repeated instances or draft template',
    () async {
      final cat = ModuleCatalog();
      final m = ModuleDefinition(
        id: 'm',
        title: 'M',
        items: [
          const SessionStep(
            id: 'r',
            kind: StepKind.audio,
            title: 'A',
            audioAssetId: 'a',
            durationMs: 1000,
          ),
        ],
      );
      await cat.save(m);
      final first = m.instantiate('p');
      await cat.attach(
        m.id,
        const SessionStep(
          id: 'new',
          kind: StepKind.silence,
          title: 'Pause',
          durationMs: 5000,
        ),
      );
      expect(cat.entries.single.items, hasLength(2));
      expect(first.items, hasLength(1));
      expect(first.modified, isFalse);
    },
  );
}
