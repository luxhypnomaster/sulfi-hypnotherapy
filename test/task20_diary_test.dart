import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/diary_publication.dart';
import 'package:sulfi_hypnotherapy/models/vitrine_config.dart';
import 'package:sulfi_hypnotherapy/services/diary_carousel.dart';
import 'package:sulfi_hypnotherapy/services/diary_read_state.dart';
import 'package:sulfi_hypnotherapy/services/vitrine_settings.dart';

import 'task15_diary_test.dart' show entry15;
import 'support/task15_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('20 local read: account+entry+cycle, quiet edit, reannounce and legacy rows preserved', () async {
    final f = await Fixture15.open();
    try {
      final e = entry15('one'),
          legacy = DiaryReadStore(f.db, readerId: 'A', localOnly: false);
      await legacy.load();
      await legacy.progress(e, textEnd: true);
      final before = await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['diary_read:%'],
      );
      final reads = DiaryReadStore(f.db, readerId: 'A');
      await reads.load();
      expect(reads.isRead(e), true);
      expect(reads.isRead(e.copyWith(title: 'quiet', version: 3)), true);
      final re = DiaryPublication.of(e).changed(reannounce: true).apply(e);
      expect(reads.isRead(re), false);
      await reads.progress(re, page: 1);
      expect(reads.isRead(re), false);
      await reads.progress(re, textEnd: true);
      expect(reads.isRead(re), true);
      expect(reads.syncSnapshot([e, re]), isEmpty);
      expect(
        await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['diary_read:%'],
        ),
        before,
      );
      await reads.switchReader('B');
      expect(reads.isRead(e), false);
      expect(reads.isRead(re), false);
      await reads.switchReader('A');
      expect(reads.isRead(re), true);
    } finally {
      await f.close();
    }
  });
  test('20 own audio requires explicit mark, not listening; ContentLink does not count as own media', () async {
    final f = await Fixture15.open();
    try {
      final r = DiaryReadStore(f.db, readerId: 'A');
      await r.load();
      final e = entry15(
        'audio',
        blocks: [
          const DiaryBlock(
            id: 'sound',
            type: DiaryBlockType.audio,
            media: DiaryMedia(assetId: 'a', mime: 'audio/mpeg', bytes: 10),
          ),
        ],
      );
      await r.progress(
        e,
        audioId: 'sound',
        audioDone: true,
        intervals: [
          [0, 9999],
        ],
      );
      expect(r.state(e), isEmpty);
      await r.progress(e, textEnd: true);
      expect(r.isRead(e), false);
      await r.progress(e, textEnd: true, confirmed: true);
      expect(r.isRead(e), true);
      expect(r.state(e).containsKey('audio'), false);
      final text = entry15('text');
      await r.progress(text, textEnd: true);
      expect(r.isRead(text), true);
    } finally {
      await f.close();
    }
  });
  test('20 carousel defaults3/7, all unread, 1:1, full cycle and empty has no tick work', () {
    final c = DiaryCarousel(), now = DateTime.utc(2026, 11, 21);
    expect(c.duration.inSeconds, 3);
    expect(c.hasEntries, false);
    c.advance();
    expect(c.current, null);
    final entries = [
      entry15('h1', high: true),
      entry15('h2', high: true),
      entry15('n1'),
      entry15('n2'),
    ];
    c.update(entries, now, (_) => false);
    final ids = <String>[];
    for (var i = 0; i < 4; i++) {
      c.advance();
      ids.add(c.current!.id);
      expect(c.duration.inSeconds, 7);
    }
    expect(ids, ['h1', 'n1', 'h2', 'n2']);
    c.advance();
    expect(c.current, null);
    expect(c.duration.inSeconds, 3);
    c.update(entries, now, (_) => true);
    c.advance();
    expect(c.current, null);
    expect(c.hasEntries, false);
  });
  test('20 pins3/4/N1 fair; all ordinary posts and multiple pins appear each bounded cycle', () {
    for (final n in [1, 3, 4]) {
      final c = DiaryCarousel(config: VitrineConfig(pinnedEveryNth: n));
      DiaryEntry pin(String id) {
        final e = entry15(id);
        return e.copyWith(
          extra: {
            ...e.extra,
            'publication': {...DiaryPublication.of(e).toMap(), 'pinned': true},
          },
        );
      }

      final entries = [
        pin('pin1'),
        pin('pin2'),
        for (var i = 0; i < 10; i++) entry15('n$i'),
      ];
      c.update(entries, DateTime.utc(2026, 11, 21), (_) => false);
      final seen = <String>{};
      for (var i = 0; i < 80; i++) {
        c.advance();
        if (c.current != null) seen.add(c.current!.id);
      }
      expect(seen, entries.map((e) => e.id).toSet());
      c.update(
        entries,
        DateTime.utc(2026, 11, 21),
        (e) => e.id.startsWith('pin'),
      );
      c.advance();
      for (var i = 0; i < 25; i++) {
        c.advance();
        expect(c.current?.id.startsWith('pin') ?? false, false);
      }
    }
  });
  test('20 refresh coalesces at slide boundary, urgent removal immediate; between-post splash', () {
    final a = entry15('a'), b = entry15('b'), c = DiaryCarousel();
    final now = DateTime.utc(2026, 11, 21);
    c.update([a], now, (_) => false);
    c.advance();
    expect(c.current?.id, 'a');
    for (var i = 0; i < 6; i++) c.update([a, b], now, (_) => false);
    expect(c.current?.id, 'a');
    c.advance();
    expect(c.current?.id, 'b');
    c.update([a], now, (_) => false);
    expect(c.current, null);
    final between = DiaryCarousel(
      config: const VitrineConfig(splashMode: VitrineSplashMode.betweenEntries),
    );
    between.update([a, b], now, (_) => false);
    between.advance();
    expect(between.current?.id, 'a');
    between.advance();
    expect(between.current, null);
    between.advance();
    expect(between.current?.id, 'b');
  });
  test('20 settings1..60, local saved != published; CLIENT denied and previous records retained', () async {
    for (final seconds in [1, 60]) {
      VitrineConfig(splashSeconds: seconds, entrySeconds: seconds).validate();
    }
    for (final seconds in [0, 61]) {
      expect(
        () => VitrineConfig(splashSeconds: seconds).validate(),
        throwsFormatException,
      );
    }
    final f = await Fixture15.open();
    String? account = 'A';
    bool canEdit = true;
    final s = VitrineSettingsStore(
      f.db,
      account: () => account,
      canEdit: () => canEdit,
    );
    try {
      await s.save(const VitrineConfig(entrySeconds: 9));
      expect((await s.load())['saved']['entrySeconds'], 9);
      expect((await s.load()).containsKey('published'), false);
      await expectLater(s.publish(), throwsFormatException);
      canEdit = false;
      await expectLater(s.save(const VitrineConfig()), throwsFormatException);
      account = 'B';
      expect(await s.load(), isEmpty);
      account = 'A';
      expect(jsonEncode(await s.load()), contains('9'));
    } finally {
      await f.close();
    }
  });
}
