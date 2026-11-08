import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SqliteLibraryRepository repository;
  late LibraryService service;
  late File source;
  AudioSelection? selection;
  Duration? duration;
  bool corrupt = false;
  var cacheReleases = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sulfi_test_');
    repository = await SqliteLibraryRepository.open(
      p.join(root.path, 'library.sqlite'),
      factory: databaseFactoryFfi,
    );
    // Synthetic test bytes, not user audio. Decoder is injected independently.
    source = await File(p.join(root.path, 'example.MP3'))
        .writeAsBytes([1, 2, 3, 4]);
    selection = (name: 'example.MP3', path: source.path);
    duration = const Duration(seconds: 65);
    corrupt = false;
    cacheReleases = 0;
    service = LibraryService(
      repository: repository,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => selection,
      probe: (_) async {
        if (corrupt) throw StateError('test decoder failure');
        return duration;
      },
      releaseSelection: () async {
        cacheReleases++;
      },
    );
    await service.initialize();
  });

  tearDown(() async {
    await repository.database.close();
    await root.delete(recursive: true);
  });

  test('canceled system picker creates neither metadata nor files', () async {
    selection = null;
    expect(await service.prepareImport(), isNull);
    expect(await repository.list(), isEmpty);
    expect(await service.directory.list().toList(), isEmpty);
    expect(cacheReleases, 1);
  });

  test('legacy external path migrates bytes preserving its stable ID; lost source stays visible', () async {
    final imported = (await service.prepareImport())!;
    await service.discard(imported);
    final legacy = AudioAsset.fromMap({
      ...imported.toMap(),
      'filePath': source.path,
      'contentHash': null,
    });
    await repository.save(legacy);
    await service.initialize();
    final migrated = (await repository.list()).single;
    expect(migrated.id, legacy.id);
    expect(migrated.contentHash, hasLength(64));
    await source.rename('${source.path}.moved');
    expect(await service.fileFor(migrated).readAsBytes(), [1, 2, 3, 4]);
    await repository.save(
      AudioAsset.fromMap({
        ...migrated.toMap(),
        'id': 'lost',
        'filePath': '/missing/test.wav',
      }),
    );
    await service.initialize();
    expect(await repository.list(), hasLength(2));
    expect(service.migrationIssues.single, contains('недоступен'));
  });

  for (final format in ['mp3', 'm4a', 'wav']) {
    test(
      'copies $format and preserves it after external original is removed',
      () async {
        selection = (name: 'Спокойствие.$format', path: source.path);
        final draft = (await service.prepareImport())!;
        expect(draft.title, 'Спокойствие');
        expect(draft.format, format);
        expect(draft.durationMs, 65000);
        expect(draft.fileSizeBytes, 4);
        expect(p.isRelative(draft.filePath), isTrue);
        expect(await repository.list(), isEmpty);
        await service.save(draft.edited('Моё аудио', AudioCategory.exit));
        await source.delete();
        expect(await service.fileFor(draft).readAsBytes(), [1, 2, 3, 4]);
        final stored = (await repository.list()).single;
        expect(stored.title, 'Моё аудио');
        expect(stored.category, AudioCategory.exit);
        expect(cacheReleases, 1);
      },
    );
  }

  test(
    'uppercase extension is accepted and duplicate names do not overwrite',
    () async {
      final first = (await service.prepareImport())!;
      final second = (await service.prepareImport())!;
      expect(first.format, 'mp3');
      expect(first.id, isNot(second.id));
      expect(first.filePath, isNot(second.filePath));
      await service.save(first);
      await service.save(second);
      expect(await repository.list(), hasLength(2));
      expect(await service.directory.list().toList(), hasLength(2));
    },
  );

  test(
    'unsupported extension, empty file and missing source are rejected',
    () async {
      selection = (name: 'example.exe', path: source.path);
      await expectLater(
        service.prepareImport(),
        throwsA(isA<LibraryException>()),
      );
      selection = (name: 'example.mp3', path: source.path);
      await source.writeAsBytes([]);
      await expectLater(
        service.prepareImport(),
        throwsA(isA<LibraryException>()),
      );
      await source.delete();
      await expectLater(
        service.prepareImport(),
        throwsA(isA<LibraryException>()),
      );
      expect(await service.directory.list().toList(), isEmpty);
      expect(await repository.list(), isEmpty);
      expect(cacheReleases, 3);
    },
  );

  test(
    'decoder failure cleans private copy without deleting original',
    () async {
      corrupt = true;
      await expectLater(
        service.prepareImport(),
        throwsA(isA<LibraryException>()),
      );
      expect(await service.directory.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
      expect(await repository.list(), isEmpty);
    },
  );

  test('unknown and zero durations are rejected and cleaned', () async {
    duration = null;
    await expectLater(
      service.prepareImport(),
      throwsA(isA<LibraryException>()),
    );
    duration = Duration.zero;
    await expectLater(
      service.prepareImport(),
      throwsA(isA<LibraryException>()),
    );
    expect(await service.directory.list().toList(), isEmpty);
  });

  test('canceling metadata editor can discard draft safely', () async {
    final draft = (await service.prepareImport())!;
    await service.discard(draft);
    expect(await repository.list(), isEmpty);
    expect(await service.directory.list().toList(), isEmpty);
    expect(await source.exists(), isTrue);
  });

  test(
    'rename, category, IDs and private files survive reopening database',
    () async {
      final draft = (await service.prepareImport())!;
      await service.save(draft);
      await service.save(draft.edited(' Выход ', AudioCategory.exit));
      final databasePath = repository.database.path;
      await repository.database.close();
      repository = await SqliteLibraryRepository.open(
        databasePath,
        factory: databaseFactoryFfi,
      );
      final stored = (await repository.list()).single;
      expect(stored.id, draft.id);
      expect(stored.title, 'Выход');
      expect(stored.category, AudioCategory.exit);
      expect(stored.createdAt, draft.createdAt);
      expect(stored.filePath, draft.filePath);
      expect(await service.fileFor(stored).exists(), isTrue);
    },
  );

  test(
    'empty or excessive title is rejected without saving metadata',
    () async {
      final draft = (await service.prepareImport())!;
      await expectLater(
        service.save(draft.edited('   ', draft.category)),
        throwsA(isA<LibraryException>()),
      );
      await expectLater(
        service.save(draft.edited('x' * 121, draft.category)),
        throwsA(isA<LibraryException>()),
      );
      expect(await repository.list(), isEmpty);
    },
  );

  test('delete removes metadata and private file, keeps original', () async {
    final draft = (await service.prepareImport())!;
    await service.save(draft);
    await service.delete(draft);
    expect(await repository.list(), isEmpty);
    expect(await service.fileFor(draft).exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('missing private file can still be deleted from library', () async {
    final draft = (await service.prepareImport())!;
    await service.save(draft);
    await service.fileFor(draft).delete();
    await service.delete(draft);
    expect(await repository.list(), isEmpty);
  });

  test(
    'startup removes abandoned imports but preserves committed audio',
    () async {
      final saved = (await service.prepareImport())!;
      await service.save(saved);
      final abandoned = (await service.prepareImport())!;
      final partial = await File(
        p.join(service.directory.path, 'asset_orphan.wav.part'),
      ).writeAsBytes([0]);
      await service.initialize();
      expect(await service.fileFor(saved).exists(), isTrue);
      expect(await service.fileFor(abandoned).exists(), isFalse);
      expect(await partial.exists(), isFalse);
      expect((await repository.list()).single.id, saved.id);
    },
  );

  test(
    'reset removes all imported data without touching external files',
    () async {
      await service.save((await service.prepareImport())!);
      await service.save((await service.prepareImport())!);
      await service.reset();
      expect(await repository.list(), isEmpty);
      expect(await service.directory.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test('metadata cannot escape private audio directory', () async {
    final asset = AudioAsset(
      id: 'bad',
      title: 'bad',
      filePath: '../example.MP3',
      durationMs: 1,
      format: 'mp3',
      createdAt: DateTime.utc(2026),
      category: AudioCategory.freeform,
      fileSizeBytes: 4,
    );
    expect(() => service.fileFor(asset), throwsA(isA<LibraryException>()));
    expect(await source.exists(), isTrue);
  });
}
