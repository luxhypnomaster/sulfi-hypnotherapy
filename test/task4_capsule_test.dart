import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late LibraryService original, target;
  late CapsuleService source, destination;
  late SqliteLibraryRepository a, b;
  late File zip;
  final now = DateTime.utc(2026, 11, 7);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task4-capsule-');
    Future<(SqliteLibraryRepository, LibraryService, CapsuleService)> open(
      String name,
    ) async {
      final dir = Directory(p.join(root.path, name));
      await dir.create();
      final repo = await SqliteLibraryRepository.open(
        p.join(dir.path, 'db'),
        factory: databaseFactoryFfi,
      );
      final library = LibraryService(
        repository: repo,
        directory: Directory(p.join(dir.path, 'audio')),
        pick: () async =>
            (name: 'test.wav', path: p.join(root.path, 'test.wav')),
        probe: (_) async => const Duration(seconds: 2),
      );
      await library.initialize();
      return (
        repo,
        library,
        CapsuleService(
          database: repo.database,
          library: library,
          diaryDirectory: Directory(p.join(dir.path, 'diary')),
          workspace: Directory(p.join(dir.path, 'cache')),
        ),
      );
    }

    (a, original, source) = await open('source');
    (b, target, destination) = await open('target');
    await File(p.join(root.path, 'test.wav'))
        .writeAsBytes([82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69]);
    for (var i = 0; i < 2; i++) {
      await original.save((await original.prepareImport())!);
    }
    final assets = await a.list();
    final module = ModuleDefinition(
      id: 'module',
      title: 'Тестовый модуль',
      items: [
        SessionStep(
          id: 'sound',
          kind: StepKind.audio,
          title: 'Тест',
          audioAssetId: assets.first.id,
          durationMs: 2000,
        ),
        const SessionStep(
          id: 'pause',
          kind: StepKind.silence,
          title: 'Пауза',
          durationMs: 3000,
        ),
      ],
    );
    await ModuleCatalog(a.database).save(module);
    final plan = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'phase',
          typeId: 'induction',
          title: 'Погружение',
          children: [module.instantiate('phase')],
        ),
      ],
    );
    final sessions = SqliteSessionRepository(a.database);
    final template = SessionTemplate(
      id: 'template',
      name: 'Тестовый шаблон',
      plan: plan,
      createdAt: now,
      updatedAt: now,
    );
    await sessions.saveTemplate(template);
    final draft = CurrentSessionDraft.fromTemplate(template);
    await sessions.saveDraft(draft);
    final run = await sessions.startRun(draft);
    await sessions.checkpoint(
      run.checkpoint(status: RunStatus.interrupted, endedAt: now),
      event: 'interrupted',
    );
    await source.diaryDirectory.create();
    final media = await File(p.join(source.diaryDirectory.path, 'sound.wav'))
        .writeAsBytes([1, 2, 3, 4]);
    await DiaryAuthorRepository(a.database).save(
      DiaryEntry(
        id: 'diary',
        message: 'Тест',
        createdAt: now,
        updatedAt: now,
        blocks: [
          DiaryBlock(
            id: 'block',
            type: DiaryBlockType.audio,
            durationMs: 1000,
            media: DiaryMedia(
              assetId: 'diary-audio',
              mime: 'audio/wav',
              bytes: 4,
              localPath: media.path,
            ),
          ),
        ],
      ),
    );
    zip = await source.export();
  });
  tearDown(() async {
    await a.database.close();
    await b.database.close();
    await root.delete(recursive: true);
  });

  test('full offline capsule restores IDs, bytes, plans, history, diary and survives restart', () async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(
      archive.files.where((f) => f.isFile && f.name.startsWith('blobs/')),
      hasLength(2),
    ); // deduplicated audio + diary
    expect(
      utf8.decode(archive.findFile('manifest.json')!.content),
      isNot(contains(root.path)),
    );
    final preview = await destination.inspect(zip);
    expect(preview.conflicts, isEmpty);
    await destination.restore(preview);
    await preview.close();
    expect(
      (await b.list()).map((x) => x.id).toSet(),
      (await a.list()).map((x) => x.id).toSet(),
    );
    for (final asset in await b.list()) {
      expect(
        await target.fileFor(asset).readAsBytes(),
        await original.fileFor((await a.list()).first).readAsBytes(),
      );
    }
    final sessions = SqliteSessionRepository(b.database);
    expect(
      (await sessions.loadDraft())!.plan.fingerprint,
      (await SqliteSessionRepository(a.database).loadDraft())!.plan.fingerprint,
    );
    expect((await sessions.templates()).single.id, 'template');
    expect(
      (await sessions.history()).single.snapshot.plan.fingerprint,
      (await sessions.loadDraft())!.plan.fingerprint,
    );
    expect(
      await sessions.events((await sessions.history()).single.id),
      hasLength(2),
    );
    final diary = (await DiaryAuthorRepository(b.database).entries()).single;
    expect(await File(diary.blocks.single.media!.localPath!).readAsBytes(), [
      1,
      2,
      3,
      4,
    ]);
    final dbPath = b.database.path;
    await b.database.close();
    b = await SqliteLibraryRepository.open(dbPath, factory: databaseFactoryFfi);
    expect(await b.list(), hasLength(2));
    expect(
      (await SqliteSessionRepository(
        b.database,
      ).history()).single.snapshot.plan.totalMs,
      5000,
    );
  });
  test('repeated import is idempotent and keeps event counts', () async {
    var preview = await destination.inspect(zip);
    await destination.restore(preview);
    await preview.close();
    preview = await destination.inspect(zip);
    expect(preview.alreadyImported, isTrue);
    await destination.restore(preview);
    await preview.close();
    expect(await b.list(), hasLength(2));
    expect(await b.database.query('run_events'), hasLength(2));
  });
  test(
    'same mechanism selectively exports module and its only dependency',
    () async {
      final selective = await source.export(moduleId: 'module');
      final preview = await destination.inspect(selective);
      expect(preview.counts['audio_assets'], 1);
      expect(preview.counts['session_runs'], 0);
      await destination.restore(preview);
      await preview.close();
      final catalog = ModuleCatalog(b.database);
      await catalog.load();
      expect(catalog.entries.single.items, hasLength(2));
      expect(catalog.entries.single.items.last.durationMs, 3000);
      expect(await b.list(), hasLength(1));
    },
  );
  test(
    'injected commit failure rolls back every row and staged media',
    () async {
      final preview = await destination.inspect(zip);
      await expectLater(
        destination.restore(
          preview,
          beforeCommit: () async =>
              throw const FileSystemException('test disk failure'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await b.list(), isEmpty);
      expect(await b.database.query('session_runs'), isEmpty);
      expect(await target.directory.list().toList(), isEmpty);
      expect(await destination.diaryDirectory.list().toList(), isEmpty);
      await destination.restore(preview);
      await preview.close();
      expect(await b.list(), hasLength(2));
    },
  );
  test('conflicts preview before mutation, cancel and keep-existing preserve local data', () async {
    final asset = (await a.list()).first;
    await target.directory.create(recursive: true);
    await original.fileFor(asset).copy(target.fileFor(asset).path);
    await b.save(asset.edited('Местное название', asset.category));
    final preview = await destination.inspect(zip);
    expect(preview.conflicts, hasLength(1));
    await expectLater(destination.restore(preview), throwsFormatException);
    expect((await b.list()).single.title, 'Местное название');
    await destination.restore(
      preview,
      choice: CapsuleConflictChoice.keepExisting,
    );
    await preview.close();
    expect(
      (await b.list()).firstWhere((a) => a.id == asset.id).title,
      'Местное название',
    );
  });
  test(
    'database change after preview aborts without losing the new data',
    () async {
      final preview = await destination.inspect(zip);
      await b.database.insert('app_counters', {'name': 'session', 'value': 17});
      await expectLater(destination.restore(preview), throwsFormatException);
      expect(await b.list(), isEmpty);
      expect((await b.database.query('app_counters')).single['value'], 17);
      await preview.close();
    },
  );
  for (final mode in ['checksum', 'schema', 'dependency', 'traversal']) {
    test('rejects $mode without touching destination', () async {
      final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final manifest = jsonDecode(
        utf8.decode(decoded.findFile('manifest.json')!.content),
      ) as Map<String, dynamic>;
      if (mode == 'schema') manifest['schema'] = 999;
      if (mode == 'dependency') manifest['records']['audio_assets'] = [];
      manifest.remove('id');
      manifest['id'] = CapsuleService.digest(manifest);
      final archive = Archive();
      for (final f in decoded) {
        archive.addFile(
          ArchiveFile(
            f.name,
            f.size,
            f.name == 'manifest.json'
                ? utf8.encode(jsonEncode(manifest))
                : mode == 'checksum' && f.name.startsWith('blobs/')
                ? List<int>.filled(f.size, 9)
                : f.content,
          ),
        );
      }
      if (mode == 'traversal') {
        archive.addFile(ArchiveFile('../outside', 1, [1]));
      }
      final corrupt = await File(p.join(root.path, 'corrupt.zip'))
          .writeAsBytes(ZipEncoder().encode(archive));
      await expectLater(destination.inspect(corrupt), throwsFormatException);
      expect(await b.list(), isEmpty);
      expect(await b.database.query('module_definitions'), isEmpty);
    });
  }
  test('free-space preflight blocks before extracting files', () async {
    final limited = CapsuleService(
      database: b.database,
      library: target,
      diaryDirectory: destination.diaryDirectory,
      workspace: destination.workspace,
      availableBytes: () async => 0,
    );
    await expectLater(limited.inspect(zip), throwsFormatException);
    expect(await b.list(), isEmpty);
  });
}
