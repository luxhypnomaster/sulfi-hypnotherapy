import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/fakes.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SqliteLibraryRepository audio;
  late SqliteSessionRepository sessions;
  late LibraryService library;
  late SessionController controller;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sulfi_v2_');
    audio = await SqliteLibraryRepository.open(
      p.join(root.path, 'library.sqlite'),
      factory: databaseFactoryFfi,
    );
    sessions = SqliteSessionRepository(audio.database);
    library = LibraryService(
      repository: audio,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => null,
      probe: (_) async => null,
      references: sessions.references,
      resetRelatedData: sessions.reset,
    );
    await library.initialize();
    controller = SessionController(repository: sessions, library: library);
    await controller.initialize();
  });
  tearDown(() async {
    await controller.flush();
    controller.dispose();
    await audio.database.close();
    await root.delete(recursive: true);
  });
  Future<void> addSample() async {
    final a = sampleAsset();
    await audio.save(a);
    await library.fileFor(a).writeAsBytes([1, 2, 3]);
    await controller.reload();
    await controller.addAudio(a);
  }

  test('default section metadata and zero delays survive reopening independently of the template', () async {
    await addSample();
    await controller.addBlock(StepKind.silence, 10000);
    final t = await controller.saveAsTemplate('Разделы', '');
    await controller.loadTemplate(t);
    expect(controller.draft.modified, isFalse);
    await controller.reload();
    expect(
      controller.draft.plan.groups.every((g) => g.description.isNotEmpty),
      isTrue,
    );
    expect(
      controller.draft.plan.steps.every((s) => s.delayBeforeSeconds == 0),
      isTrue,
    );
    expect(controller.draft.modified, isFalse);
    final first = controller.draft.plan.steps.first.id;
    await controller.setDelay(first, 30);
    expect(
      (await sessions.templates()).single.plan.steps.first.delayBeforeSeconds,
      0,
    );
  });
  test('displaying default sections preserves legacy group fingerprints and saved plans', () async {
    final legacy = <String, dynamic>{
      'steps': <Object>[],
      'groups': [
        {'id': 'old', 'name': 'Подготовка'},
      ],
      'exitStepId': null,
    };
    final plan = SessionPlan.fromMap(legacy);
    expect(plan.fingerprint, jsonEncode(legacy));
    final names = plan.availableGroups.map((g) => g.name);
    expect(names.where((name) => name == 'Подготовка'), hasLength(1));
    expect(plan.availableGroups.first.description, isNotEmpty);
    expect(plan.fingerprint, jsonEncode(legacy));
    expect(plan.groups.single.description, isEmpty);
    expect(plan.availableGroups, hasLength(defaultStageGroups.length));
  });
  test(
    'new audio chooses its stage by category without sorting playback order',
    () async {
      final categories = [
        AudioCategory.exit,
        AudioCategory.preparation,
        AudioCategory.induction,
        AudioCategory.work,
        AudioCategory.integration,
        AudioCategory.deepener,
      ];
      for (final category in categories) {
        final a = sampleAsset(id: category.name)
            .edited(category.label, category);
        await audio.save(a);
        await controller.addAudio(a);
      }
      await controller.reload();
      expect(
        controller.draft.plan.steps.map((s) => s.title),
        categories.map((c) => c.label),
      );
      expect(
        controller.draft.plan.steps.map(
          (s) => controller.draft.plan.groupName(s.groupId),
        ),
        categories.map((c) => c.label),
      );
      expect(
        controller.draft.plan.steps.every((s) => s.delayBeforeSeconds == 0),
        isTrue,
      );
      expect(controller.draft.plan.groups, hasLength(6));
    },
  );
  test(
    'draft autosave does not reserve session numbers or create history',
    () async {
      await addSample();
      await controller.setText(topic: 'Тема', notes: 'Моя заметка');
      await controller.setDelay(controller.draft.plan.steps.single.id, 390);
      final persisted = (await sessions.loadDraft())!;
      expect(persisted.plan.steps.single.delayBeforeSeconds, 390);
      expect(persisted.topicText, 'Тема');
      expect(persisted.notes, 'Моя заметка');
      expect(await sessions.history(), isEmpty);
      expect(await sessions.nextNumber(), 1);
    },
  );
  test('new blocks start at zero delay including first and duplicate audio gets distinct IDs', () async {
    await addSample();
    await controller.addAudio(sampleAsset());
    expect(
      controller.draft.plan.steps.every((s) => s.delayBeforeSeconds == 0),
      isTrue,
    );
    expect(controller.draft.plan.steps.map((s) => s.id).toSet(), hasLength(2));
    final first = controller.draft.plan.steps.first.id;
    await controller.setDelay(first, 30);
    expect(controller.draft.plan.steps.last.delayBeforeSeconds, 0);
  });
  test('editing a draft never rewrites source template', () async {
    await addSample();
    final t = await controller.saveAsTemplate('Образец', 'Описание');
    await controller.loadTemplate(t);
    expect(controller.draft.modified, isFalse);
    await controller.setDelay(controller.draft.plan.steps.single.id, 390);
    expect(controller.draft.modified, isTrue);
    expect(
      (await sessions.templates()).single.plan.steps.single.delayBeforeSeconds,
      0,
    );
    expect(controller.draft.plan.totalMs, 455000);
    await controller.restore();
    expect(controller.draft.modified, isFalse);
    expect(controller.draft.plan.totalMs, 65000);
  });
  test('restore and template selection retain topic and notes', () async {
    await addSample();
    final t = await controller.saveAsTemplate('Образец', '');
    await controller.setText(topic: 'Границы', notes: 'Личная заметка');
    await controller.loadTemplate(t);
    await controller.restore();
    expect(controller.draft.topicText, 'Границы');
    expect(controller.draft.notes, 'Личная заметка');
  });
  test(
    'queued rapid changes keep newest delay, topic and order after reopening',
    () async {
      await addSample();
      final id = controller.draft.plan.steps.single.id;
      await Future.wait([
        controller.setDelay(id, 5),
        controller.setDelay(id, 10),
        controller.setText(topic: 'Первая'),
        controller.setText(topic: 'Последняя'),
      ]);
      await controller.duplicate(id);
      await controller.reorder(0, 2);
      final expected = controller.draft.toMap();
      await audio.database.close();
      audio = await SqliteLibraryRepository.open(
        p.join(root.path, 'library.sqlite'),
        factory: databaseFactoryFfi,
      );
      sessions = SqliteSessionRepository(audio.database);
      expect((await sessions.loadDraft())!.toMap(), expected);
    },
  );
  test(
    'reorder moves the delay with block and duplication preserves it',
    () async {
      await addSample();
      final id = controller.draft.plan.steps.single.id;
      await controller.setDelay(id, 30);
      await controller.duplicate(id);
      final copy = controller.draft.plan.steps.last.id;
      expect(copy, isNot(id));
      await controller.setDelay(copy, 60);
      await controller.reorder(0, 2);
      expect(controller.draft.plan.steps.first.id, copy);
      expect(controller.draft.plan.steps.last.delayBeforeSeconds, 30);
      expect(controller.draft.plan.totalMs, 220000);
    },
  );
  test(
    'saving as template creates new object without selecting or overwriting it',
    () async {
      await addSample();
      final a = await controller.saveAsTemplate('Первый', '');
      await controller.loadTemplate(a);
      await controller.setDelay(controller.draft.plan.steps.single.id, 5);
      final b = await controller.saveAsTemplate('Второй', '');
      expect(b.id, isNot(a.id));
      expect(await sessions.templates(), hasLength(2));
      expect(controller.draft.baseTemplateId, a.id);
      expect(controller.draft.modified, isTrue);
    },
  );
  test(
    'deleting source template does not delete the independent draft',
    () async {
      await addSample();
      final t = await controller.saveAsTemplate('Источник', '');
      await controller.loadTemplate(t);
      await sessions.deleteTemplate(t.id);
      await controller.reload();
      expect(controller.draft.plan.steps, hasLength(1));
      expect(controller.baseTemplate, isNull);
    },
  );
  test('numbers are assigned atomically on start and never reused after history deletion', () async {
    await addSample();
    final snapshot = await controller.snapshotForStart();
    final first = await sessions.startRun(snapshot);
    await expectLater(sessions.startRun(snapshot), throwsStateError);
    await sessions.checkpoint(
      first.checkpoint(
        status: RunStatus.interrupted,
        endedAt: DateTime.now().toUtc(),
      ),
      event: 'interrupted',
    );
    await sessions.deleteRun(first.id);
    final second = await sessions.startRun(snapshot);
    expect(second.displayNumber, 2);
    expect(await sessions.nextNumber(), 3);
  });
  test('history snapshot stays frozen after draft edits, audio rename and hostile checkpoint', () async {
    await addSample();
    final run = await sessions.startRun(await controller.snapshotForStart());
    final id = controller.draft.plan.steps.single.id;
    await controller.setDelay(id, 390);
    await audio.save(
      sampleAsset().edited('Переименовано', sampleAsset().category),
    );
    final altered = SessionRun(
      id: run.id,
      displayNumber: run.displayNumber,
      name: 'Не должно попасть',
      snapshot: controller.draft,
      startedAt: run.startedAt,
      status: RunStatus.completed,
    );
    await sessions.checkpoint(altered, event: 'completed');
    final stored = (await sessions.history()).single;
    expect(stored.snapshot.plan.steps.single.delayBeforeSeconds, 0);
    expect(stored.snapshot.plan.steps.single.title, 'Тестовая запись');
    expect(stored.name, run.name);
    expect(stored.status, RunStatus.completed);
    await sessions.checkpoint(run, event: 'late');
    expect((await sessions.history()).single.status, RunStatus.completed);
  });
  test('renaming and notes do not alter the execution snapshot', () async {
    await addSample();
    final run = await sessions.startRun(await controller.snapshotForStart());
    await sessions.editRun(
      run.id,
      name: 'Моё название',
      notes: 'Новая заметка',
    );
    await sessions.checkpoint(
      run.checkpoint(status: RunStatus.completed),
      event: 'completed',
    );
    final stored = (await sessions.history()).single;
    expect(stored.name, 'Моё название');
    expect(stored.notes, 'Новая заметка');
    expect(stored.snapshot.notes, '');
  });
  test('unfinished run is interrupted on next launch with its last checkpoint retained', () async {
    await addSample();
    final run = await sessions.startRun(await controller.snapshotForStart());
    await sessions.checkpoint(
      run.checkpoint(phase: 'audio', playheadMs: 12345, elapsedMs: 14000),
      event: 'paused',
    );
    final before = (await sessions.history()).single;
    await sessions.interruptUnfinished();
    final stored = (await sessions.history()).single;
    expect(stored.status, RunStatus.interrupted);
    expect(stored.playheadMs, 12345);
    expect(stored.endEstimated, isTrue);
    expect(stored.endedAt, before.lastCheckpointAt);
    expect(
      (await sessions.events(run.id)).last['eventType'],
      'process_interrupted',
    );
  });
  test(
    'referenced asset deletion is blocked without losing audio bytes',
    () async {
      await addSample();
      await controller.saveAsTemplate('Источник', '');
      await expectLater(
        library.delete(sampleAsset()),
        throwsA(isA<LibraryException>()),
      );
      expect(await library.fileFor(sampleAsset()).exists(), isTrue);
      expect(await audio.list(), hasLength(1));
    },
  );
  test('reset clears all related entities and private audio but not external sources', () async {
    await addSample();
    await controller.saveAsTemplate('Источник', '');
    await sessions.startRun(await controller.snapshotForStart());
    final external = await File(p.join(root.path, 'external.wav'))
        .writeAsBytes([0]);
    await library.reset();
    expect(await sessions.history(), isEmpty);
    expect(await sessions.templates(), isEmpty);
    expect(await sessions.loadDraft(), isNull);
    expect(await audio.list(), isEmpty);
    expect(await external.exists(), isTrue);
  });
  test('missing audio and unsupported mic blocks cannot start a run', () async {
    await addSample();
    await library.fileFor(sampleAsset()).delete();
    await expectLater(
      controller.snapshotForStart(),
      throwsA(isA<LibraryException>()),
    );
    await controller.clearPlan();
    await controller.addBlock(StepKind.voiceRecording, 60000);
    await expectLater(
      controller.snapshotForStart(),
      throwsA(isA<LibraryException>()),
    );
    expect(await sessions.history(), isEmpty);
  });
  test(
    'negative and non-five-second delays are rejected without changing draft',
    () async {
      await addSample();
      final id = controller.draft.plan.steps.single.id;
      await expectLater(
        controller.setDelay(id, -5),
        throwsA(isA<LibraryException>()),
      );
      await expectLater(
        controller.setDelay(id, 7),
        throwsA(isA<LibraryException>()),
      );
      expect(
        (await sessions.loadDraft())!.plan.steps.single.delayBeforeSeconds,
        0,
      );
    },
  );
  test('immutable snapshot lists cannot be edited through aliases', () async {
    await addSample();
    final run = await sessions.startRun(await controller.snapshotForStart());
    expect(() => run.snapshot.plan.steps.clear(), throwsUnsupportedError);
    expect(
      () => run.snapshot.plan.groups.add(
        const StageGroup(id: 'bad', name: 'bad'),
      ),
      throwsUnsupportedError,
    );
  });
  test(
    'v1 to v2 migration preserves original metadata, IDs and private audio',
    () async {
      final path = p.join(root.path, 'old.sqlite');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) => db.execute(
            '''CREATE TABLE audio_assets (
      id TEXT PRIMARY KEY,title TEXT NOT NULL,filePath TEXT NOT NULL UNIQUE,durationMs INTEGER NOT NULL,
      format TEXT NOT NULL,createdAt TEXT NOT NULL,category TEXT NOT NULL,fileSizeBytes INTEGER NOT NULL)''',
          ),
        ),
      );
      await old.insert('audio_assets', {
        'id': 'original',
        'title': 'Моя запись',
        'filePath': 'asset_original.wav',
        'durationMs': 12000,
        'format': 'wav',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'category': 'induction',
        'fileSizeBytes': 3,
      });
      final file = await File(p.join(root.path, 'asset_original.wav'))
          .writeAsBytes([3, 2, 1]);
      await old.close();
      final migrated = await SqliteLibraryRepository.open(
        path,
        factory: databaseFactoryFfi,
      );
      final a = (await migrated.list()).single;
      expect(a.id, 'original');
      expect(a.title, 'Моя запись');
      expect(a.category.label, 'Погружение');
      expect(a.description, '');
      expect(await file.readAsBytes(), [3, 2, 1]);
      expect(
        await SqliteSessionRepository(migrated.database).history(),
        isEmpty,
      );
      await migrated.database.close();
    },
  );
}
