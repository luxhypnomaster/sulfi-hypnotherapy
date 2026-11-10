import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/services/diary_read_state.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_install.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('local cross-language author → production JS domain → client selective install, metadata-only retry and revoke', () async {
    final process = await Process.start('node', [
      'server/alchemist/test/support/flutter-bridge.mjs',
    ]);
    final errors = <String>[];
    process.stderr.transform(utf8.decoder).listen(errors.add);
    final port = int.parse(
      await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first,
    );
    HttpOverrides.global = null;
    final http = HttpClient();
    bool losePublishReply = false;
    Future<DiaryResponse> connection(
      String method,
      Uri uri,
      Map<String, String> headers,
      String? body,
    ) async {
      final req = await http.postUrl(Uri.parse('http://127.0.0.1:$port'));
      headers.forEach(req.headers.set);
      req.add(utf8.encode(body!));
      final res = await req.close();
      final response = DiaryResponse(
        res.statusCode,
        await utf8.decoder.bind(res).join(),
      );
      if (losePublishReply &&
          jsonDecode(body)['operation'] == 'catalog.publish') {
        losePublishReply = false;
        throw const SocketException('Injected lost commit response');
      }
      return response;
    }

    final endpoint = Uri.parse(
      'https://script.google.com/macros/s/LOCAL_TEST_ONLY/exec',
    );
    final ownerApi = AlchemistApi(
      endpoint,
      connection: connection,
      credential: () async => 'TEST_OWNER',
      maxAttempts: 1,
    );
    final reader = AlchemistApi(endpoint, connection: connection);
    final author = await Fixture15.open(),
        client = await Fixture15.open(client: true);
    try {
      final module = await seed15(author);
      final index = await LocalCatalogSource.currentIndex(author.c.capsules!);
      final service = AlchemistCatalog(author.c, api: ownerApi);
      final track = index.firstWhere(
        (r) => r.key.content.type == ContentType.track,
      );
      final trackCard = await service.prepare(track);
      trackCard['card']['shortAnnotation'] = 'Первый трек';
      trackCard['card']['visibility'] = 'public';
      await service.publish(trackCard);
      final trackPublic = await reader.call('catalog.get', {
        'catalogItemId': trackCard['catalogItemId'],
      });
      final installer = AlchemistInstall(client.c.capsules!, reader);
      await installer.install(trackPublic);
      expect(
        await LocalCatalogSource.installedRevision(client.c.capsules!, track),
        isTrue,
      );
      final firstStats = await ownerApi.call('test.stats', {});
      final moduleRoot = index.singleWhere(
        (r) => r.key.content.id == module.id,
      );
      final draft = await service.prepare(moduleRoot);
      draft['card']['shortAnnotation'] = 'Три точных трека и две паузы';
      draft['card']['visibility'] = 'public';
      losePublishReply = true;
      await expectLater(
        service.publish(draft),
        throwsA(isA<SocketException>()),
      );
      final recovered = (await service.drafts()).singleWhere(
        (r) => r['catalogItemId'] == draft['catalogItemId'],
      );
      expect(recovered['pending'], isNotNull);
      await service.publish(recovered);
      draft.clear();
      draft.addAll(recovered);
      final all = await reader.call('catalog.list', {});
      expect((all['items'] as List).length, 2);
      final public = await reader.call('catalog.get', {
        'catalogItemId': draft['catalogItemId'],
      });
      await installer.install(public);
      await client.c.reload();
      expect(
        await LocalCatalogSource.installedRevision(
          client.c.capsules!,
          moduleRoot,
        ),
        isTrue,
      );
      expect(client.c.assets.length, 3);
      expect(client.c.modules.entries.single.items.length, 5);
      final after = await ownerApi.call('test.stats', {});
      expect(
        after['blobs'],
        3,
        reason: 'same track reused when publishing a module',
      );
      expect(
        after['downloaded'],
        after['uploaded'],
        reason: 'already installed first track was never downloaded twice',
      );
      expect(after['downloaded'], greaterThan(firstStats['downloaded'] as int));
      draft['card']['shortAnnotation'] = 'Только новая аннотация';
      await service.publish(draft);
      await service.publish(
        draft,
      ); // stable receipt even if user repeats success
      expect(
        (await ownerApi.call('test.stats', {}))['uploaded'],
        after['uploaded'],
      );
      expect(
        (await reader.call('catalog.get', {
          'catalogItemId': draft['catalogItemId'],
        }))['card']['shortAnnotation'],
        'Только новая аннотация',
      );
      await service.transition(draft, 'withdraw');
      expect(
        () => reader.call('catalog.get', {
          'catalogItemId': draft['catalogItemId'],
        }),
        throwsA(isA<DiaryApiException>()),
      );
      expect(
        await LocalCatalogSource.installedRevision(
          client.c.capsules!,
          moduleRoot,
        ),
        isTrue,
        reason: 'withdrawal never deletes an offline installed copy',
      );
      final collection = await service.prepareCollection([
        track,
        moduleRoot,
      ], 'Набор расслабления');
      collection['card']['shortAnnotation'] =
          'Модуль и трек без повторного скачивания';
      collection['card']['visibility'] = 'public';
      await service.publish(collection);
      final collectionCard = await reader.call('catalog.get', {
        'catalogItemId': collection['catalogItemId'],
      });
      final statsCollection = await ownerApi.call('test.stats', {});
      await installer.install(collectionCard);
      expect(
        (await ownerApi.call('test.stats', {}))['downloaded'],
        statsCollection['downloaded'],
      );
      final capsule = await author.c.capsules!.export(moduleId: module.id);
      final package = await service.preparePackage(capsule);
      package['card']['shortAnnotation'] = 'Проверенный переносимый ZIP';
      package['card']['visibility'] = 'public';
      await service.publish(package);
      final packageCard = await reader.call('catalog.get', {
        'catalogItemId': package['catalogItemId'],
      });
      await installer.install(packageCard);
      expect(
        await LocalCatalogSource.installedRevision(
          client.c.capsules!,
          moduleRoot,
        ),
        isTrue,
      );
      expect(client.c.assets.length, 3);
      author.c.draft = CurrentSessionDraft(
        plan: SessionPlan(steps: module.items),
        updatedAt: DateTime.utc(2026),
        notes: 'PRIVATE NOTE NOT EXPORTED',
      );
      final sessionCard = await service.prepareCurrentSession();
      expect(jsonEncode(sessionCard['root']).contains('PRIVATE NOTE'), isFalse);
      sessionCard['card']['shortAnnotation'] = 'Состав текущей сессии';
      sessionCard['card']['visibility'] = 'public';
      await service.publish(sessionCard);
      await installer.install(
        await reader.call('catalog.get', {
          'catalogItemId': sessionCard['catalogItemId'],
        }),
      );
      final template = SessionTemplate(
        id: 'template16',
        name: 'Шаблон',
        plan: author.c.draft.plan,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await author.c.repository.saveTemplate(template);
      final templateRoot = (await LocalCatalogSource.currentIndex(
        author.c.capsules!,
      )).singleWhere((r) => r.key.content.id == template.id);
      final templateCard = await service.prepare(templateRoot);
      templateCard['card']['shortAnnotation'] = 'Точный шаблон';
      templateCard['card']['visibility'] = 'public';
      await service.publish(templateCard);
      await installer.install(
        await reader.call('catalog.get', {
          'catalogItemId': templateCard['catalogItemId'],
        }),
      );
      expect(
        await LocalCatalogSource.installedRevision(
          client.c.capsules!,
          templateRoot,
        ),
        isTrue,
      );
      final secondAuthor = await Fixture15.open();
      try {
        final remoteEditor = AlchemistCatalog(secondAuthor.c, api: ownerApi);
        expect(await remoteEditor.synchronize(), greaterThanOrEqualTo(5));
        final remoteCard = (await remoteEditor.drafts()).singleWhere(
          (v) => v['catalogItemId'] == trackCard['catalogItemId'],
        );
        expect(remoteCard['remoteOnly'], isTrue);
        expect(secondAuthor.c.assets, isEmpty);
        final beforeMeta = await ownerApi.call('test.stats', {});
        remoteCard['card']['shortAnnotation'] =
            'Аннотация со второго устройства';
        await remoteEditor.publish(remoteCard);
        expect(
          (await ownerApi.call('test.stats', {}))['uploaded'],
          beforeMeta['uploaded'],
        );
        expect(
          (await reader.call('catalog.get', {
            'catalogItemId': trackCard['catalogItemId'],
          }))['card']['shortAnnotation'],
          'Аннотация со второго устройства',
        );
      } finally {
        await secondAuthor.close();
      }
      // Same new backend and existing diary models: durable offline intent,
      // actual multipart video bytes, no private path projection, offline cache.
      final authorMedia = DiaryMediaStore(
        Directory('${author.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => const Duration(seconds: 1),
        videoProbe: (_) async => (width: 64, height: 48, durationMs: 1000),
      );
      final clip = File('${author.root.path}/large.mp4');
      final videoBytes = await File('test/fixtures/task16_video.mp4')
          .readAsBytes();
      final padded = <int>[
        ...videoBytes,
        0,
        32,
        0,
        0,
        102,
        114,
        101,
        101,
        ...List.filled(2 * 1024 * 1024 - 8, 0),
      ];
      await clip.writeAsBytes(padded);
      final video = await authorMedia.importFile(DiaryBlockType.video, (
        path: clip.path,
        name: 'large.mp4',
      ));
      final entry = DiaryEntry(
        id: 'diary16',
        extra: {
          'contentLinks': [
            ContentLink(moduleRoot.key, ContentLinkAction.install).toMap(),
          ],
        },
        title: 'Видео и текст',
        message: 'Аннотация дневника',
        blocks: [
          const DiaryBlock(
            id: 'text',
            type: DiaryBlockType.text,
            text: 'Точный текст',
          ),
          video,
        ],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final diaryAuthor = AlchemistDiaryApi(
        endpoint,
        capsules: author.c.capsules!,
        media: authorMedia,
        connection: connection,
      );
      await diaryAuthor.enqueuePublication(entry, published: true);
      expect(
        (await author.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_diary_queue:%'],
        )).length,
        1,
      );
      final session = await diaryAuthor.authenticate('TEST_OWNER');
      expect(await diaryAuthor.flushPending(session), 1);
      final localRow = (await author.db.query(
        'diary_author',
        where: 'id=?',
        whereArgs: [entry.id],
      )).single;
      final publishedDiary = DiaryEntry.fromMap(
        Map<String, dynamic>.from(jsonDecode(localRow['payload'] as String)),
      );
      expect(publishedDiary.status, DiaryStatus.published);
      final clientMedia = DiaryMediaStore(
        Directory('${client.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => null,
      );
      final diaryReader = AlchemistDiaryApi(
        endpoint,
        capsules: client.c.capsules!,
        media: clientMedia,
        connection: connection,
      );
      final feed = await diaryReader.feed();
      final received = feed.entries.singleWhere((e) => e.id == entry.id);
      expect(received.blocks.last.type, DiaryBlockType.video);
      expect(received.contentLinks.single.key.digest, moduleRoot.key.digest);
      final exact = await reader.call('catalog.resolveReference', {
        'logicalId': moduleRoot.key.content.id,
        'revisionId': moduleRoot.key.revision,
        'digest': moduleRoot.key.digest,
      });
      final linked = await Fixture15.open(client: true);
      try {
        await AlchemistInstall(linked.c.capsules!, reader).install(exact);
        expect(
          await LocalCatalogSource.installedRevision(
            linked.c.capsules!,
            moduleRoot,
          ),
          isTrue,
        );
      } finally {
        await linked.close();
      }

      expect(received.blocks.last.media!.localPath, isNull);
      final videoDescriptor = await reader.call('media.getDescriptor', {
        'assetRevisionId': received.blocks.last.media!.assetId,
      });
      var interrupted = false;
      await expectLater(
        AlchemistInstall(client.c.capsules!, reader).downloadAsset(
          videoDescriptor,
          interrupted: () => interrupted,
          progress: (n, total) {
            if (n >= 262144) interrupted = true;
          },
        ),
        throwsFormatException,
      );
      final pausedStats = await ownerApi.call('test.stats', {});
      final downloaded = await diaryReader.resolveMedia(
        received.blocks.last.media!,
      );
      final resumedStats = await ownerApi.call('test.stats', {});
      expect(
        (resumedStats['downloaded'] as int) -
            (pausedStats['downloaded'] as int),
        await clip.length() - 262144,
        reason: 'new downloader resumes persisted aligned checkpoint',
      );
      expect(await downloaded!.length(), await clip.length());
      expect(await downloaded.readAsBytes(), padded);
      await diaryReader.authenticateReader('TEST_OWNER');
      final readsA = DiaryReadStore(
            author.db,
            readerId: diaryAuthor.readerScope,
          ),
          readsB = DiaryReadStore(client.db, readerId: diaryReader.readerScope);
      await readsA.load();
      await readsB.load();
      await readsA.progress(received, textEnd: true, page: 2);
      await diaryAuthor.synchronizeReads(readsA, [received]);
      await diaryReader.synchronizeReads(readsB, [received]);
      expect(readsB.isRead(received), isTrue);
      expect(readsB.state(received)['page'], 2);
      final prior = await ownerApi.call('entry.get', {'entryId': entry.id});
      final statsBefore = await ownerApi.call('test.stats', {});
      final changed = await diaryAuthor.publish(
        publishedDiary.copyWith(message: 'Только аннотация'),
        session,
        published: true,
      );
      final later = await ownerApi.call('entry.get', {'entryId': entry.id});
      expect(
        later['revision'],
        prior['revision'],
        reason: 'metadata edit preserves immutable body',
      );
      expect(
        (await ownerApi.call('test.stats', {}))['uploaded'],
        statsBefore['uploaded'],
      );
      await diaryAuthor.publish(changed, session, published: false);
      expect((await diaryReader.feed()).entries, isEmpty);
      expect(
        await downloaded.exists(),
        isTrue,
        reason: 'withdrawal preserves verified offline bytes',
      );
      expect(errors, isEmpty);
    } finally {
      http.close(force: true);
      process.kill();
      await process.exitCode;
      await author.close();
      await client.close();
    }
  });
}
