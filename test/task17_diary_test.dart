import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/diary_publication.dart';
import 'package:sulfi_hypnotherapy/services/diary_layout.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';

import 'support/task15_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DiaryEntry short() => DiaryEntry(
    id: 'short17',
    title: 'Короткая запись',
    message: 'Добавь себе в библиотеку',
    blocks: const [],
    createdAt: DateTime.utc(2026, 11, 13),
    updatedAt: DateTime.utc(2026, 11, 13),
  );
  test('17 G3 title + short message valid without fake blocks; published header independent of missing number', () {
    final e = short();
    expect(e.publicationErrorFor(advanced: true), isNull);
    expect(e.contentLinks, isEmpty);
    expect(e.blocks, isEmpty);
    expect(
      e.copyWith(title: '').publicationErrorFor(advanced: true),
      isNotNull,
    );
    expect(
      diaryMeta(e.copyWith(status: DiaryStatus.published)),
      contains('Опубликовано'),
    );
    expect(
      diaryMeta(e.copyWith(status: DiaryStatus.published)),
      isNot(contains('Черновик')),
    );
  });
  test('17 G3 same verified media bytes at private path and server locator are not a working draft', () {
    final local = short().copyWith(
      blocks: [
        DiaryBlock(
          id: 'image',
          type: DiaryBlockType.image,
          media: DiaryMedia(
            assetId: 'local',
            mime: 'image/png',
            bytes: 20,
            hash: 'a' * 64,
            localPath: 'private/picture.png',
          ),
        ),
      ],
    );
    final remote = local.copyWith(
      status: DiaryStatus.published,
      blocks: [
        DiaryBlock(
          id: 'image',
          type: DiaryBlockType.image,
          media: DiaryMedia(
            assetId: 'remote',
            mime: 'image/png',
            bytes: 20,
            hash: 'a' * 64,
            locator: 'alchemist:opaque',
          ),
        ),
      ],
    );
    expect(diaryEditFingerprint(local), diaryEditFingerprint(remote));
    expect(
      diaryEditFingerprint(local.copyWith(title: 'Изменено')),
      isNot(diaryEditFingerprint(remote)),
    );
  });
  test('17 G2 atomic diary intent survives before pump and legacy flush cannot bypass the durable runner', () async {
    final f = await Fixture15.open();
    final api = AlchemistDiaryApi(
      Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, _) async => DiaryResponse(
        200,
        jsonEncode({
          'ok': true,
          'status': 200,
          'result': {
            'subject': 'controlled-owner',
            'role': 'MASTER',
            'expiresAt':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        }),
      ),
    );
    var sent = 0;
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => api.author.ownerBinding,
      send: (_, _, _, _, _) async {
        sent++;
      },
    );
    try {
      final session = await api.authenticate('CONTROLLED_NOT_GOOGLE');
      await Future.wait(
        List.generate(
          5,
          (_) => api.enqueueDurablePublication(short(), published: true),
        ),
      );
      final rows = await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_diary_queue:%'],
      );
      expect(rows.length, 1);
      expect(
        jsonDecode(rows.single['value'] as String)['_work']['phase'],
        'queued',
      );
      expect(await api.flushPending(session), 0);
      await q.recover();
      expect(q.rows.single['_work']['code'], 'APP_RESTART');
      expect(sent, 0);
      await q.enqueue('alchemist_diary_queue:short17');
      for (var i = 0; i < 100 && sent == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sent, 1);
    } finally {
      q.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await f.close();
    }
  });
}
