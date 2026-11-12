// Real Dart services + production JS domain over loopback. Controlled credentials;
// this is explicitly not Google consent, live Drive or physical Android QA.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_announcement.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_install.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('G3 catalog-before-diary: failure keeps local draft; exact 3-track announce reuses committed bytes, selective client install', () async {
    final process = await Process.start('node', [
      'server/alchemist/test/support/flutter-bridge.mjs',
    ]);
    process.stderr.drain<void>();
    final port = int.parse(
      await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first,
    );
    HttpOverrides.global = null;
    final http = HttpClient();
    var failUpload = true;
    Future<DiaryResponse> connection(
      String method,
      Uri uri,
      Map<String, String> headers,
      String? body,
    ) async {
      if (failUpload && jsonDecode(body!)['operation'] == 'media.beginUpload') {
        throw const SocketException('controlled DNS outage');
      }
      final request = await http.postUrl(Uri.parse('http://127.0.0.1:$port'));
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body!));
      final response = await request.close();
      return DiaryResponse(
        response.statusCode,
        await utf8.decoder.bind(response).join(),
      );
    }

    final f = await Fixture15.open(),
        client = await Fixture15.open(client: true);
    SessionController? c;
    DiaryController? diary;
    try {
      final module = await seed15(f);
      final endpoint = Uri.parse(
        'https://script.google.com/macros/s/UNIT/exec',
      );
      final diaryApi = AlchemistDiaryApi(
        endpoint,
        capsules: f.c.capsules!,
        media: DiaryMediaStore(
          Directory('${f.root.path}/diary'),
          pick: (_) async => null,
          probe: (_) async => null,
        ),
        connection: connection,
      );
      final session = await diaryApi.authenticate('TEST_OWNER');
      diary = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
        policy: f.c.policy,
        api: diaryApi,
      );
      c = SessionController(
        repository: f.c.repository,
        library: f.c.library,
        capsules: f.c.capsules,
        diary: diary,
      );
      final remote = AlchemistApi(
        endpoint,
        connection: connection,
        credential: () async => 'TEST_OWNER',
        identityScope: () => diaryApi.readerScope,
        maxAttempts: 1,
      );
      final catalog = AlchemistCatalog(c, api: remote),
          reader = AlchemistApi(endpoint, connection: connection);
      final root = (await LocalCatalogSource.currentIndex(f.c.capsules!))
          .singleWhere((r) => r.key.content.id == module.id);
      final draft = await catalog.prepare(root);
      draft['card']['shortAnnotation'] = 'Три точных трека';
      draft['card']['visibility'] = 'public';
      await catalog.save(draft);
      final entry = await prepareCatalogAnnouncement(catalog, draft),
          duplicate = await prepareCatalogAnnouncement(catalog, draft);
      expect(duplicate.id, entry.id);
      expect(
        await reader.call('feed.list', {}),
        containsPair('entries', isEmpty),
      );
      diaryApi.beforePublication = (e) =>
          commitAnnouncementDependency(catalog, e);
      await expectLater(
        diaryApi.publish(entry, session, published: true),
        throwsA(isA<DiaryApiException>()),
      );
      expect(
        (await diary.authorRepository!.entries()).single.status,
        DiaryStatus.draft,
      );
      expect((await reader.call('feed.list', {}))['entries'], isEmpty);
      failUpload = false;
      final published = await diaryApi.publish(entry, session, published: true);
      expect(published.status, DiaryStatus.published);
      final stats = await remote.call('test.stats', {});
      expect(stats['blobs'], 3);
      final again = await prepareCatalogAnnouncement(
        catalog,
        (await catalog.drafts()).single,
      );
      expect(again.id, isNot(entry.id));
      expect(again.contentLinks.single.key.token, root.key.token);
      await diaryApi.publish(again, session, published: true);
      expect(
        (await remote.call('test.stats', {}))['uploaded'],
        stats['uploaded'],
      );
      final reference = await reader.call('catalog.resolveReference', {
        'logicalId': root.key.content.id,
        'revisionId': root.key.revision,
        'digest': root.key.digest,
      });
      final installer = AlchemistInstall(client.c.capsules!, reader);
      await installer.install(reference);
      await client.c.reload();
      expect(client.c.assets, hasLength(3));
      final before = await remote.call('test.stats', {});
      await installer.install(reference);
      expect(
        (await remote.call('test.stats', {}))['downloaded'],
        before['downloaded'],
      );
      for (final asset in client.c.assets) {
        expect(await client.c.library.fileFor(asset).exists(), true);
      }
      expect(
        await LocalCatalogSource.installedRevision(client.c.capsules!, root),
        true,
      );
    } finally {
      c?.dispose();
      diary?.dispose();
      http.close(force: true);
      process.kill();
      await f.close();
      await client.close();
    }
  });
}
