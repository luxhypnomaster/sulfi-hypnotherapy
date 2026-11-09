import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';

void main() {
  test('exact resolver: shared dependency once, missing, cycle, conflicting versions and digests', () {
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    RevisionKey key(String id, String rev, {String digest = hash}) =>
        RevisionKey(ContentKey(ContentType.module, id), rev, digest);
    ContentRevision node(String id, String rev, List<RevisionKey> deps) =>
        ContentRevision(key: key(id, rev), payload: {}, dependencies: deps);
    final audio = node('a', '1', []);
    final m1 = node('m1', '1', [audio.key]);
    final m2 = node('m2', '1', [audio.key]);
    final root = node('root', '1', [m1.key, m2.key]);
    expect(
      resolveContent(root.key, [
        root,
        m2,
        audio,
        m1,
      ]).revisions.map((r) => r.key.content.id),
      ['a', 'm1', 'm2', 'root'],
    );
    expect(
      () => resolveContent(root.key, [root, m1, m2]),
      throwsFormatException,
    );
    final cycle = node('cycle', '1', [key('cycle', '1')]);
    expect(() => resolveContent(cycle.key, [cycle]), throwsFormatException);
    final a2 = node('a', '2', []);
    final conflict = node('root', '1', [audio.key, a2.key]);
    expect(
      () => resolveContent(conflict.key, [conflict, audio, a2]),
      throwsFormatException,
    );
    final forged = ContentRevision(
      key: key(
        'a',
        '1',
        digest:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      payload: {},
    );
    expect(
      () => resolveContent(audio.key, [audio, forged]),
      throwsFormatException,
    );
  });
  test('immutable content revision separates logical, exact and occurrence IDs; fork parent is exact', () {
    final official = ContentRevision.create(
      const ContentKey(ContentType.module, 'official'),
      {'id': 'official', 'origin': 'supplied', 'title': 'Оригинал'},
      declaredVersion: 1,
    );
    final fork = official.fork('personal-copy');
    expect(fork.key.content.id, isNot(official.key.content.id));
    expect(fork.parent!.toMap(), official.key.toMap());
    expect(fork.payload['origin'], 'personal');
    expect(official.payload['origin'], 'supplied');
    expect(ContentRevision.fromMap(fork.toMap()).key.digest, fork.key.digest);
    final damaged = fork.toMap();
    damaged['payload'] = {'title': 'подмена'};
    expect(() => ContentRevision.fromMap(damaged), throwsFormatException);
    final rebound = official.toMap();
    rebound['logicalId'] = 'other';
    expect(() => ContentRevision.fromMap(rebound), throwsFormatException);
    expect(() => official.fork('official'), throwsArgumentError);
  });
  test('diary exact ContentLink and future fields survive old entry/copy/serialization; live publishing stays blocked', () {
    final old = DiaryEntry(
      id: 'old',
      message: 'Запись',
      body: 'Текст',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(DiaryEntry.fromMap(old.toMap()).contentLinks, isEmpty);
    final r = ContentRevision.create(
      const ContentKey(ContentType.track, 'track'),
      {'title': 'Трек'},
    );
    final link = ContentLink(
      r.key,
      ContentLinkAction.install,
      extra: {'future': true},
    );
    final map = {
      ...old.toMap(),
      'futureRoot': {'keep': 1},
      'contentLinks': [
        link.toMap(),
        {'type': 'future-v3', 'other': 'kept'},
      ],
    };
    final entry = DiaryEntry.fromMap(map);
    expect(entry.contentLinks.single.key.toMap(), r.key.toMap());
    expect(entry.copyWith(message: 'Другая запись').toMap()['futureRoot'], {
      'keep': 1,
    });
    expect(entry.toMap()['contentLinks'], map['contentLinks']);
    expect(entry.contentLinks.single.extra, {'future': true});
    expect(entry.publicationError, contains('локально'));
    expect(entry.toMap(public: true).containsKey('futureRoot'), false);
  });
}
