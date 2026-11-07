import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/history_facts.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);
  final a = SessionStep(
    id: 'a',
    kind: StepKind.audio,
    title: 'Первый',
    audioAssetId: 'audio',
    durationMs: 12000,
  );
  final b = SessionStep(
    id: 'b',
    kind: StepKind.silence,
    title: 'Пауза',
    durationMs: 30000,
  );
  final off = SessionStep(
    id: 'off',
    kind: StepKind.audio,
    title: 'Выключенный',
    enabled: false,
  );
  SessionRun run({
    List<String> done = const [],
    List<String> skipped = const [],
    RunStatus status = RunStatus.interrupted,
  }) => SessionRun(
    id: 'r',
    displayNumber: 1,
    name: 'История',
    snapshot: CurrentSessionDraft(
      plan: SessionPlan(steps: [a, b, off]),
      updatedAt: now,
    ),
    startedAt: now,
    status: status,
    completedStepIds: done,
    skippedStepIds: skipped,
  );
  test(
    'completion uses IDs and explicit events; seek near end is not a skip',
    () {
      final facts = HistoryFacts(run(done: ['a']), [
        {'stepIndex': 0, 'eventType': 'seek', 'playheadMs': 11900},
        {'stepIndex': 1, 'eventType': 'block_completed'},
      ]);
      expect(facts.step(a), StepFact.completed);
      expect(facts.step(b), StepFact.completed);
      expect(facts.step(off), StepFact.disabled);
      expect(facts.completed, 2);
      expect(facts.group([a, b]), StepFact.completed);
      expect(
        HistoryFacts(run(), [
          {'stepIndex': 0, 'eventType': 'seek', 'playheadMs': 11999},
        ]).step(a),
        StepFact.unknown,
      );
    },
  );
  test(
    'interrupted whole run never paints future or unknown steps red/green',
    () {
      final facts = HistoryFacts(run(), [
        {'stepIndex': 0, 'eventType': 'block_started'},
        {'stepIndex': 0, 'eventType': 'audio_error'},
      ]);
      expect(facts.step(a), StepFact.interrupted);
      expect(facts.step(b), StepFact.unknown);
      expect(facts.group([a, b]), StepFact.interrupted);
      expect(
        HistoryFacts(run(status: RunStatus.completed), []).step(a),
        StepFact.unknown,
      );
      expect(
        HistoryFacts(run(done: ['a']), []).group([a, b]),
        StepFact.unknown,
      );
    },
  );
  test('skip requires a stored ID/event; started and absent evidence stay distinct', () {
    expect(HistoryFacts(run(skipped: ['a']), []).step(a), StepFact.skipped);
    expect(
      HistoryFacts(run(), [
        {'stepIndex': 1, 'eventType': 'block_skipped'},
      ]).step(b),
      StepFact.skipped,
    );
    expect(
      HistoryFacts(run(), [
        {'stepIndex': 0, 'eventType': 'block_started'},
      ]).step(a),
      StepFact.started,
    );
  });
  test('terminal run and pending detail ID commit together, survive restart, acknowledge without duplicates', () async {
    sqfliteFfiInit();
    final root = await Directory.systemTemp.createTemp('task5-history');
    var db = await openAppDatabase(
      '${root.path}/db',
      factory: databaseFactoryFfi,
    );
    var repo = SqliteSessionRepository(db);
    final started = await repo.startRun(run().snapshot);
    await repo.checkpoint(
      started.checkpoint(
        status: RunStatus.completed,
        endedAt: now,
        completedStepIds: ['a', 'b'],
      ),
      event: 'completed',
    );
    expect(await repo.pendingHistory(), started.id);
    await db.close();
    db = await openAppDatabase('${root.path}/db', factory: databaseFactoryFfi);
    repo = SqliteSessionRepository(db);
    expect(await repo.pendingHistory(), started.id);
    expect(await repo.history(), hasLength(1));
    final before = (await repo.history()).single.snapshot.toMap();
    await repo.events(started.id);
    await repo.history();
    await repo.editRun(started.id, notes: 'Личная заметка');
    expect((await repo.history()).single.snapshot.toMap(), before);
    expect((await repo.history()).single.notes, 'Личная заметка');
    await repo.acknowledgeHistory('other');
    expect(await repo.pendingHistory(), started.id);
    await repo.acknowledgeHistory(started.id);
    expect(await repo.pendingHistory(), isNull);
    expect(await repo.history(), hasLength(1));
    await db.close();
    await root.delete(recursive: true);
  });
  test('editor restoration is isolated; cancel preserves current; save as NEW never mutates historical template', () async {
    final root = await Directory.systemTemp.createTemp('task5-editor');
    final repo = MemorySessionRepository();
    final c = SessionController(
      repository: repo,
      library: LibraryService(
        repository: MemoryRepository(),
        directory: root,
        pick: () async => null,
        probe: (_) async => null,
      ),
    );
    await c.initialize();
    final historical = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'p',
          typeId: 'work',
          title: 'Сохранённая фаза',
          children: [
            PhaseChild(
              id: 'm',
              definitionId: 'deleted',
              title: 'Старый модуль',
              items: [b],
            ),
          ],
        ),
      ],
    );
    final template = await c.saveAsTemplate(
      'Оригинал',
      'Историческое описание',
      plan: historical,
    );
    await c.loadTemplate(template);
    final snapshot = await c.snapshotForStart();
    expect(snapshot.baseTemplateDescription, 'Историческое описание');
    final source = await repo.startRun(snapshot);
    await repo.checkpoint(source.checkpoint(status: RunStatus.interrupted));
    await c.clearPlan();
    final before = c.draft.toMap();
    final editor = await c.beginEditing();
    await editor.useRun(source, rebuild: true);
    expect(editor.draft.plan.phases!.single.title, 'Сохранённая фаза');
    expect(
      editor.draft.plan.phases!.single.children.every((c) => !c.isModule),
      isTrue,
    );
    expect(c.draft.toMap(), before);
    expect(c.modules.entries, isEmpty);
    final fresh = await editor.saveAsTemplate('Новая копия', 'Из архива');
    expect(fresh.id, isNot(template.id));
    expect(
      (await repo.templates()).firstWhere((t) => t.id == template.id).toMap(),
      template.toMap(),
    );
    expect(
      (await repo.history()).single.snapshot.toMap(),
      source.snapshot.toMap(),
    );
    editor.dispose();
    c.dispose();
    await root.delete(recursive: true);
  });
}
