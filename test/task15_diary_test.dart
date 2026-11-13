import 'dart:convert';
import 'dart:io';

import 'package:sulfi_hypnotherapy/services/diary_audio.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';

import 'diary_multimedia_test.dart' show FakeAudio;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/diary_publication.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_read_state.dart';
import 'package:sulfi_hypnotherapy/services/diary_publication_diff.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';
import 'package:sulfi_hypnotherapy/ui/diary_editor.dart';
import 'package:sulfi_hypnotherapy/ui/diary_home.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';

DiaryEntry entry15(
  String id, {
  bool high = false,
  int day = 1,
  List<DiaryBlock>? blocks,
}) {
  final now = DateTime.utc(2026, 11, day);
  return DiaryPublication(
    cycle: 'cycle-$id',
    activatedAt: now,
    highPriority: high,
  ).apply(
    DiaryEntry(
      id: id,
      title: 'Название $id',
      message: 'Послание $id',
      body: 'Текст $id',
      blocks: blocks,
      status: DiaryStatus.published,
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  test('DAY categories, unknown fields, quiet edit, reannounce, manual/time/combined UTC expiry archive', () async {
    final f = await Fixture15.open();
    final d = DiaryController(
      DiaryRepository(f.db),
      clock: () => DateTime.utc(2026, 11, 9),
    );
    try {
      expect(diaryCategories.values.toList(), [
        'Развлечения',
        'Таро',
        'Объявления',
        'Запись на приём',
        'Критические обновления приложения',
        'Новые модули и программы',
      ]);
      var e = entry15('one').copyWith(
        extra: {
          ...entry15('one').extra,
          'futureRoot': {'retain': 9},
        },
      );
      final p = DiaryPublication.of(e);
      e = p.changed(categoryId: 'future').apply(e);
      expect(
        DiaryPublication.of(DiaryEntry.fromMap(e.toMap())).categoryName,
        'Неизвестная категория',
      );
      expect(e.toMap()['futureRoot'], {'retain': 9});
      await d.repository.cache([e], {}, '1');
      await d.load();
      expect(d.currentEntry?.id, e.id);
      expect(d.reads.isRead(e), false);
      await d.textProgress(e, 3, end: true);
      expect(d.currentEntry, null);
      expect(d.published.single.id, e.id);
      final quiet = e.copyWith(title: 'Правка', version: 1);
      await d.repository.cache([quiet], {}, '2');
      await d.load();
      expect(d.reads.isRead(quiet), true);
      final again = DiaryPublication.of(quiet)
          .changed(reannounce: true, now: DateTime.utc(2026, 11, 9))
          .apply(quiet)
          .copyWith(version: 2);
      expect(DiaryPublication.of(again).cycle, isNot(p.cycle));
      await d.repository.cache([again], {}, '3');
      await d.load();
      expect(d.currentEntry?.id, e.id);
      final read2 = DiaryReadStore(f.db, readerId: 'second-reader');
      await read2.load();
      expect(read2.isRead(e), false);
      final closed = DiaryPublication.of(again)
          .changed(authorClosed: true, validUntil: DateTime.utc(2026, 12))
          .apply(again)
          .copyWith(version: 3);
      await d.repository.cache([closed], {}, '4');
      await d.load();
      expect(d.currentEntry, null);
      expect(d.published, hasLength(1));
      final timed = DiaryPublication.of(again)
          .changed(validUntil: DateTime.parse('2026-11-09T03:00:00+03:00'))
          .apply(again)
          .copyWith(version: 4);
      await d.repository.cache([timed], {}, '5');
      await d.load();
      expect(d.currentEntry, null);
      final reopen = DiaryReadStore(f.db);
      await reopen.load();
      expect(reopen.readerId, d.reads.readerId);
      expect(reopen.isRead(e), true);
      expect(
        jsonEncode(diaryPublicManifest(again)),
        isNot(contains('readerId')),
      );
      expect(
        jsonEncode(diaryPublicManifest(again)),
        isNot(contains('futureRoot')),
      );
    } finally {
      d.dispose();
      await f.close();
    }
  });
  test('DAY deterministic rotation newest then normal/high fairness, stable build and explicit advance', () async {
    final f = await Fixture15.open();
    final d = DiaryController(
      DiaryRepository(f.db),
      clock: () => DateTime.utc(2026, 11, 9),
    );
    try {
      final list = [
        entry15('h1', high: true, day: 5),
        entry15('h2', high: true, day: 4),
        entry15('n1', day: 3),
        entry15('n2', day: 2),
      ];
      await d.repository.cache(list, {}, '1');
      await d.load();
      expect(diaryRotation(list, d.clock(), (_) => false).map((e) => e.id), [
        'h1',
        'n1',
        'h2',
        'n2',
      ]);
      expect(d.currentEntry?.id, 'h1');
      expect(d.currentEntry?.id, 'h1');
      d.rotateHome();
      expect(d.currentEntry?.id, 'n1');
    } finally {
      d.dispose();
      await f.close();
    }
  });
  test('DAY real heard intervals need EOF, seek jump not completion; persisted partial and mixed both media', () async {
    final f = await Fixture15.open();
    final r = DiaryReadStore(f.db, readerId: 'reader');
    await r.load();
    final e = entry15(
      'mixed',
      blocks: [
        const DiaryBlock(id: 'text', type: DiaryBlockType.text, text: 'Текст'),
        const DiaryBlock(
          id: 'audio',
          type: DiaryBlockType.audio,
          durationMs: 10000,
          media: DiaryMedia(
            assetId: 'a',
            mime: 'audio/mp4',
            bytes: 100,
            hash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
      ],
    );
    try {
      final h = HeardAudio();
      bool sample(
        int position,
        int time, {
        bool playing = true,
        bool eof = false,
        int epoch = 0,
      }) => h.sample(
        position: position,
        nowMs: time,
        playing: playing,
        completed: eof,
        duration: 10000,
        seekEpoch: epoch,
      );
      sample(0, 0);
      expect(sample(10000, 100, playing: false, eof: true, epoch: 1), false);
      sample(0, 200, epoch: 2);
      sample(5000, 5200, epoch: 2);
      await r.progress(e, audioId: 'audio', intervals: h.intervals);
      await r.progress(e, page: 2);
      final reopen = DiaryReadStore(f.db, readerId: 'reader');
      await reopen.load();
      final saved = reopen.state(e);
      expect(saved['page'], 2);
      expect(saved['read'], false);
      final h2 = HeardAudio(
        intervals: (saved['audio']['audio']['intervals'] as List)
            .map((v) => List<int>.from(v))
            .toList(),
      );
      h2.sample(
        position: 5000,
        nowMs: 6000,
        playing: true,
        completed: false,
        duration: 10000,
        seekEpoch: 0,
      );
      final done = h2.sample(
        position: 10000,
        nowMs: 11000,
        playing: false,
        completed: true,
        duration: 10000,
        seekEpoch: 0,
      );
      expect(done, true);
      await reopen.progress(
        e,
        audioId: 'audio',
        intervals: h2.intervals,
        audioDone: done,
      );
      expect(reopen.isRead(e), false);
      await reopen.progress(e, textEnd: true, page: 3);
      expect(reopen.isRead(e), true);
      final cycle2 = DiaryPublication.of(e).changed(reannounce: true).apply(e);
      expect(reopen.isRead(cycle2), false);
    } finally {
      await f.close();
    }
  });
  test('DAY diff metadata/reorder/reannounce zero upload, one new image one upload; private path never public', () {
    const m1 = DiaryMedia(
      assetId: 'one',
      mime: 'image/png',
      bytes: 20,
      localPath: '/private/draft.png',
      locator: 'https://drive.google.com/private',
      hash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    const m2 = DiaryMedia(
      assetId: 'two',
      mime: 'image/png',
      bytes: 20,
      hash: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    final a = entry15(
      'diff',
      blocks: [
        const DiaryBlock(
          id: 'i',
          type: DiaryBlockType.image,
          media: m1,
          width: 10,
          height: 10,
        ),
        const DiaryBlock(id: 't', type: DiaryBlockType.text, text: 'Текст'),
      ],
    );
    final edit = a.copyWith(
      title: 'Изменено',
      blocks: a.blocks.reversed.toList(),
    );
    expect(DiaryDiffPlan.between(a, edit).mediaUploads, 0);
    expect(
      DiaryDiffPlan.between(
        a,
        DiaryPublication.of(edit).changed(reannounce: true).apply(edit),
      ).mediaUploads,
      0,
    );
    expect(
      DiaryDiffPlan.between(
        a,
        edit.copyWith(blocks: [edit.blocks.last.copyWith(media: m2)]),
      ).mediaUploads,
      1,
    );
    final json = jsonEncode(diaryPublicManifest(a));
    expect(json, isNot(contains('/private/')));
    expect(json, isNot(contains('drive.google.com')));
    expect(json, isNot(contains('localPath')));
  });
  test(
    'DAY future metadata cannot reach legacy API even when authenticated',
    () async {
      final f = await Fixture15.open();
      var calls = 0;
      final d = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
        api: DiaryApi(
          Uri.parse('https://fixture.invalid'),
          request: (m, u, h, b) async {
            calls++;
            throw StateError('must not call');
          },
        ),
      );
      try {
        await d.load();
        await d.saveDraft(entry15('local'));
        await expectLater(
          d.saveToCloud(entry15('local')),
          throwsA(isA<DiaryApiException>()),
        );
        await expectLater(
          d.publish(entry15('local'), published: true),
          throwsA(isA<DiaryApiException>()),
        );
        expect(calls, 0);
      } finally {
        d.dispose();
        await f.close();
      }
    },
  );
  test('DAY actual DiaryAudio callbacks mark full EOF only, seek alone rejected, preview stays separate', () async {
    final f = await Fixture15.open();
    var now = DateTime.utc(2026, 11, 9);
    final store = DiaryMediaStore(
      Directory('${f.root.path}/diary'),
      pick: (_) async => null,
      probe: (_) async => const Duration(seconds: 10),
    );
    final block = await store.importFile(DiaryBlockType.audio, (
      name: 'voice.m4a',
      path: 'test/fixtures/android_aac_isom.m4a',
    ));
    final transport = FakeAudio()..duration = const Duration(seconds: 10);
    final d = DiaryController(
      DiaryRepository(f.db),
      clock: () => now,
      audioFactory: () => DiaryAudio(transport: transport, store: store),
    );
    final e = entry15('voice', blocks: [block]);
    try {
      await d.repository.cache([e], {}, '1');
      await d.load();
      final a = d.audioFor(e)!;
      await a.toggle(block);
      await a.seek(const Duration(seconds: 10));
      transport.completed = true;
      transport.playing = false;
      transport.stream.add(null);
      await d.reads.flush();
      expect(d.reads.isRead(e), false);
      await a.seek(Duration.zero);
      await a.toggle(block);
      now = now.add(const Duration(seconds: 5));
      transport.position = const Duration(seconds: 5);
      transport.stream.add(null);
      await a.pause();
      await d.reads.flush();
      expect(d.reads.isRead(e), false);
      await a.toggle(block);
      now = now.add(const Duration(seconds: 5));
      transport.position = const Duration(seconds: 10);
      transport.completed = true;
      transport.playing = false;
      transport.stream.add(null);
      await d.reads.flush();
      expect(d.reads.isRead(e), true);
      expect(d.ownsAudio(a), true);
    } finally {
      d.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await f.close();
    }
  });
  testWidgets(
    'DAY reader opens unread, last real page confirmation removes Home only; preview has no effects',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final d = DiaryController(DiaryRepository(f.db));
      final e = entry15('read');
      try {
        await t.runAsync(() async {
          await d.repository.cache([e], {}, '1');
          await d.load();
        });
        await show15(t, f, DiaryReader(entry: e, diary: d));
        expect(d.reads.isRead(e), false);
        await capture15(t, 'g4-reader-unread');
        await t.ensureVisible(find.byKey(const Key('diary-text-end')));
        await t.tap(find.byKey(const Key('diary-text-end')));
        await io15(t);
        expect(d.reads.isRead(e), true);
        expect(d.currentEntry, null);
        expect(d.published, hasLength(1));
        await show15(t, f, Scaffold(body: DiaryHomeMessage(diary: d)));
        expect(find.text(e.message), findsNothing);
        final again = DiaryPublication.of(e).changed(reannounce: true).apply(e);
        await show15(t, f, DiaryReader(entry: again, diary: d, preview: true));
        expect(find.byKey(const Key('diary-text-end')), findsNothing);
        expect(d.reads.isRead(again), false);
        await capture15(t, 'g4-author-preview');
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'DAY author exact ContentLink picker uses registry, saves draft and original fields',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final d = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
      );
      try {
        await t.runAsync(() async {
          await f.c.library.save((await f.c.library.prepareImport())!);
          await d.load();
        });
        final e = entry15('link').copyWith(
          extra: {
            'futureRoot': {'keep': true},
          },
        );
        await show15(t, f, DiaryEditor(diary: d, entry: e));
        await t.ensureVisible(find.byKey(const Key('diary-add-content')));
        await t.tap(find.byKey(const Key('diary-add-content')));
        await io15(t);
        final options = find.byType(SimpleDialogOption);
        expect(options, findsOneWidget);
        await capture15(t, 'g4-exact-content-picker');
        await t.tap(options);
        await io15(t);
        final draft = d.drafts.single;
        expect(draft.contentLinks.single.key.digest, hasLength(64));
        expect(draft.extra['futureRoot'], {'keep': true});
        await capture15(t, 'g4-draft-with-content-link');
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
}
