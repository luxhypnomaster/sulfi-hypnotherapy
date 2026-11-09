import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_publication_diff.dart';

import 'task15_diary_test.dart' show entry15;

void main() {
  test('server handoff fixtures are actual Dart domain projections and retain explicit public extensions', () async {
    final r = ContentRevision.create(
      const ContentKey(ContentType.track, 'fixture'),
      {
        'id': 'fixture',
        'title': 'Аудио',
        'contentHash':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      },
      declaredVersion: 1,
    );
    final e = entry15(
      'fixture',
      blocks: [
        const DiaryBlock(id: 'text', type: DiaryBlockType.text, text: 'Текст'),
        const DiaryBlock(
          id: 'image',
          type: DiaryBlockType.image,
          width: 1,
          height: 1,
          media: DiaryMedia(
            assetId: 'image',
            mime: 'image/png',
            bytes: 20,
            hash: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            localPath: '/not-public',
          ),
        ),
      ],
    );
    final enriched = e.copyWith(
      extra: {
        ...e.extra,
        'contentLinks': [ContentLink(r.key, ContentLinkAction.install).toMap()],
        'publicExtensions': {'futureOptional': true},
        'privateRoot': 'must-stay-local',
      },
    );
    final manifest = diaryPublicManifest(enriched);
    expect(jsonEncode(manifest), isNot(contains('privateRoot')));
    expect(jsonEncode(manifest), isNot(contains('/not-public')));
    expect(DiaryEntry.fromMap(manifest).extra['publicExtensions'], {
      'futureOptional': true,
    });
    final fixtures = {
      'DiaryPublication': manifest,
      'ContentRevision': r.toMap(),
      'ContentLink': enriched.contentLinks.single.toMap(),
      'Feed': {
        'entries': [manifest],
        'revision': '"1"',
        'nextPage': null,
      },
    };
    final expected = jsonDecode(
      await File('docs/task15/SERVER_HANDOFF/EXAMPLES.json').readAsString(),
    );
    expect(fixtures, expected);
  });
}
