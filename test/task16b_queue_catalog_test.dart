import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_media_transfer.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_catalog_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('G2/G4 persistent existing queue survives worker restart; pause/cancel preserve source; other account cannot resume', () async {
    final f = await Fixture15.open();
    String? owner = 'hashed-owner-a';
    final gate = Completer<void>();
    var sent = 0;
    final queue = AlchemistWorkQueue(
      db: f.db,
      owner: () => owner,
      send: (name, row, stop, stage, progress) async {
        sent++;
        stage('server_verifying');
        progress(42, 42);
        await gate.future;
        if (stop()) throw StateError('paused');
      },
    );
    const name = 'alchemist_card:fixture';
    try {
      await f.db.insert('app_settings', {
        'name': name,
        'value': jsonEncode({
          'ownerBinding': owner,
          'card': {'title': 'Fixture'},
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await queue.enqueue(name);
      for (var i = 0; i < 50 && sent == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sent, 1);
      await queue.pause(name);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await queue.refresh();
      expect(queue.rows.single['_work']['phase'], 'paused');
      owner = 'hashed-owner-b';
      await queue.refresh();
      expect(queue.rows, isEmpty);
      await expectLater(queue.enqueue(name), throwsA(isA<DiaryApiException>()));
      owner = 'hashed-owner-a';
      await queue.refresh();
      await queue.pause(name, cancel: true);
      expect(queue.rows.single['_work']['phase'], 'cancelled');
      expect(queue.rows.single['card']['title'], 'Fixture');
      queue.dispose();
      final restarted = AlchemistWorkQueue(
        db: f.db,
        owner: () => owner,
        send: (_, _, _, _, _) async {
          fail('Restart must not auto-send');
        },
      );
      await restarted.recover();
      expect(restarted.rows.single['_work']['phase'], 'cancelled');
      restarted.dispose();
    } finally {
      await f.close();
    }
  });
  test('G2 authoritative offset after lost chunk response, 100% is not verified, receipt reuse and owner isolation', () async {
    final f = await Fixture15.open();
    final file = File('${f.root.path}/large.mp4');
    await file.writeAsBytes(List<int>.generate(600000, (i) => i % 251));
    final hash = (await sha256.bind(file.openRead()).first).toString();
    var owner = 'account:opaque-a',
        offset = 0,
        chunks = 0,
        lose = true,
        commits = 0;
    final stages = <String>[];
    final descriptor = {
      'assetRevisionId': 'asset-fixture',
      'logicalId': 'logical',
      'revisionId': hash,
      'sha256': hash,
      'byteLength': 600000,
      'mime': 'video/mp4',
    };
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/UNIT/exec'),
      identityScope: () => owner,
      credential: () async => 'CONTROLLED_ONLY',
      maxAttempts: 1,
      connection: (method, uri, headers, body) async {
        final e = jsonDecode(body!), p = e['parameters'];
        Map<String, dynamic> result;
        switch (e['operation']) {
          case 'media.beginUpload':
            result = {'sessionId': 'session', 'offset': offset};
          case 'media.uploadChunk':
            expect(p['offset'], offset);
            final length = base64Decode(p['base64']).length;
            offset += length;
            chunks++;
            if (lose) {
              lose = false;
              throw const HttpException('private uncontrolled text');
            }
            result = {'offset': offset};
          case 'media.commitUpload':
            commits++;
            result = descriptor;
          case 'media.getDescriptor':
            result = descriptor;
          default:
            throw StateError('Unexpected operation');
        }
        return DiaryResponse(
          200,
          jsonEncode({'ok': true, 'status': 200, 'result': result}),
        );
      },
    );
    try {
      final transfer = AlchemistMediaTransfer(f.db, api);
      Future<Map<String, dynamic>> send() => transfer.upload(
        file,
        logicalId: 'logical',
        revisionId: hash,
        mime: 'video/mp4',
        onStage: (s) {
          stages.add(s);
          if (s == 'bytes_acked' && owner == 'account:opaque-a') {
            expect(commits, 0);
          }
        },
      );
      await expectLater(send(), throwsA(isA<AlchemistApiException>()));
      expect(offset, 262144);
      expect(await file.exists(), true);
      await send();
      expect(chunks, 3);
      expect(
        stages.indexOf('bytes_acked'),
        lessThan(stages.indexOf('server_verifying')),
      );
      expect(stages.last, 'verified');
      await send();
      expect(chunks, 3);
      expect(commits, 1);
      final previous = await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_upload:%'],
      );
      expect(previous, hasLength(1));
      expect(
        jsonEncode(previous),
        isNot(contains('private uncontrolled text')),
      );
      owner = 'account:opaque-b';
      await send();
      expect(
        await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_upload:%'],
        ),
        hasLength(2),
      );
      expect(await file.length(), 600000);
    } finally {
      await f.close();
    }
  });
  testWidgets(
    'G3 actual card deduplicates, restores cover and metadata, category multiselect renders',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final diary = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
        policy: f.c.policy,
        mediaStore: DiaryMediaStore(
          Directory('${f.root.path}/diary'),
          pick: (_) async => null,
          probe: (_) async => const Duration(seconds: 1),
        ),
      );
      final c = SessionController(
        repository: f.c.repository,
        library: f.c.library,
        capsules: f.c.capsules,
        diary: diary,
      );
      try {
        final data = (await t.runAsync(() async {
          final module = await seed15(f);
          final root = (await LocalCatalogSource.currentIndex(f.c.capsules!))
              .singleWhere((r) => r.key.content.id == module.id);
          final service = AlchemistCatalog(c);
          final d = await service.prepare(root);
          d['card']['shortAnnotation'] = 'Сохранённая аннотация';
          d['card']['description'] = 'Описание не перезаписывать';
          d['card']['categoryIds'] = ['Старая категория'];
          await diary.mediaStore!.directory.create(recursive: true);
          final image = File('${diary.mediaStore!.directory.path}/fixture.png');
          await image.writeAsBytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
            ),
          );
          d['localCover'] = DiaryMedia(
            assetId: 'cover-fixture',
            mime: 'image/png',
            bytes: await image.length(),
            hash: (await sha256.bind(image.openRead()).first).toString(),
            localPath: image.path,
          ).toMap();
          d['coverStatus'] = 'local';
          await service.save(d);
          final again = await Future.wait([
            service.prepare(root),
            service.prepare(root),
          ]);
          expect(
            again.every((v) => v['catalogItemId'] == d['catalogItemId']),
            true,
          );
          expect(await service.drafts(), hasLength(1));
          return (service: service, draft: again.first);
        }))!;
        await show15(
          t,
          f,
          CatalogCardEditor(service: data.service, draft: data.draft),
        );
        expect(find.byType(Image), findsWidgets);
        expect(find.text('Сохранённая аннотация'), findsOneWidget);
        expect(find.text('Обложка: local'), findsOneWidget);
        await capture15(t, 'task16b-cover-local');
        await t.scrollUntilVisible(
          find.textContaining('Категории:'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.textContaining('Категории:'));
        await io15(t);
        expect(find.text('Старая категория'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsWidgets);
        await capture15(t, 'task16b-category-selection');
        await t.tap(find.text('Готово'));
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 600));
        await io15(t);
        await t.pumpWidget(const SizedBox());
      } finally {
        c.dispose();
        diary.dispose();
        await t.runAsync(f.close);
      }
    },
  );
}
