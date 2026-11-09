import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/content_revision_store.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/execution_identity.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SqliteLibraryRepository audio;
  late SqliteSessionRepository sessions;
  late ModuleCatalog catalog;
  late LibraryService library;
  late SessionController c;
  late ModuleDefinition module;
  late SessionTemplate template;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task4-identity');
    audio = await SqliteLibraryRepository.open(
      p.join(root.path, 'db'),
      factory: databaseFactoryFfi,
    );
    sessions = SqliteSessionRepository(audio.database);
    catalog = ModuleCatalog(audio.database);
    final source = await File(p.join(root.path, 'source.wav'))
        .writeAsBytes([1, 2, 3, 4]);
    library = LibraryService(
      repository: audio,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => (name: 'Тест.wav', path: source.path),
      probe: (_) async => const Duration(seconds: 2),
    );
    await library.initialize();
    await library.save((await library.prepareImport())!);
    c = SessionController(
      repository: sessions,
      library: library,
      modules: catalog,
    );
    await c.initialize();
    module = ModuleDefinition(
      id: 'definition',
      title: 'Исходный модуль',
      items: [
        SessionStep(
          id: 'track',
          kind: StepKind.audio,
          title: 'Тестовый трек',
          audioAssetId: (await audio.list()).single.id,
          durationMs: 2000,
        ),
        const SessionStep(
          id: 'silence',
          kind: StepKind.silence,
          title: 'Пауза',
          durationMs: 3000,
        ),
      ],
    );
    await catalog.save(module);
    final phase = await c.createPhase('induction');
    await c.addModule(phase, module);
    template = await c.saveAsTemplate('План', '');
    await c.loadTemplate(template);
  });
  tearDown(() async {
    c.dispose();
    await audio.database.close();
    await root.delete(recursive: true);
  });
  ModuleDefinition updated() => ModuleDefinition(
    id: module.id,
    title: 'Новая версия',
    version: 2,
    items: [
      ...module.items,
      const SessionStep(
        id: 'extra',
        kind: StepKind.silence,
        title: 'Ещё пауза',
        durationMs: 4000,
      ),
    ],
  );
  Future<SessionRun> history() async {
    final run = await sessions.startRun(await c.snapshotForStart());
    await sessions.checkpoint(run.checkpoint(status: RunStatus.interrupted));
    await c.reload();
    return (await sessions.history()).single;
  }

  test('Task14 personal template copy has new logical ID and exact retained parent, original stays intact', () async {
    final before = template.toMap();
    final copy = await c.saveAsTemplate(
      'Моя копия',
      'Описание',
      plan: template.plan,
      parent: template,
    );
    expect(copy.id, isNot(template.id));
    expect(copy.origin, 'personal');
    expect(copy.parentRevision!.content.id, template.id);
    final parent = await ContentRevisionStore(audio.database)
        .get(copy.parentRevision!);
    expect(parent!.payload, before);
    expect(
      (await sessions.templates())
          .singleWhere((t) => t.id == template.id)
          .toMap(),
      before,
    );
    expect(
      (await sessions.templates())
          .singleWhere((t) => t.id == copy.id)
          .parentRevision!
          .digest,
      copy.parentRevision!.digest,
    );
  });
  test('definition updates linked current/template, pencil, but never frozen history or events', () async {
    final run = await history();
    final frozen = run.toMap().toString();
    final events = await sessions.events(run.id);
    await catalog.save(updated());
    await c.reload();
    expect(c.draft.plan.totalMs, 9000);
    expect(c.draft.plan.phases!.single.children.single.title, 'Новая версия');
    expect(c.templates.single.plan.totalMs, 9000);
    expect(c.draft.modified, isTrue);
    expect(c.draft.plan.phases!.single.children.single.modified, isFalse);
    expect((await sessions.history()).single.toMap().toString(), frozen);
    expect(await sessions.events(run.id), events);
  });
  test(
    'local instance edits detach; other linked templates keep refreshing',
    () async {
      final phase = c.draft.plan.phases!.single;
      final child = phase.children.single;
      await c.updateChild(
        phase.id,
        child.copyWith(title: 'Локальное имя', items: [child.items.first]),
      );
      await catalog.save(updated());
      await c.reload();
      expect(c.draft.plan.totalMs, 2000);
      expect(
        c.draft.plan.phases!.single.children.single.title,
        'Локальное имя',
      );
      expect(
        c.draft.plan.phases!.single.children.single.workingStatus,
        'Временный',
      );
      expect(c.templates.single.plan.totalMs, 9000);
    },
  );
  test('an unchanged matching template replays as normal modules and preserves entire interrupted plan', () async {
    final run = await history();
    await c.useRun(run);
    expect(c.draft.baseTemplateId, template.id);
    expect(c.draft.archiveName, isNull);
    expect(c.draft.plan.phases!.single.children.single.isModule, isTrue);
    expect(c.draft.plan.totalMs, 5000);
  });
  test('changed linked definition produces archival direct tracks/pauses with no catalog copies', () async {
    final run = await history();
    await catalog.save(updated());
    await c.reload();
    await c.useRun(run);
    expect(c.draft.archiveName, 'План');
    expect(c.draft.baseTemplateId, isNull);
    expect(
      c.draft.plan.phases!.single.children.every((c) => !c.isModule),
      isTrue,
    );
    expect(c.draft.plan.totalMs, 5000);
    expect(catalog.entries, hasLength(1));
    expect(c.templates, hasLength(1));
    final reloaded = await sessions.loadDraft();
    expect(reloaded!.archiveName, 'План');
  });
  test('deleted template and no original template both use temporary archival plan', () async {
    final run = await history();
    await sessions.deleteTemplate(template.id);
    await c.reload();
    await c.useRun(run);
    expect(c.draft.archiveName, 'План');
    expect(c.templates, isEmpty);
    expect(c.draft.plan.phases!.single.children, hasLength(2));
  });
  test(
    'metadata-only audio rename/category does not prevent exact replay',
    () async {
      final run = await history();
      final a = c.assets.single;
      await library.save(
        a.edited('Новое имя', AudioCategory.work, description: 'Описание'),
      );
      await c.reload();
      expect(await c.replayIssues(run), isEmpty);
      await c.useRun(run);
      expect(c.draft.baseTemplateId, template.id);
    },
  );
  test('missing or replaced audio blocks exact replay; rebuild requires manual replacement/removal', () async {
    final run = await history();
    final file = library.fileFor(c.assets.single);
    await file.writeAsBytes([8, 7, 6, 5]);
    expect(await c.replayIssues(run), isNotEmpty);
    await expectLater(c.useRun(run), throwsA(isA<LibraryException>()));
    await c.useRun(run, rebuild: true);
    expect(c.draft.unavailableStepIds, hasLength(1));
    await expectLater(c.snapshotForStart(), throwsA(isA<LibraryException>()));
    expect((await sessions.history()).single.snapshot.plan.totalMs, 5000);
    await file.delete();
    expect(await c.replayIssues(run), isNotEmpty);
  });
  test(
    'active snapshot stays frozen when library definition changes',
    () async {
      final active = await sessions.startRun(await c.snapshotForStart());
      await catalog.save(updated());
      expect(
        (await sessions.history()).single.snapshot.toMap(),
        active.snapshot.toMap(),
      );
      expect((await sessions.loadDraft())!.plan.totalMs, 9000);
    },
  );
  test('fingerprint is versioned, deterministic and ignores IDs and non-executable labels', () async {
    final snapshot = await c.snapshotForStart();
    expect(snapshot.executionFingerprint, startsWith('v1:'));
    final clone = SessionPlan.fromMap(snapshot.plan.toMap());
    expect(
      executionFingerprint(
        clone,
        Map.fromEntries(snapshot.audioMetadata.entries.toList().reversed),
      ),
      snapshot.executionFingerprint,
    );
    final phase = clone.phases!.single;
    final child = phase.children.single;
    final renamed = clone.copyWith(
      phases: [
        phase.copyWith(
          children: [
            child.copyWith(
              title: 'Другое имя модуля',
              items: child.items
                  .map(
                    (s) => s.copyWith(
                      id: newId(),
                      title: 'Название',
                      description: 'Описание',
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
    expect(
      executionFingerprint(renamed, snapshot.audioMetadata),
      snapshot.executionFingerprint,
    );
    final reordered = clone.copyWith(
      phases: [
        phase.copyWith(
          children: [child.copyWith(items: child.items.reversed.toList())],
        ),
      ],
    );
    expect(
      executionFingerprint(reordered, snapshot.audioMetadata),
      isNot(snapshot.executionFingerprint),
    );
  });
  test(
    'unsaved editor is not silently overwritten by linked catalog propagation',
    () async {
      final editor = await c.beginEditing();
      await editor.setText(notes: 'Несохранённый текст');
      await catalog.save(updated());
      await c.reload();
      expect(editor.draft.notes, 'Несохранённый текст');
      expect(editor.draft.plan.totalMs, 5000);
      await expectLater(editor.applyEditor(), throwsA(isA<LibraryException>()));
      expect(c.draft.plan.totalMs, 9000);
      editor.dispose();
    },
  );
}
