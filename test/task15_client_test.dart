import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/diary_publication.dart';
import 'package:sulfi_hypnotherapy/services/diary_contract_provider.dart';
import 'package:sulfi_hypnotherapy/services/diary_contract_cache.dart';
import 'package:sulfi_hypnotherapy/services/diary_contract_outbox.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/diary_publication_diff.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/diary_content_link.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'support/task15_provider.dart';
import 'task15_export_test.dart' show seed15;
import 'task15_diary_test.dart' show entry15;

void main() {
  testWidgets(
    'CLI independent stores author -> immutable fake provider -> client media/read/exact install/player; reannounce/expiry/private isolation',
    (t) async {
      final a = (await t.runAsync(Fixture15.open))!,
          b = (await t.runAsync(() => Fixture15.open(client: true)))!;
      final server = FakePublicationServer(), repo = DiaryRepository(b.db);
      final reader = DiaryController(
        repo,
        policy: b.c.library.policy,
        authorRepository: DiaryAuthorRepository(b.db),
        allowDebugAuthor: true,
        clock: () => DateTime.utc(2026, 11, 9),
      );
      final author = server.client(author: true),
          client = server.client(author: false);
      late DiaryEntry e;
      late RevisionKey trackKey;
      try {
        await t.runAsync(() async {
          final module = await seed15(a);
          await DiaryAuthorRepository(a.db).save(
            entry15('secret').copyWith(
              status: DiaryStatus.draft,
              extra: {'privateNote': 'OWNER_ONLY'},
            ),
          );
          final zip = await a.c.capsules!.export(moduleId: module.id);
          final source = await LocalCatalogSource.open(a.c.capsules!, zip);
          final root = source.revisions
              .singleWhere((r) => r.key.content.type == ContentType.module)
              .key;
          trackKey = source.revisions
              .firstWhere((r) => r.key.content.type == ContentType.track)
              .key;
          final currentIndex = await LocalCatalogSource.currentIndex(
            a.c.capsules!,
          );
          expect(
            currentIndex
                .singleWhere((r) => r.key.content.type == ContentType.module)
                .key
                .toMap(),
            root.toMap(),
            reason: 'author picker and importer must use SAME dependency-inclusive key',
          );
          final bytes = await zip.readAsBytes(),
              zipHash = sha256.convert(bytes).toString();
          await author.upload(zipHash, bytes, idempotencyKey: 'zip');
          server.packages[root.token] = zipHash;
          server.packages[trackKey.token] = zipHash;
          await source.close();
          final voiceBytes = await File('test/fixtures/android_aac_isom.m4a')
              .readAsBytes();
          final voiceHash = sha256.convert(voiceBytes).toString();
          await author.upload(voiceHash, voiceBytes, idempotencyKey: 'voice');
          final image = base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
          );
          final imageHash = sha256.convert(image).toString();
          await author.upload(imageHash, image, idempotencyKey: 'image');
          e = entry15(
            'public',
            blocks: [
              const DiaryBlock(
                id: 'text',
                type: DiaryBlockType.text,
                text: 'Текст для читателя',
              ),
              DiaryBlock(
                id: 'image',
                type: DiaryBlockType.image,
                width: 1,
                height: 1,
                media: DiaryMedia(
                  assetId: 'img',
                  mime: 'image/png',
                  bytes: image.length,
                  hash: imageHash,
                  localPath: '/author/private/photo.png',
                ),
              ),
              DiaryBlock(
                id: 'voice',
                type: DiaryBlockType.audio,
                durationMs: 65000,
                media: DiaryMedia(
                  assetId: 'voice',
                  mime: 'audio/mp4',
                  bytes: voiceBytes.length,
                  hash: voiceHash,
                  localPath: '/author/private/audio.m4a',
                ),
              ),
            ],
          );
          e = e.copyWith(
            extra: {
              ...e.extra,
              'privateNote': 'OWNER_ONLY',
              'contentLinks': [
                ContentLink(root, ContentLinkAction.install).toMap(),
                ContentLink(trackKey, ContentLinkAction.open).toMap(),
              ],
            },
          );
          final queue = DiaryContractOutbox(a.db, a.c.library.policy);
          await queue.enqueue(e, ifMatch: server.etag, requestId: 'publish-1');
          server.offline = true;
          await expectLater(queue.flush(author), throwsStateError);
          expect(
            await a.db.query(
              'app_settings',
              where: 'name LIKE ?',
              whereArgs: ['diary_contract_outbox:%'],
            ),
            hasLength(1),
          );
          server.offline = false;
          expect(await queue.flush(author), 1);
          expect(server.writes, 1);
          final snapshot = canonicalContent(server.manifests);
          expect(snapshot, isNot(contains('OWNER_ONLY')));
          expect(snapshot, isNot(contains('/author/')));
          expect(snapshot, isNot(contains('readerId')));
          final store = DiaryMediaStore(
            Directory('${b.root.path}/diary'),
            pick: (_) async => null,
            probe: (_) async => const Duration(seconds: 65),
          );
          await cacheContractDiary(client, repo, store);
          await reader.load();
          expect(reader.published, hasLength(1));
          expect(reader.authorWorkspace, false);
          reader.enterDebugAuthor();
          expect(reader.authorWorkspace, false);
          await expectLater(reader.saveDraft(e), throwsA(isA<Exception>()));
          final cached = reader.published.single;
          expect(cached.blocks.map((b) => b.id), ['text', 'image', 'voice']);
          for (final media
              in cached.blocks.map((b) => b.media).whereType<DiaryMedia>()) {
            expect(await store.file(media)!.exists(), true);
            expect(
              sha256.convert(await store.file(media)!.readAsBytes()).toString(),
              media.hash,
            );
          }
          await reader.textProgress(cached, 0, end: true);
          expect(reader.reads.isRead(cached), false);
          await reader.reads.progress(
            cached,
            audioId: 'voice',
            intervals: [
              [0, 65000],
            ],
            audioDone: true,
          );
          expect(reader.reads.isRead(cached), true);
          expect(canonicalContent(server.manifests), snapshot);
          expect(
            await a.db.query(
              'app_settings',
              where: 'name LIKE ?',
              whereArgs: ['diary_read:%'],
            ),
            isEmpty,
          );
          final package = File('${b.root.path}/selected.zip');
          await package.writeAsBytes(await client.blob(zipHash));
          final catalog = await LocalCatalogSource.open(b.c.capsules!, package);
          await catalog.install(await catalog.plan(root));
          await catalog.close();
          await b.c.reload();
          expect(b.c.assets, hasLength(3));
          expect(b.c.modules.entries.single.items, hasLength(5));
        });
        await show15(
          t,
          b,
          Scaffold(
            body: DiaryContentLink(
              link: ContentLink(trackKey, ContentLinkAction.open),
            ),
          ),
        );
        expect(find.text('Открыть'), findsOneWidget);
        await t.tap(find.text('Открыть'));
        await io15(t);
        expect(b.player.current?.id, trackKey.content.id);
        expect(b.player.playing, true);
        await capture15(t, 'g5-client-exact-content-open');
        await show15(t, b, DiaryScreen(diary: reader));
        expect(find.text('Новая запись'), findsNothing);
        expect(find.byTooltip('Редактировать запись'), findsNothing);
        expect(find.text('Локальный автор · тестовый режим'), findsNothing);
        await capture15(t, 'g5-client-journal');
        await t.runAsync(() async {
          final uploads = server.uploads;
          final quiet = e.copyWith(title: 'Тихая правка', version: 1);
          expect(DiaryDiffPlan.between(e, quiet).mediaUploads, 0);
          await author.publish(
            quiet,
            ifMatch: server.etag,
            idempotencyKey: 'quiet',
          );
          final store = DiaryMediaStore(
            Directory('${b.root.path}/diary'),
            pick: (_) async => null,
            probe: (_) async => const Duration(seconds: 65),
          );
          await cacheContractDiary(client, repo, store);
          await reader.load();
          expect(reader.reads.isRead(reader.published.single), true);
          final re = DiaryPublication.of(quiet)
              .changed(reannounce: true, now: DateTime.utc(2026, 11, 9))
              .apply(quiet);
          await author.publish(re, ifMatch: server.etag, idempotencyKey: 're');
          await cacheContractDiary(client, repo, store);
          await reader.load();
          expect(reader.currentEntry?.id, re.id);
          expect(reader.reads.isRead(reader.published.single), false);
          final expiry = DiaryPublication.of(re)
              .changed(validUntil: DateTime.utc(2026, 11, 8))
              .apply(re);
          await author.publish(
            expiry,
            ifMatch: server.etag,
            idempotencyKey: 'expire',
          );
          await cacheContractDiary(client, repo, store);
          await reader.load();
          expect(reader.currentEntry, null);
          expect(reader.published, hasLength(1));
          expect(server.uploads, uploads);
        });
      } finally {
        await t.pumpWidget(const SizedBox());
        reader.dispose();
        await t.runAsync(() async {
          await a.close();
          await b.close();
        });
      }
    },
  );
  test('SRV contract enforces permission, conditional publish, idempotent receipt, blob entitlement and SHA', () async {
    final s = FakePublicationServer();
    final author = s.client(author: true), client = s.client(author: false);
    final e = entry15('contract');
    await expectLater(
      client.publish(e, ifMatch: s.etag, idempotencyKey: 'unauthorized'),
      throwsA(isA<ContractFailure>().having((e) => e.status, 'status', 403)),
    );
    final oldEtag = s.etag;
    final etag = await author.publish(
      e,
      ifMatch: oldEtag,
      idempotencyKey: 'request',
    );
    expect(s.writes, 1);
    expect(
      await author.publish(e, ifMatch: oldEtag, idempotencyKey: 'request'),
      etag,
    );
    expect(s.writes, 1);
    await expectLater(
      author.publish(
        e.copyWith(title: 'Concurrent'),
        ifMatch: oldEtag,
        idempotencyKey: 'request2',
      ),
      throwsA(isA<ContractFailure>().having((e) => e.status, 'status', 412)),
    );
    await expectLater(
      author.publish(
        e.copyWith(title: 'Different body'),
        ifMatch: etag,
        idempotencyKey: 'request',
      ),
      throwsA(isA<ContractFailure>().having((e) => e.status, 'status', 409)),
    );
    final data = Uint8List.fromList([1, 2, 3]),
        hash = sha256.convert([1, 2, 3]).toString();
    await expectLater(
      client.upload(hash, data, idempotencyKey: 'x'),
      throwsA(isA<ContractFailure>().having((e) => e.status, 'status', 403)),
    );
    await author.upload(hash, data, idempotencyKey: 'blob');
    await author.upload(hash, data, idempotencyKey: 'blob');
    expect(s.uploads, 1);
    await expectLater(
      client.blob(hash),
      throwsA(isA<ContractFailure>().having((e) => e.status, 'status', 403)),
      reason: 'digest knowledge is not permission',
    );
    await expectLater(
      author.upload(hash, Uint8List.fromList([4]), idempotencyKey: 'bad'),
      throwsFormatException,
    );
    final ext = e.copyWith(
      extra: {
        ...e.extra,
        'publicExtensions': {
          'futureOptional': {'kept': true},
        },
        'privateFuture': 'notPublic',
      },
    );
    await author.publish(ext, ifMatch: s.etag, idempotencyKey: 'ext');
    final read = (await client.feed()).entries.single;
    expect(read.extra['publicExtensions'], {
      'futureOptional': {'kept': true},
    });
    expect(read.extra.containsKey('privateFuture'), false);
    expect(s.manifests[e.id], hasLength(2));
  });
}
