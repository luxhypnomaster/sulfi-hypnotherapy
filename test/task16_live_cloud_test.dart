import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_install.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_http.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';

import 'support/task15_fixture.dart';

// Opt-in only: trusted manual-main workflow pins/reviews this exact source.
// No refresh token, arbitrary endpoint, real user files or APK login is used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  test(
    'LIVE Google Drive: actual Flutter author services → GAS → client installer',
    () async {
      HttpOverrides.global = null;
      final endpoint = Uri.parse(env['SULFI_LIVE_ENDPOINT']!);
      final tokenFile = File(env['SULFI_LIVE_CREDENTIAL_FILE']!);
      final prefix = env['SULFI_LIVE_PREFIX']!;
      if (!RegExp(r'^task16e2e_[0-9_]+$').hasMatch(prefix)) {
        throw const FormatException('Unapproved live fixture prefix');
      }
      final evidenceFile = File(env['SULFI_LIVE_EVIDENCE']!);
      final phases = <String>[];
      final metrics = <String, int>{};
      final artifacts = <String, dynamic>{};
      final redirects = <String, ({String? operation, int bytes})>{};
      final maxResponseMs = <String, int>{};
      String? lastOperation;
      var uploaded = 0, downloaded = 0;
      var stop = false, losePublishReply = false;
      Future<void> persist() async {
        await evidenceFile.writeAsString(
          jsonEncode({
            'kind': 'REAL_GOOGLE_DRIVE_FLUTTER_SERVICES',
            'physicalAndroid': 'NOT_RUN',
            'androidSdkLogin': 'NOT_RUN_CI_IDENTITY',
            'prefix': prefix,
            'phases': phases,
            'requests': metrics,
            'uploadedBytes': uploaded,
            'downloadedBytes': downloaded,
            'artifacts': artifacts,
            'lastOperation': lastOperation,
            'maxResponseMs': maxResponseMs,
          }),
        );
      }

      Future<void> checkpoint(String phase) async {
        phases.add(phase);
        await persist();
        // Fixed technical labels only, never tokens or content.
        // ignore: avoid_print
        print('LIVE_PHASE=$phase');
      }

      Future<DiaryResponse> wire(
        String method,
        Uri uri,
        Map<String, String> headers,
        String? body,
      ) async {
        final q = body == null ? null : jsonDecode(body) as Map;
        final context = redirects.remove(uri.toString());
        final op = q?['operation'] as String? ?? context?.operation;
        final sentBytes = q?['operation'] == 'media.uploadChunk'
            ? base64Decode(q!['parameters']['base64']).length
            : context?.bytes ?? 0;
        lastOperation = op;
        await persist();
        final watch = Stopwatch()..start();
        if (op != null) metrics[op] = (metrics[op] ?? 0) + 1;
        final response = await const AlchemistHttp().request(
          method,
          uri,
          headers,
          body,
        );
        watch.stop();
        if (op != null &&
            watch.elapsedMilliseconds > (maxResponseMs[op] ?? 0)) {
          maxResponseMs[op] = watch.elapsedMilliseconds;
        }
        if ([302, 303].contains(response.status) &&
            response.headers['location'] != null) {
          redirects[response.headers['location']!] = (
            operation: op,
            bytes: sentBytes,
          );
        }
        await persist();
        if (response.status == 200 && response.body.startsWith('{')) {
          final r = jsonDecode(response.body) as Map;
          if (r['ok'] == true) {
            if (op == 'media.uploadChunk') {
              uploaded += sentBytes;
            }
            if (op == 'media.downloadChunk') {
              downloaded += base64Decode(r['result']['base64']).length;
            }
            if (losePublishReply && op == 'catalog.publish') {
              losePublishReply = false;
              throw const SocketException(
                'Injected lost reply after real commit',
              );
            }
          }
        }
        return response;
      }

      final owner = AlchemistApi(
        endpoint,
        connection: wire,
        credential: () => tokenFile.readAsString(),
        maxAttempts: 1,
      );
      final reader = AlchemistApi(endpoint, connection: wire);
      Future<Duration?> actualProbe(String path) async {
        final p = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'json',
          path,
        ]);
        if (p.exitCode != 0) return null;
        final seconds = double.tryParse(
          jsonDecode(p.stdout as String)['format']['duration'] as String,
        );
        return seconds == null
            ? null
            : Duration(milliseconds: (seconds * 1000).round());
      }

      final author = await Fixture15.open(probe: actualProbe),
          client = await Fixture15.open(client: true, probe: actualProbe);
      final cards = <Map<String, dynamic>>[];
      final service = AlchemistCatalog(author.c, api: owner);
      try {
        await checkpoint('STARTED');
        // 50sec/22050Hz mono PCM: genuine >2MiB WAV with deterministic synthetic
        // low-amplitude noise, not speech or the Sulfi voice. Noncompressible ZIP.
        const samples = 50 * 22050;
        final wave = ByteData(44 + samples * 2);
        void ascii(int offset, String value) {
          for (var i = 0; i < value.length; i++) {
            wave.setUint8(offset + i, value.codeUnitAt(i));
          }
        }

        ascii(0, 'RIFF');
        wave.setUint32(4, wave.lengthInBytes - 8, Endian.little);
        ascii(8, 'WAVE');
        ascii(12, 'fmt ');
        wave.setUint32(16, 16, Endian.little);
        wave.setUint16(20, 1, Endian.little);
        wave.setUint16(22, 1, Endian.little);
        wave.setUint32(24, 22050, Endian.little);
        wave.setUint32(28, 44100, Endian.little);
        wave.setUint16(32, 2, Endian.little);
        wave.setUint16(34, 16, Endian.little);
        ascii(36, 'data');
        wave.setUint32(40, samples * 2, Endian.little);
        var random = prefix.codeUnits.fold<int>(
          1,
          (n, x) => (n * 31 + x) & 0x7fffffff,
        );
        for (var i = 0; i < samples; i++) {
          random ^= (random << 13) & 0xffffffff;
          random ^= random >> 17;
          random ^= (random << 5) & 0xffffffff;
          random &= 0xffffffff;
          wave.setInt16(44 + i * 2, (random & 2047) - 1024, Endian.little);
        }
        final audioBytes = <List<int>>[
          wave.buffer.asUint8List(),
          [
            ...await File('test/fixtures/android_aac_isom.m4a').readAsBytes(),
            0,
            0,
            0,
            9,
            102,
            114,
            101,
            101,
            1,
          ],
          [
            ...await File('test/fixtures/android_aac_isom.m4a').readAsBytes(),
            0,
            0,
            0,
            9,
            102,
            114,
            101,
            101,
            2,
          ],
        ];
        final steps = <SessionStep>[];
        for (var i = 0; i < audioBytes.length; i++) {
          final bytes = audioBytes[i], ext = i == 0 ? 'wav' : 'm4a';
          final file = File(
            '${author.c.library.directory.path}/$prefix-$i.$ext',
          );
          await file.writeAsBytes(bytes);
          final asset = AudioAsset(
            id: '${prefix}_audio_$i',
            title: 'Технический тест №16: аудио $i',
            filePath: file.uri.pathSegments.last,
            durationMs: i == 0 ? 50000 : 12000,
            format: ext,
            createdAt: DateTime.utc(2026, 11, 10),
            category: AudioCategory.freeform,
            fileSizeBytes: bytes.length,
            contentHash: sha256.convert(bytes).toString(),
            section: LibrarySection.personal,
            origin: 'personal',
          );
          await author.c.library.save(asset);
          steps.add(
            SessionStep(
              id: '${prefix}_step_$i',
              kind: StepKind.audio,
              title: asset.title,
              audioAssetId: asset.id,
              durationMs: asset.durationMs,
            ),
          );
          if (i < 2) {
            steps.add(
              SessionStep(
                id: '${prefix}_pause_$i',
                kind: StepKind.silence,
                title: 'Пауза',
                durationMs: 2000,
              ),
            );
          }
        }
        final module = ModuleDefinition(
          id: '${prefix}_module',
          title: 'Технический тест №16: модуль',
          items: steps,
        );
        await author.c.modules.save(module);
        await author.c.reload();
        final index = await LocalCatalogSource.currentIndex(author.c.capsules!);
        final track = index.singleWhere(
          (r) => r.key.content.id == '${prefix}_audio_0',
        );
        final moduleRoot = index.singleWhere(
          (r) => r.key.content.id == module.id,
        );
        Future<Map<String, dynamic>> prepare(ContentRevision r) async {
          final c = await service.prepare(r);
          cards.add(c);
          c['card']['shortAnnotation'] =
              'Синтетический контроль №16, не терапевтическая запись';
          c['card']['visibility'] = 'public';
          return c;
        }

        final trackCard = await prepare(track);
        await expectLater(
          service.publish(
            trackCard,
            interrupted: () => stop,
            progress: (n, total) {
              if (n >= 262144) stop = true;
            },
          ),
          throwsFormatException,
        );
        expect(uploaded, 262144);
        await checkpoint('REAL_AUDIO_UPLOAD_PAUSED');
        stop = false;
        await service.publish(trackCard);
        expect(uploaded, audioBytes[0].length);
        final publicTrack = await reader.call('catalog.get', {
          'catalogItemId': trackCard['catalogItemId'],
        });
        final installer = AlchemistInstall(client.c.capsules!, reader);
        await installer.install(publicTrack);
        expect(
          await LocalCatalogSource.installedRevision(client.c.capsules!, track),
          true,
        );
        artifacts['wav'] = {
          'bytes': audioBytes[0].length,
          'sha256': sha256.convert(audioBytes[0]).toString(),
          'durationMs': 50000,
        };
        await checkpoint('REAL_ANNOTATED_TRACK_INSTALLED');
        final moduleCard = await prepare(moduleRoot),
            beforeModuleDownload = downloaded;
        losePublishReply = true;
        await expectLater(
          service.publish(moduleCard),
          throwsA(isA<SocketException>()),
        );
        await service.publish(moduleCard);
        await installer.install(
          await reader.call('catalog.get', {
            'catalogItemId': moduleCard['catalogItemId'],
          }),
        );
        expect(
          downloaded - beforeModuleDownload,
          audioBytes[1].length + audioBytes[2].length,
        );
        await client.c.reload();
        expect(client.c.assets.length, 3);
        expect(client.c.modules.entries.single.items.length, 5);
        await checkpoint('REAL_MODULE_MISSING_ONLY_INSTALL_AND_RECEIPT_REPLAY');
        final beforeMetaBytes = uploaded;
        moduleCard['card']['shortAnnotation'] =
            'Проверенная metadata-only аннотация';
        await service.publish(moduleCard);
        expect(uploaded, beforeMetaBytes);
        expect(
          (await reader.call('catalog.get', {
            'catalogItemId': moduleCard['catalogItemId'],
          }))['immutableRevisionId'],
          moduleRoot.key.revision,
        );
        await checkpoint('REAL_METADATA_ONLY_EDIT');
        final template = SessionTemplate(
          id: '${prefix}_template',
          name: 'Контрольный шаблон №16',
          plan: SessionPlan(steps: steps),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        await author.c.repository.saveTemplate(template);
        final templateRoot = (await LocalCatalogSource.currentIndex(
          author.c.capsules!,
        )).singleWhere((r) => r.key.content.id == template.id);
        final templateCard = await prepare(templateRoot);
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
          true,
        );
        final zip = await author.c.capsules!.export(moduleId: module.id);
        expect(await zip.length(), greaterThan(262144));
        final package = await service.preparePackage(zip);
        cards.add(package);
        package['card']['shortAnnotation'] = 'Контрольный ZIP №16';
        package['card']['visibility'] = 'public';
        await service.publish(package);
        await installer.install(
          await reader.call('catalog.get', {
            'catalogItemId': package['catalogItemId'],
          }),
        );
        artifacts['zip'] = {
          'bytes': await zip.length(),
          'sha256': (await sha256.bind(zip.openRead()).first).toString(),
        };
        await checkpoint('REAL_TEMPLATE_AND_LARGE_ZIP_INSTALLED');
        final media = DiaryMediaStore(
          Directory('${author.root.path}/live-diary'),
          pick: (_) async => null,
          probe: (_) async => const Duration(seconds: 12),
          videoProbe: (_) async => (width: 64, height: 48, durationMs: 1000),
        );
        final png = File('${author.root.path}/pixel.png');
        await png.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAC0lEQVR4nGNgQAcAABIAAXfx+gAAAAAASUVORK5CYII=',
          ),
        );
        final image = await media.importFile(DiaryBlockType.image, (
          path: png.path,
          name: 'pixel.png',
        ));
        final audio = await media.importFile(DiaryBlockType.audio, (
          path: 'test/fixtures/android_aac_isom.m4a',
          name: 'sample.m4a',
        ));
        final clip = File('${author.root.path}/large.mp4');
        final atom = ByteData(2 * 1024 * 1024);
        atom.setUint32(0, atom.lengthInBytes);
        atom.buffer.asUint8List().setRange(4, 8, 'free'.codeUnits);
        atom.setUint32(atom.lengthInBytes - 4, random);
        await clip.writeAsBytes([
          ...await File('test/fixtures/task16_video.mp4').readAsBytes(),
          ...atom.buffer.asUint8List(),
        ]);
        final video = await media.importFile(DiaryBlockType.video, (
          path: clip.path,
          name: 'large.mp4',
        ));
        final entry = DiaryEntry(
          id: '${prefix}_diary',
          title: 'Контрольный дневник №16',
          message: 'Синтетические медиа, не личные записи',
          extra: {
            'contentLinks': [
              ContentLink(moduleRoot.key, ContentLinkAction.install).toMap(),
            ],
          },
          blocks: [
            const DiaryBlock(
              id: 'text',
              type: DiaryBlockType.text,
              text: 'Синтетический текст №16',
            ),
            image,
            audio,
            video,
          ],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final diary = AlchemistDiaryApi(
          endpoint,
          capsules: author.c.capsules!,
          media: media,
          connection: wire,
        );
        await diary.enqueuePublication(entry, published: true);
        final session = await diary.authenticate(
          await tokenFile.readAsString(),
        );
        expect(await diary.flushPending(session), 1);
        final clientMedia = DiaryMediaStore(
          Directory('${client.root.path}/live-diary'),
          pick: (_) async => null,
          probe: (_) async => null,
        );
        final diaryReader = AlchemistDiaryApi(
          endpoint,
          capsules: client.c.capsules!,
          media: clientMedia,
          connection: wire,
        );
        final page = await diaryReader.feed();
        final received = page.entries.singleWhere((e) => e.id == entry.id);
        expect(received.blocks.map((b) => b.type), [
          DiaryBlockType.text,
          DiaryBlockType.image,
          DiaryBlockType.audio,
          DiaryBlockType.video,
        ]);
        final descriptor = await reader.call('media.getDescriptor', {
          'assetRevisionId': received.blocks.last.media!.assetId,
        });
        var pauseDownload = false;
        await expectLater(
          installer.downloadAsset(
            descriptor,
            interrupted: () => pauseDownload,
            progress: (n, total) {
              if (n >= 262144) pauseDownload = true;
            },
          ),
          throwsFormatException,
        );
        final beforeResume = downloaded;
        for (final block in received.blocks.where((b) => b.media != null)) {
          final file = (await diaryReader.resolveMedia(block.media!))!;
          expect(await file.length(), block.media!.bytes);
          expect(
            (await sha256.bind(file.openRead()).first).toString(),
            block.media!.hash,
          );
        }
        // Only remaining video bytes plus the tiny PNG/AAC were requested.
        expect(downloaded - beforeResume, lessThan(await clip.length() + 8192));
        artifacts['video'] = {
          'bytes': await clip.length(),
          'sha256': (await sha256.bind(clip.openRead()).first).toString(),
        };
        expect(received.contentLinks.single.key.digest, moduleRoot.key.digest);
        await checkpoint(
          'REAL_DIARY_IMAGE_AUDIO_VIDEO_CONTENTLINK_AND_DOWNLOAD_RESUME',
        );
        final privateId = '${prefix}_private';
        await owner.call('entry.createDraft', {
          'requestId': '${prefix}_private_create',
          'entry': {
            'id': privateId,
            'title': 'Private synthetic',
            'blocks': [
              {'id': 'p', 'type': 'text', 'text': 'Never public'},
            ],
          },
          'visibility': 'private',
        });
        await expectLater(
          reader.call('entry.get', {'entryId': privateId}),
          throwsA(
            isA<AlchemistApiException>().having((e) => e.status, 'status', 404),
          ),
        );
        await expectLater(
          reader.call('catalog.createDraft', {
            'requestId': '${prefix}_negative',
          }),
          throwsA(
            isA<AlchemistApiException>().having((e) => e.status, 'status', 403),
          ),
        );
        await checkpoint('REAL_PRIVATE_AND_ANONYMOUS_MUTATION_DENIED');
        final published = DiaryEntry.fromMap(
          Map<String, dynamic>.from(
            jsonDecode(
              (await author.db.query(
                    'diary_author',
                    where: 'id=?',
                    whereArgs: [entry.id],
                  )).single['payload']
                  as String,
            ),
          ),
        );
        await diary.publish(published, session, published: false);
        for (final card in cards.reversed) {
          await service.transition(card, 'archive');
        }
        await expectLater(
          reader.call('media.getDescriptor', {
            'assetRevisionId': descriptor['assetRevisionId'],
          }),
          throwsA(
            isA<AlchemistApiException>().having((e) => e.status, 'status', 404),
          ),
        );
        expect(
          await LocalCatalogSource.installedRevision(
            client.c.capsules!,
            moduleRoot,
          ),
          true,
        );
        await checkpoint(
          'REAL_WITHDRAW_DENIES_NEW_BYTES_OFFLINE_COPY_RETAINED',
        );
        await checkpoint('SERVICE_E2E_PASS_NOT_ANDROID_APK_QA');
      } finally {
        await author.close();
        await client.close();
      }
    },
    skip: env['SULFI_LIVE_ENDPOINT'] == null,
    timeout: const Timeout(Duration(minutes: 50)),
  );
}
