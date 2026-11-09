import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late Database db;
  late AccessPolicy policy;
  late LibraryService library;
  late ModuleCatalog modules;
  late SqliteSessionRepository sessions;
  final now = DateTime.utc(2026, 11, 7);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task5-access');
    db = await openAppDatabase(
      '${root.path}/db.sqlite',
      factory: databaseFactoryFfi,
    );
    policy = AccessPolicy(database: db);
    await policy.load();
    library = LibraryService(
      policy: policy,
      repository: SqliteLibraryRepository(db),
      directory: Directory('${root.path}/audio'),
      pick: () async =>
          (name: 'sample.m4a', path: 'test/fixtures/android_aac_isom.m4a'),
      probe: (_) async => const Duration(seconds: 12),
    );
    await library.initialize();
    modules = ModuleCatalog(db, policy);
    sessions = SqliteSessionRepository(db, policy);
  });
  tearDown(() async {
    policy.dispose();
    await db.close();
    await root.delete(recursive: true);
  });
  test('AUTHOR section General persists independently of personal origin and protects bytes in CLIENT', () async {
    final imported = (await library.prepareImport())!;
    await library.save(
      imported.edited(
        'Общий материал',
        AudioCategory.preparation,
        section: LibrarySection.general,
      ),
    );
    final common = (await library.repository.list()).single;
    expect(common.section, LibrarySection.general);
    expect(common.origin, 'personal');
    expect(common.isPersonal, isTrue);
    expect(common.authorManaged, isTrue);
    await policy.setMode(LocalMode.client);
    expect(policy.canEditAudio(common), isFalse);
    // Forging the incoming origin/section does not bypass the stored ownership.
    final forged = AudioAsset.fromMap({
      ...common.toMap(),
      'section': 'personal',
      'authorManaged': 0,
    });
    await expectLater(library.save(forged), throwsA(isA<LibraryException>()));
    await expectLater(library.delete(forged), throwsA(isA<LibraryException>()));
    expect(await library.fileFor(common).exists(), isTrue);
    await policy.setMode(LocalMode.author);
    await library.save(common.edited('Обновлён', common.category));
  });
  test('CLIENT imports personal audio, creates modules and templates; provided definitions remain readonly', () async {
    await modules.save(
      ModuleDefinition(id: 'supplied', title: 'Авторский', origin: 'supplied'),
    );
    final supplied = SessionTemplate(
      id: 'base',
      name: 'База',
      origin: 'supplied',
      plan: SessionPlan(steps: const []),
      createdAt: now,
      updatedAt: now,
    );
    await sessions.saveTemplate(supplied);
    await policy.setMode(LocalMode.client);
    final audio = (await library.prepareImport())!;
    await library.save(audio);
    await expectLater(
      library.save(
        audio.edited(
          audio.title,
          audio.category,
          section: LibrarySection.suggestions,
        ),
      ),
      throwsA(isA<LibraryException>()),
    );
    await modules.save(
      ModuleDefinition(
        id: 'own',
        title: 'Мой',
        items: [
          SessionStep(
            id: 's',
            kind: StepKind.audio,
            title: audio.title,
            audioAssetId: audio.id,
            durationMs: audio.durationMs,
          ),
        ],
      ),
    );
    await modules.attach(
      'own',
      SessionStep(
        id: 'p',
        kind: StepKind.silence,
        title: 'Пауза',
        durationMs: 1000,
      ),
    );
    await expectLater(
      modules.save(ModuleDefinition(id: 'supplied', title: 'Подмена')),
      throwsA(isA<LibraryException>()),
    );
    await expectLater(
      modules.attach(
        'supplied',
        SessionStep(id: 'x', kind: StepKind.silence, title: 'x'),
      ),
      throwsA(isA<LibraryException>()),
    );
    await sessions.saveTemplate(
      SessionTemplate(
        id: 'own',
        name: 'Мой шаблон',
        plan: SessionPlan(steps: const []),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await expectLater(
      sessions.saveTemplate(supplied),
      throwsA(isA<LibraryException>()),
    );
    await expectLater(
      sessions.deleteTemplate('base'),
      throwsA(isA<LibraryException>()),
    );
    await sessions.deleteTemplate('own');
    await expectLater(library.reset(), throwsA(isA<LibraryException>()));
    expect((await library.repository.list()).single.id, audio.id);
  });
  test('mode persists without changing content; fixed client edition ignores persisted AUTHOR and rejects switching', () async {
    await policy.setMode(LocalMode.client);
    final reopened = AccessPolicy(database: db);
    await reopened.load();
    expect(reopened.mode, LocalMode.client);
    await policy.setMode(LocalMode.author);
    final client = AccessPolicy(database: db, clientEdition: true);
    await client.load();
    expect(client.mode, LocalMode.client);
    await expectLater(
      client.setMode(LocalMode.author),
      throwsA(isA<LibraryException>()),
    );
    reopened.dispose();
    client.dispose();
  });
  test(
    'CLIENT local diary requires no author login and cannot publish',
    () async {
      await policy.setMode(LocalMode.client);
      final diary = DiaryController(
        DiaryRepository(db),
        authorRepository: DiaryAuthorRepository(db),
        policy: policy,
      );
      final entry = DiaryEntry(
        id: 'personal',
        message: 'Личная запись',
        createdAt: now,
        updatedAt: now,
      );
      await diary.saveDraft(entry);
      expect(diary.drafts.single.id, 'personal');
      await expectLater(
        diary.publish(entry, published: true),
        throwsA(isA<Exception>()),
      );
      expect(
        (await DiaryAuthorRepository(db).entries()).single.message,
        'Личная запись',
      );
      diary.dispose();
    },
  );
  test('v6 -> v7 additive migration preserves all existing rows and origin/section', () async {
    final audio = (await library.prepareImport())!;
    await library.save(
      audio.edited(
        'Авторский импорт',
        AudioCategory.induction,
        section: LibrarySection.general,
      ),
    );
    await db.execute('ALTER TABLE audio_assets DROP COLUMN authorManaged');
    await db.execute('DROP TABLE app_settings');
    await db.execute('PRAGMA user_version=6');
    final before = await db.query('audio_assets');
    await db.close();
    db = await openAppDatabase(
      '${root.path}/db.sqlite',
      factory: databaseFactoryFfi,
    );
    expect(await db.getVersion(), 9);
    final after = await db.query('audio_assets');
    for (final e in before.single.entries) {
      expect(after.single[e.key], e.value);
    }
    expect(after.single['authorManaged'], 1);
    expect(after.single['origin'], 'personal');
    expect(await File('${root.path}/audio/${audio.filePath}').exists(), isTrue);
  });
}
