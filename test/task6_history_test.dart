import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:archive/archive_io.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/history_attachments.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/preview_diary_transport.dart';
import 'package:sulfi_hypnotherapy/services/diary_audio.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('six histories, separate multimedia, deletion gaps and clean capsule restore remain idempotent', () async {
    final root = await Directory.systemTemp.createTemp('task6');
    final db = await openAppDatabase(
      '${root.path}/db',
      factory: databaseFactoryFfi,
    );
    final lib = LibraryService(
      repository: SqliteLibraryRepository(db),
      directory: Directory('${root.path}/audio'),
      pick: () async => null,
      probe: (_) async => const Duration(seconds: 12),
    );
    await lib.initialize();
    final repo = SqliteSessionRepository(db);
    final media = DiaryMediaStore(
      Directory('${root.path}/history_media'),
      stripImageMetadata: true,
      pick: (_) async => null,
      probe: lib.probe,
    );
    final attachments = HistoryAttachments(db, media);
    final templates = <SessionTemplate>[];
    for (var i = 0; i < 3; i++) {
      final t = SessionTemplate(
        id: 'template-$i',
        name: 'Исходный $i',
        description: 'Сохранённое описание',
        plan: SessionPlan(
          steps: [
            const SessionStep(
              id: 's',
              kind: StepKind.silence,
              title: 'Пауза',
              durationMs: 1000,
            ),
          ],
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveTemplate(t);
      templates.add(t);
    }
    final ids = <String>[];
    for (var i = 0; i < 6; i++) {
      final r = await repo.startRun(
        CurrentSessionDraft.fromTemplate(templates[i % 3]),
      );
      await repo.checkpoint(
        r.checkpoint(
          status: i == 2 ? RunStatus.interrupted : RunStatus.completed,
        ),
        event: i == 2 ? 'interrupted' : 'completed',
      );
      ids.add(r.id);
    }
    await repo.deleteTemplate(templates.last.id);
    final before = (await repo.history())
        .map((r) => r.snapshot.toMap())
        .toList();
    final block = await media.importFile(DiaryBlockType.audio, (
      name: 'note.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    await db.execute(
      "CREATE TRIGGER history_failure BEFORE INSERT ON history_attachments BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(
      attachments.attach(ids.last, block),
      throwsA(isA<Exception>()),
    );
    expect(await attachments.list(ids.last), isEmpty);
    expect(await media.file(block.media)!.exists(), isTrue);
    await db.execute('DROP TRIGGER history_failure');
    final a = await attachments.attach(ids.last, block);
    final originalImage = await File('${root.path}/original.png').writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAH3RFWHRDb21tZW50AFJFTU9WRS1NRVRBREFUQS1GSVhUVVJFjb2KVwAAABZJREFUeJxj/P+fgYGBgYmBgYGBgQEAGRECAp3OF8MAAAAASUVORK5CYII=',
      ),
    );
    final picture = await media.importFile(DiaryBlockType.image, (
      name: 'picture.png',
      path: originalImage.path,
    ));
    await attachments.attach(ids.last, picture);
    expect(
      utf8.decode(
        await media.file(picture.media)!.readAsBytes(),
        allowMalformed: true,
      ),
      isNot(contains('REMOVE-METADATA-FIXTURE')),
    );
    expect(
      utf8.decode(await originalImage.readAsBytes(), allowMalformed: true),
      contains('REMOVE-METADATA-FIXTURE'),
    );
    final diaryMedia = DiaryMediaStore(
      Directory('${root.path}/diary'),
      pick: (_) async => null,
      probe: lib.probe,
    );
    final diaryBlock = await diaryMedia.importFile(DiaryBlockType.audio, (
      name: 'diary-note.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    final diary = DiaryEntry(
      id: 'portable-diary',
      message: 'Текст дневника',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      blocks: [
        DiaryBlock(id: 'text', type: DiaryBlockType.text, text: 'До аудио'),
        diaryBlock,
      ],
      readingState: {
        'textReadAt': '2026-11-01',
        'audioListenedAt': null,
        'priority': 2,
      },
    );
    await DiaryAuthorRepository(db).save(diary);

    await repo.editRun(ids.last, notes: 'Текст');
    expect(
      (await repo.history()).map((r) => r.snapshot.toMap()).toList(),
      before,
    );
    expect(await lib.repository.list(), isEmpty);
    final second = await attachments.attach(ids.first, block);
    await attachments.remove(ids.first, second.id);
    expect(await media.file(block.media)!.exists(), isTrue);
    await repo.deleteRun(ids[1]);
    expect(await repo.history(), hasLength(5));
    expect(await repo.nextNumber(), 7);
    final capsule = CapsuleService(
      database: db,
      library: lib,
      diaryDirectory: Directory('${root.path}/diary'),
      workspace: Directory('${root.path}/cache'),
    );
    final zip = await capsule.export();
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    expect(
      archive.files.where((f) => f.isFile && f.name.startsWith('blobs/')),
      hasLength(2),
    );
    expect(
      utf8.decode(archive.findFile('manifest.json')!.content),
      isNot(contains(root.path)),
    );
    final target = await openAppDatabase(
      '${root.path}/other/db',
      factory: databaseFactoryFfi,
    );
    final targetLib = LibraryService(
      repository: SqliteLibraryRepository(target),
      directory: Directory('${root.path}/other/audio'),
      pick: () async => null,
      probe: lib.probe,
    );
    await targetLib.initialize();
    final restore = CapsuleService(
      database: target,
      library: targetLib,
      diaryDirectory: Directory('${root.path}/other/diary'),
      workspace: Directory('${root.path}/other/cache'),
    );
    final preview = await restore.inspect(zip);
    await restore.restore(preview);
    await preview.close();
    expect(
      (await SqliteSessionRepository(
        target,
      ).history()).map((r) => r.id).toSet(),
      (await repo.history()).map((r) => r.id).toSet(),
    );
    final restored = (await HistoryAttachments(
      target,
      DiaryMediaStore(
        Directory('${root.path}/other/history_media'),
        pick: (_) async => null,
        probe: lib.probe,
      ),
    ).list(ids.last)).firstWhere((item) => item.id == a.id);
    expect(restored.id, a.id);
    final targetAttachments = HistoryAttachments(
      target,
      DiaryMediaStore(
        Directory('${root.path}/other/history_media'),
        pick: (_) async => null,
        probe: lib.probe,
      ),
    );
    expect(await targetAttachments.list(ids.last), hasLength(2));
    final targetPicture = (await targetAttachments.list(ids.last))
        .firstWhere((a) => a.block.type == DiaryBlockType.image);
    expect(
      await File(targetPicture.block.media!.localPath!).readAsBytes(),
      await media.file(picture.media)!.readAsBytes(),
    );
    expect(await target.query('session_runs'), await db.query('session_runs'));
    final restoredDiary = (await DiaryAuthorRepository(
      target,
    ).entries()).single;
    expect(
      restoredDiary.blocks.map((b) => b.id),
      diary.blocks.map((b) => b.id),
    );
    expect(restoredDiary.readingState, diary.readingState);
    expect(
      await File(restoredDiary.blocks.last.media!.localPath!).readAsBytes(),
      await diaryMedia.file(diaryBlock.media)!.readAsBytes(),
    );

    expect(
      await File(restored.block.media!.localPath!).readAsBytes(),
      await media.file(block.media)!.readAsBytes(),
    );
    final again = await restore.inspect(zip);
    expect(again.alreadyImported, isTrue);
    await restore.restore(again);
    await again.close();
    expect(
      jsonEncode(
        (await SqliteSessionRepository(
          target,
        ).history()).first.snapshot.toMap(),
      ),
      jsonEncode((await repo.history()).first.snapshot.toMap()),
    );
    await repo.deleteRun(ids.last);
    expect(await attachments.list(ids.last), isEmpty);
    await attachments.collect();
    expect(await media.file(block.media)!.exists(), isFalse);
    await target.close();
    await db.close();
    await root.delete(recursive: true);
  });
  test('invalid history audio metadata is rejected and corrupt references preserve every private file', () async {
    final root = await Directory.systemTemp.createTemp('task6-invalid');
    final db = await openAppDatabase(
      '${root.path}/db',
      factory: databaseFactoryFfi,
    );
    final repo = SqliteSessionRepository(db);
    final run = await repo.startRun(
      CurrentSessionDraft(
        plan: SessionPlan(steps: const []),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.checkpoint(
      run.checkpoint(status: RunStatus.completed),
      event: 'completed',
    );
    final store = DiaryMediaStore(
      Directory('${root.path}/history_media'),
      pick: (_) async => null,
      probe: (_) async => const Duration(seconds: 12),
    );
    final service = HistoryAttachments(db, store);
    final block = await store.importFile(DiaryBlockType.audio, (
      name: 'note.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    final attachment = await service.attach(run.id, block);
    final invalid = attachment.toMap();
    (invalid['block'] as Map)['durationMs'] = null;
    expect(() => HistoryAttachment.fromMap(invalid), throwsFormatException);
    final unrelated = await File(
      '${store.directory.path}/retained-after-error.m4a',
    ).writeAsBytes([1, 2, 3]);
    await db.update(
      'history_attachments',
      {'payload': jsonEncode(invalid)},
      where: 'id=?',
      whereArgs: [attachment.id],
    );
    await expectLater(service.collect(), throwsFormatException);
    expect(await unrelated.exists(), isTrue);
    expect(await store.file(block.media)!.exists(), isTrue);
    await db.close();
    await root.delete(recursive: true);
  });
  test('dormant diary text/audio reading fields survive copy and portable serialization', () {
    final e = DiaryEntry(
      id: 'e',
      message: 'm',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      readingState: {
        'textReadAt': '2026-11-01',
        'audioListenedAt': null,
        'priority': 2,
      },
    );
    expect(
      DiaryEntry.fromMap(e.copyWith(message: 'changed').toMap()).readingState,
      e.readingState,
    );
    expect(e.toMap(public: true).containsKey('readingState'), isFalse);
  });
  test('schema7 to8 preserves six raw run documents and settings without creating history', () async {
    final root = await Directory.systemTemp.createTemp('task6-migration');
    var db = await openAppDatabase(
      '${root.path}/db',
      factory: databaseFactoryFfi,
    );
    final repo = SqliteSessionRepository(db);
    for (var i = 0; i < 6; i++) {
      final run = await repo.startRun(
        CurrentSessionDraft(
          plan: SessionPlan(steps: const []),
          updatedAt: DateTime.now(),
        ),
      );
      await repo.checkpoint(
        run.checkpoint(status: RunStatus.interrupted),
        event: 'interrupted',
      );
    }
    await db.insert('app_settings', {
      'name': 'content_mode',
      'value': 'client',
    });
    final before = await db.query('session_runs');
    final events = await db.query('run_events');
    final counters = await db.query('app_counters');
    await db.execute('DROP TABLE history_attachments');
    await db.execute('PRAGMA user_version=7');
    await db.close();
    db = await openAppDatabase('${root.path}/db', factory: databaseFactoryFfi);
    expect(await db.query('session_runs'), before);
    expect(await db.query('run_events'), events);
    expect(await db.query('app_counters'), counters);
    expect(
      (await db.query(
        'app_settings',
        where: "name='content_mode'",
      )).single['value'],
      'client',
    );
    expect(await db.query('history_attachments'), isEmpty);
    expect(await db.getVersion(), 9);
    await db.close();
    await root.delete(recursive: true);
  });
  test('diary adapter keeps the one shared preview alive after reader disposal and resumes from the same source', () async {
    final root = await Directory.systemTemp.createTemp('task6-preview');
    final store = DiaryMediaStore(
      root,
      pick: (_) async => null,
      probe: (_) async => const Duration(seconds: 12),
    );
    final block = await store.importFile(DiaryBlockType.audio, (
      name: 'note.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    final player = MemoryPlayer();
    final first = DiaryAudio(
      transport: PreviewDiaryTransport(player),
      store: store,
    );
    await first.toggle(block);
    expect(player.playing, isTrue);
    final id = player.current!.id;
    await first.close();
    expect(player.playing, isTrue);
    final second = DiaryAudio(
      transport: PreviewDiaryTransport(player),
      store: store,
    );
    await second.toggle(block);
    expect(player.playing, isFalse);
    expect(player.current!.id, id);
    await second.toggle(block);
    expect(player.playing, isTrue);
    expect(player.current!.id, id);
    await second.close();
    await player.stop();
    player.dispose();
    await root.delete(recursive: true);
  });
}
