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
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/data/content_revision_store.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/services/history_attachments.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

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
    final image = await File(p.join(source.diaryDirectory.path, 'image.png'))
        .writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
          ),
        );
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
          DiaryBlock(
            id: 'image',
            type: DiaryBlockType.image,
            width: 1,
            height: 1,
            media: DiaryMedia(
              assetId: 'diary-image',
              mime: 'image/png',
              bytes: await image.length(),
              localPath: image.path,
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

  for (final scope in ['track', 'module', 'template']) {
    test(
      'Task14 selective $scope roundtrip and idempotence without private records',
      () async {
        final asset = (await a.list()).first;
        final file = await source.export(
          trackId: scope == 'track' ? asset.id : null,
          moduleId: scope == 'module' ? 'module' : null,
          templateId: scope == 'template' ? 'template' : null,
        );
        final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
        final manifest = jsonDecode(
          utf8.decode(archive.findFile('manifest.json')!.content),
        );
        expect(manifest['scope'], scope);
        expect(manifest['records']['audio_assets'], hasLength(1));
        for (final table in [
          'session_runs',
          'run_events',
          'diary_author',
          'diary_public',
          'history_attachments',
          'current_draft',
        ]) {
          expect(manifest['records'][table], isEmpty);
        }
        expect(
          archive.files.where((f) => f.isFile && f.name.startsWith('blobs/')),
          hasLength(1),
        );
        final preview = await destination.inspect(file);
        await destination.restore(preview);
        await preview.close();
        expect(await b.list(), hasLength(1));
        if (scope == 'module' || scope == 'template') {
          final modules = ModuleCatalog(b.database);
          await modules.load();
          expect(modules.entries.single.items.map((s) => s.kind), [
            StepKind.audio,
            StepKind.silence,
          ]);
        }
        if (scope == 'template') {
          expect(
            (await SqliteSessionRepository(
              b.database,
            ).templates()).single.plan.totalMs,
            5000,
          );
        }
        final again = await destination.inspect(file);
        expect(again.alreadyImported, true);
        await destination.restore(again);
        await again.close();
        expect(await b.list(), hasLength(1));
        expect(await target.directory.list().length, 1);
      },
    );
  }
  test(
    'Task14 selective scope rejects absent metadata and absent bytes',
    () async {
      await expectLater(
        source.export(trackId: 'missing'),
        throwsFormatException,
      );
      await expectLater(
        source.export(moduleId: 'missing'),
        throwsFormatException,
      );
      await expectLater(
        source.export(templateId: 'missing'),
        throwsFormatException,
      );
      await original.fileFor((await a.list()).first).delete();
      await expectLater(
        source.export(templateId: 'template'),
        throwsFormatException,
      );
      expect(await b.list(), isEmpty);
    },
  );
  test('Task14 offline catalog indexes before install, selects exact template, omits private rows and retries idempotently', () async {
    final local = await LocalCatalogSource.open(destination, zip);
    expect(
      local.revisions.where((r) => r.key.content.type == ContentType.track),
      hasLength(2),
    );
    expect(await b.list(), isEmpty);
    final template = local.revisions.singleWhere(
      (r) => r.key.content.type == ContentType.template,
    );
    final plan = await local.plan(template.key);
    expect(plan.closure.revisions, hasLength(3));
    expect(plan.newBytes, 12);
    final states = <ContentInstallState>[];
    await local.install(plan, onState: states.add);
    expect(states, [
      ContentInstallState.planned,
      ContentInstallState.staging,
      ContentInstallState.verifying,
      ContentInstallState.committing,
      ContentInstallState.installed,
    ]);
    expect(await b.list(), hasLength(1));
    expect(await b.database.query('session_runs'), isEmpty);
    expect(await b.database.query('diary_author'), isEmpty);
    expect(await local.installed(template), true);
    expect((await local.plan(template.key)).newBytes, 0);
    await local.install(await local.plan(template.key));
    expect(await b.list(), hasLength(1));
    expect(await target.directory.list().length, 1);
    final revision = await ContentRevisionStore(b.database).get(template.key);
    expect(revision!.key.digest, template.key.digest);
    await local.close();
  });
  test('Task14 catalog cancel, commit failure, retry and corrupt staged source leave no partial content', () async {
    final local = await LocalCatalogSource.open(destination, zip);
    final root = local.revisions.singleWhere(
      (r) => r.key.content.type == ContentType.template,
    );
    final plan = await local.plan(root.key);
    var cancelled = false;
    await expectLater(
      local.install(
        plan,
        cancelled: () => cancelled,
        onState: (s) {
          if (s == ContentInstallState.verifying) cancelled = true;
        },
      ),
      throwsFormatException,
    );
    expect(await b.list(), isEmpty);
    await expectLater(
      local.install(plan, beforeCommit: () async => throw StateError('fault')),
      throwsStateError,
    );
    expect(await b.list(), isEmpty);
    expect(await b.database.query('session_templates'), isEmpty);
    expect(await target.directory.list().length, 0);
    final hash = root.dependencies.firstWhere(
      (k) => k.content.type == ContentType.track,
    );
    final track = local.revisions.singleWhere((r) => r.key.token == hash.token);
    final file = File(
      p.join(local.preview.staging.path, track.payload['contentHash']),
    );
    final original = await file.readAsBytes();
    await file.writeAsBytes([9, 8, 7]);
    await expectLater(local.install(plan), throwsFormatException);
    expect(await b.list(), isEmpty);
    await file.writeAsBytes(original);
    await local.install(plan);
    expect(await local.installed(root), true);
    await local.close();
  });
  test('Task14 schema8 populated upgrade retains every table and media, then pins old definition after v2', () async {
    final historyMedia = DiaryMediaStore(
      Directory(p.join(source.diaryDirectory.parent.path, 'history_media')),
      pick: (_) async => null,
      probe: original.probe,
    );
    final attachment = await historyMedia.importFile(DiaryBlockType.audio, (
      name: 'note.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    final run = (await SqliteSessionRepository(a.database).history()).single;
    await HistoryAttachments(
      a.database,
      historyMedia,
    ).attach(run.id, attachment);
    final populatedZip = await source.export();
    final preview = await destination.inspect(populatedZip);
    await destination.restore(preview);
    await preview.close();
    await b.database.insert('app_settings', {
      'name': 'owner-setting',
      'value': 'kept',
    });
    await b.database.insert('diary_sync', {'id': 1, 'revision': 'kept'});
    final tables = [
      ...CapsuleService.tables.where((t) => t != 'content_revisions'),
      'app_settings',
      'diary_sync',
    ];
    final before = {for (final t in tables) t: await b.database.query(t)};
    final bytes = {
      for (final a in await target.repository.list())
        a.filePath: await target.fileFor(a).readAsBytes(),
    };
    expect(await b.database.query('history_attachments'), hasLength(1));
    final mediaBytes = <String, List<int>>{};
    for (final dir in [
      destination.diaryDirectory,
      Directory(
        p.join(destination.diaryDirectory.parent.path, 'history_media'),
      ),
    ]) {
      await for (final f in dir.list(recursive: true)) {
        if (f is File) mediaBytes[f.path] = await f.readAsBytes();
      }
    }
    final path = b.database.path;
    await b.database.execute('DROP TABLE content_revisions');
    await b.database.execute('PRAGMA user_version=8');
    await b.database.close();
    final reopened = await openAppDatabase(path, factory: databaseFactoryFfi);
    try {
      expect(await reopened.getVersion(), 9);
      for (final t in tables) {
        expect(await reopened.query(t), before[t], reason: t);
      }
      for (final e in bytes.entries) {
        expect(
          await File(p.join(target.directory.path, e.key)).readAsBytes(),
          e.value,
        );
      }
      for (final e in mediaBytes.entries) {
        expect(await File(e.key).readAsBytes(), e.value);
      }
      final store = ContentRevisionStore(reopened);
      final old = (await store.list()).singleWhere(
        (r) => r.key.content.type == ContentType.module,
      );
      final oldRun = await reopened.query('session_runs');
      final modules = ModuleCatalog(reopened);
      await modules.load();
      final m = modules.entries.single;
      await modules.save(
        ModuleDefinition(id: m.id, title: 'v2', version: 2, items: m.items),
      );
      expect((await store.get(old.key))!.key.digest, old.key.digest);
      expect(modules.source(m.id, 1)!.title, m.title);
      expect(await reopened.query('session_runs'), oldRun);
      expect(
        (await store.list()).every((r) => r.parent == null),
        true,
      ); // No fabricated legacy parent.
    } finally {
      await reopened.close();
    }
  });
  test('Task14 installer checks storage before writes, reconciles abandoned files, and reopens after restart', () async {
    var free = 1 << 30;
    final bounded = CapsuleService(
      database: b.database,
      library: target,
      diaryDirectory: destination.diaryDirectory,
      workspace: destination.workspace,
      availableBytes: () async => free,
    );
    var local = await LocalCatalogSource.open(bounded, zip);
    final r = local.revisions.singleWhere(
      (r) => r.key.content.type == ContentType.template,
    );
    final plan = await local.plan(r.key);
    free = 0;
    await expectLater(local.install(plan), throwsFormatException);
    expect(await b.list(), isEmpty);
    free = 1 << 30;
    await local.install(plan);
    await local.close();
    await File(p.join(target.directory.path, 'asset_capsule_abandoned.wav'))
        .writeAsBytes([1, 2, 3]);
    await CapsuleService.cleanWorkspace(destination.workspace);
    await target.initialize();
    expect(await target.directory.list().length, 1);
    local = await LocalCatalogSource.open(bounded, zip);
    final reopened = local.revisions.singleWhere(
      (v) => v.key.token == r.key.token,
    );
    expect(await local.installed(reopened), true);
    expect((await local.plan(reopened.key)).newBytes, 0);
    await local.close();
  });
  test('Task14 immutable audio prevents package update silently replacing history dependencies', () async {
    final preview = await destination.inspect(zip);
    await destination.restore(preview);
    await preview.close();
    final before = await b.database.query('audio_assets');
    final changed = AudioAsset.fromMap({
      ...before.first,
      'contentHash':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });
    await expectLater(b.save(changed), throwsStateError);
    expect(await b.database.query('audio_assets'), before);
  });
  test('full offline capsule restores IDs, bytes, plans, history, diary and survives restart', () async {
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(
      archive.files.where((f) => f.isFile && f.name.startsWith('blobs/')),
      hasLength(3),
    ); // deduplicated audio + diary audio/image
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
    expect(await File(diary.blocks.first.media!.localPath!).readAsBytes(), [
      1,
      2,
      3,
      4,
    ]);
    expect(
      await File(diary.blocks.last.media!.localPath!).readAsBytes(),
      await File(p.join(source.diaryDirectory.path, 'image.png')).readAsBytes(),
    );
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
  test('merging equal session numbers preserves both histories and remains idempotent', () async {
    final originalRun = (await SqliteSessionRepository(
      a.database,
    ).history()).single;
    final sessions = SqliteSessionRepository(b.database);
    final local = await sessions.startRun(originalRun.snapshot);
    await sessions.checkpoint(local.checkpoint(status: RunStatus.interrupted));
    var preview = await destination.inspect(zip);
    await destination.restore(preview);
    await preview.close();
    final runs = await sessions.history();
    expect(runs.map((r) => r.id).toSet(), {local.id, originalRun.id});
    expect(runs.map((r) => r.displayNumber).toSet(), {1, 2});
    expect(await sessions.events(local.id), hasLength(1));
    preview = await destination.inspect(zip);
    expect(preview.alreadyImported, isTrue);
    await destination.restore(preview);
    await preview.close();
    expect(await sessions.history(), hasLength(2));
  });
  test('history may reference deliberately deleted audio without making its backup unrestorable', () async {
    for (final table in [
      'current_draft',
      'session_templates',
      'module_definitions',
      'audio_assets',
    ]) {
      await a.database.delete(table);
    }
    final partial = await source.export();
    final preview = await destination.inspect(partial);
    await destination.restore(preview);
    await preview.close();
    expect(await b.list(), isEmpty);
    expect(await SqliteSessionRepository(b.database).history(), hasLength(1));
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
  test('explicit cancellation before commit rolls back both database and new files', () async {
    final preview = await destination.inspect(zip);
    var cancel = false;
    await expectLater(
      destination.restore(
        preview,
        cancelled: () => cancel,
        beforeCommit: () async {
          cancel = true;
        },
      ),
      throwsFormatException,
    );
    expect(await b.list(), isEmpty);
    expect(await b.database.query('session_runs'), isEmpty);
    expect(await target.directory.list().toList(), isEmpty);
    await preview.close();
  });
  test('startup removes only abandoned transfer cache and preserves committed media and unrelated files', () async {
    await destination.workspace.create(recursive: true);
    final stale = Directory('${destination.workspace.path}/restore-old');
    await stale.create();
    await File('${stale.path}/partial').writeAsBytes([0]);
    final keep = await File('${destination.workspace.path}/unrelated.txt')
        .writeAsString('keep');
    final cached = await File(
      '${destination.workspace.path}/sulfi-incoming-old.zip',
    ).writeAsBytes([1]);
    await CapsuleService.cleanWorkspace(destination.workspace);
    expect(await stale.exists(), isFalse);
    expect(await cached.exists(), isFalse);
    expect(await keep.exists(), isTrue);
    expect(await zip.exists(), isTrue);
    expect(await original.fileFor((await a.list()).first).exists(), isTrue);
  });
  for (final mode in [
    'checksum',
    'schema',
    'dependency',
    'traversal',
    'size',
    'duplicate',
    'revision-payload',
  ]) {
    test('rejects $mode without touching destination', () async {
      final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final manifest = jsonDecode(
        utf8.decode(decoded.findFile('manifest.json')!.content),
      ) as Map<String, dynamic>;
      if (mode == 'schema') manifest['schema'] = 999;
      if (mode == 'revision-payload') {
        final invalid = ContentRevision.create(
          const ContentKey(ContentType.module, 'invalid'),
          {'id': 'invalid'},
        );
        manifest['records']['content_revisions'].add({
          'id': invalid.key.token,
          'payload': jsonEncode(invalid.toMap()),
        });
      }
      if (mode == 'size') manifest['files'][0]['bytes'] += 1;
      if (mode == 'duplicate') {
        manifest['records']['audio_assets'].add(
          Map<String, dynamic>.from(manifest['records']['audio_assets'][0]),
        );
      }
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
  for (final legacySchema in [6, 7, 8]) {
    test(
      'Task14 legacy schema $legacySchema capsule remains readable; access mode is never imported',
      () async {
        final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
        final manifest = jsonDecode(
          utf8.decode(decoded.findFile('manifest.json')!.content),
        );
        manifest['databaseSchema'] = legacySchema;
        manifest['records'].remove('content_revisions');
        if (legacySchema < 8) manifest['records'].remove('history_attachments');
        if (legacySchema == 6) {
          for (final row in manifest['records']['audio_assets']) {
            row.remove('authorManaged');
          }
        }
        manifest.remove('id');
        manifest['id'] = CapsuleService.digest(manifest);
        final archive = Archive();
        for (final f in decoded.files.where((f) => f.isFile)) {
          final data = f.name == 'manifest.json'
              ? utf8.encode(jsonEncode(manifest))
              : f.content;
          archive.addFile(ArchiveFile(f.name, data.length, data));
        }
        final legacy = await File(p.join(root.path, 'legacy6.zip'))
            .writeAsBytes(ZipEncoder().encode(archive));
        await target.policy.setMode(LocalMode.client);
        final preview = await destination.inspect(legacy);
        await destination.restore(preview);
        await preview.close();
        expect(target.policy.mode, LocalMode.client);
        final again = await destination.inspect(legacy);
        expect(again.alreadyImported, isTrue);
        expect(again.conflicts, isEmpty);
        await destination.restore(again);
        await again.close();
        expect(await b.list(), hasLength(2));
        expect(
          (await DiaryAuthorRepository(
            b.database,
          ).entries()).single.blocks.first.media!.assetId,
          'diary-audio',
        );
      },
    );
  }
  test(
    'Task5: CLIENT capsule replacement cannot overwrite protected author audio',
    () async {
      final asset = (await a.list()).first;
      await original.save(
        asset.edited(
          'Авторская запись',
          asset.category,
          section: LibrarySection.general,
        ),
      );
      final initialZip = await source.export();
      final first = await destination.inspect(initialZip);
      await destination.restore(first);
      await first.close();
      final before = (await b.list())
          .firstWhere((a) => a.id == asset.id)
          .toMap();
      await original.save(
        (await a.list())
            .firstWhere((a) => a.id == asset.id)
            .edited('Изменено в капсуле', asset.category),
      );
      final changed = await source.export();
      await target.policy.setMode(LocalMode.client);
      final preview = await destination.inspect(changed);
      await expectLater(
        destination.restore(preview, choice: CapsuleConflictChoice.replace),
        throwsA(isA<Exception>()),
      );
      await preview.close();
      expect(
        (await b.list()).firstWhere((a) => a.id == asset.id).toMap(),
        before,
      );
      expect(
        await target
            .fileFor((await b.list()).firstWhere((a) => a.id == asset.id))
            .exists(),
        isTrue,
      );
    },
  );
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
  test('a readable capsule can repair lost bytes after an earlier successful restore', () async {
    var preview = await destination.inspect(zip);
    await destination.restore(preview);
    await preview.close();
    final lost = (await b.list()).first;
    await target.fileFor(lost).delete();
    preview = await destination.inspect(zip);
    expect(preview.alreadyImported, isFalse);
    expect(preview.conflicts, isNotEmpty);
    await destination.restore(preview, choice: CapsuleConflictChoice.replace);
    await preview.close();
    final restored = (await b.list()).firstWhere((a) => a.id == lost.id);
    expect(await target.fileFor(restored).exists(), isTrue);
    expect(await b.database.query('run_events'), hasLength(2));
  });
}
