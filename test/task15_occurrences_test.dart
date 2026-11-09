import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/fakes.dart';

void main() {
  sqfliteFfiInit();
  test('G1 A/B source duration cache drift, edit only A, add C, persist/reopen, Undo', () async {
    final dir = await Directory.systemTemp.createTemp('task15-occurrences');
    var audio = await SqliteLibraryRepository.open(
      '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    SessionController open() => SessionController(
      repository: SqliteSessionRepository(audio.database),
      library: LibraryService(
        repository: audio,
        directory: Directory('${dir.path}/audio'),
        pick: () async => null,
        probe: (_) async => const Duration(seconds: 65),
      ),
      modules: ModuleCatalog(audio.database),
    );
    var c = open();
    try {
      await audio.save(sampleAsset(id: 'a'));
      await c.initialize();
      final source = ModuleDefinition(
        id: 'same-source',
        title: 'Модуль изменено в имени',
        items: const [
          SessionStep(
            id: 'sound',
            kind: StepKind.audio,
            title: 'Аудио',
            audioAssetId: 'a',
            durationMs: 60000,
          ),
          SessionStep(
            id: 'pause',
            kind: StepKind.silence,
            title: 'Пауза',
            durationMs: 5000,
          ),
        ],
      );
      await c.modules.save(source);
      final phase = await c.createPhase('induction');
      await c.addModule(phase, source);
      await c.addModule(phase, source);
      final editor = await c.beginEditing();
      final original = editor.draft.plan.phases!.single.children.first;
      await editor.updateChild(
        phase,
        original.copyWith(items: original.items.reversed.toList()),
      );
      // Returning from ModuleEditor calls reload: actual audio metadata changed
      // from cached 60s to measured 65s. It must not falsely mark occurrence B.
      await editor.reload();
      expect(
        editor.draft.plan.phases!.single.children.map(
          editor.moduleDiffersFromSource,
        ),
        [true, false],
      );
      await editor.addModule(phase, source);
      expect(
        editor.draft.plan.phases!.single.children.map(
          editor.moduleDiffersFromSource,
        ),
        [true, false, false],
      );
      await editor.applyEditor();
      editor.dispose();
      c.dispose();
      await audio.database.close();
      audio = await SqliteLibraryRepository.open(
        '${dir.path}/db',
        factory: databaseFactoryFfi,
      );
      c = open();
      await c.initialize();
      final children = c.draft.plan.phases!.single.children;
      expect(children.map((v) => v.id).toSet(), hasLength(3));
      expect(children.map(c.moduleDiffersFromSource), [true, false, false]);
      await c.updateChild(
        phase,
        children.first.copyWith(items: original.items),
      );
      await c.reload();
      expect(
        c.draft.plan.phases!.single.children.map(c.moduleDiffersFromSource),
        [false, false, false],
      );
      expect(c.modules.entries.single.items.map((s) => s.id), [
        'sound',
        'pause',
      ]);
      expect(
        c.draft.plan.phases!.single.children.every(
          (v) => v.title == source.title,
        ),
        true,
      );
    } finally {
      c.dispose();
      await audio.database.close();
      await dir.delete(recursive: true);
    }
  });
}
