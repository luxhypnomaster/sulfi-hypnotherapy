// Synthetic domain regressions, NOT a native UI upgrade or real Google login.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'support/task15_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('16V legacy APK24 draft scope is readable only by same verified MASTER without row/media rewrite', () async {
    final f = await Fixture15.open();
    var subject = 'owner-a', role = 'MASTER';
    final api = AlchemistDiaryApi(
      Uri.parse('https://script.google.com/macros/s/UNIT/exec'),
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, body) async => DiaryResponse(
        200,
        jsonEncode({
          'ok': true,
          'status': 200,
          'result': {
            'subject': subject,
            'role': role,
            'expiresAt':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          },
        }),
      ),
    );
    final author = DiaryAuthorRepository(f.db);
    final d = DiaryController(
      AlchemistDiaryRepository(f.db, scope: () => api.readerScope),
      api: api,
      policy: f.c.policy,
      authorRepository: author,
    );
    try {
      final now = DateTime.now().toUtc();
      final media = File('${f.root.path}/diary/existing.m4a');
      await media.parent.create(recursive: true);
      await File('test/fixtures/android_aac_isom.m4a').copy(media.path);
      final bytes = await media.readAsBytes();
      for (final owner in ['owner-a', 'owner-b']) {
        await author.save(
          DiaryEntry(
            id: 'legacy-$owner',
            message: 'Existing private work',
            createdAt: now,
            updatedAt: now,
            extra: {'_alchemistScope': 'google:$owner'},
            blocks: [
              const DiaryBlock(
                id: 'text-first',
                type: DiaryBlockType.text,
                text: 'Kept first',
              ),
              DiaryBlock(
                id: 'audio-second',
                type: DiaryBlockType.audio,
                media: DiaryMedia(
                  assetId: 'existing',
                  mime: 'audio/mp4',
                  bytes: bytes.length,
                  localPath: media.path,
                ),
              ),
            ],
          ),
        );
      }
      final before = await f.db.query('diary_author', orderBy: 'id');
      await d.load();
      expect(d.drafts, isEmpty, reason: 'Guest must not see author work');
      Future<void> verify() async {
        await api.authenticateReader('controlled-test-token');
        f.c.policy.applyVerifiedServerRole(api.verifiedRole);
        await d.load();
      }

      await verify();
      expect(d.drafts.map((e) => e.id), ['legacy-owner-a']);
      expect(d.drafts.single.blocks.map((b) => b.id), [
        'text-first',
        'audio-second',
      ]);
      subject = 'owner-b';
      await verify();
      expect(d.drafts.map((e) => e.id), ['legacy-owner-b']);
      role = 'CLIENT';
      await verify();
      expect(d.drafts, isEmpty);
      api.clearSession();
      f.c.policy.applyVerifiedServerRole(null);
      await d.load();
      expect(d.drafts, isEmpty);
      expect(await f.db.query('diary_author', orderBy: 'id'), before);
      expect(await media.readAsBytes(), bytes);
    } finally {
      d.dispose();
      await f.close();
    }
  });
}
