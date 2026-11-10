import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
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
