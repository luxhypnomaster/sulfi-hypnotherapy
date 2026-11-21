import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_editor.dart';
import 'package:sulfi_hypnotherapy/ui/diary_home_banner.dart';
import 'package:sulfi_hypnotherapy/ui/home_composition.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';
import 'package:sulfi_hypnotherapy/ui/session_scope.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_diary_test.dart' show entry15;

void main() {
  testWidgets(
    '21 selected draft static preview reuses exact HOME9:16 geometry, no save/read/rotation/remote/media effects',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      var remote = 0, audio = 0;
      final media = DiaryMediaStore(
        Directory('${f.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => null,
      );
      media.remoteResolver = (_) async {
        remote++;
        return null;
      };
      final d = DiaryController(
        DiaryRepository(f.db),
        policy: f.c.policy,
        authorRepository: DiaryAuthorRepository(f.db),
        mediaStore: media,
        audioFactory: () {
          audio++;
          throw StateError('static preview must not create audio');
        },
      );
      final draft = entry15('selected').copyWith(status: DiaryStatus.draft),
          other = entry15('other');
      late final SessionController c;
      await t.runAsync(() async {
        c = SessionController(
          repository: f.c.repository,
          library: f.c.library,
          modules: f.c.modules,
          capsules: f.c.capsules,
          diary: d,
          preview: f.player,
        );
        await c.reload();
        await d.saveDraft(draft);
        await d.repository.cache([other], {}, '1');
        await d.load();
      });
      try {
        await show15(
          t,
          f,
          HomeComposition(
            controller: c,
            player: f.player,
            busy: false,
            onStructure: () {},
            onTemplates: () {},
            onLibrary: () {},
            onHistory: () {},
            onNotes: () {},
            onStart: () {},
            onPreview: (_) async {},
            clock: const Text('clock'),
          ),
          size: const Size(360, 640),
        );
        final header = t.getRect(find.byKey(const Key('home-portrait'))),
            board = t.getRect(find.byKey(const Key('home-board-frame'))),
            nav = t.getRect(find.byKey(const Key('home-navigation')));
        await show15(
          t,
          f,
          SessionScope(
            controller: c,
            player: f.player,
            child: DiaryEditor(diary: d, entry: draft),
          ),
          size: const Size(360, 640),
        );
        await io15(t);
        final before = (await t.runAsync(() => f.db.query('diary_author')))!;
        final readBefore = d.reads.state(draft);
        await t.enterText(
          find.byKey(const Key('diary-title')),
          'Несохранённый выбранный заголовок',
        );
        await t.ensureVisible(find.byKey(const Key('diary-preview-home')));
        await t.tap(find.byKey(const Key('diary-preview-home')));
        await t.pumpAndSettle();
        expect(find.byType(DiaryHomeBanner), findsNothing);
        expect(find.byType(DiaryPublicationSlide), findsOneWidget);
        expect(find.text('Несохранённый выбранный заголовок'), findsOneWidget);
        expect(find.text('Послание other'), findsNothing);
        expect(t.getRect(find.byKey(const Key('home-portrait'))), header);
        expect(t.getRect(find.byKey(const Key('home-board-frame'))), board);
        expect(t.getRect(find.byKey(const Key('home-navigation'))), nav);
        await t.pump(const Duration(seconds: 35));
        expect(find.text('Несохранённый выбранный заголовок'), findsOneWidget);
        final after = (await t.runAsync(() => f.db.query('diary_author')))!;
        expect(jsonEncode(after), jsonEncode(before));
        expect(d.reads.state(draft), readBefore);
        expect(remote, 0);
        expect(audio, 0);
        await capture15(t, 'task21-static-selected-home');
        await t.tap(find.byKey(const Key('static-preview-close')));
        await t.pumpAndSettle();
        expect(find.byType(DiaryEditor), findsOneWidget);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          c.dispose();
          d.dispose();
          await f.close();
        });
      }
    },
  );
  testWidgets(
    '21 existing full reader preview remains reachable from same editor',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final d = DiaryController(
        DiaryRepository(f.db),
        policy: f.c.policy,
        authorRepository: DiaryAuthorRepository(f.db),
      );
      final e = entry15('preview').copyWith(status: DiaryStatus.draft);
      await t.runAsync(d.load);
      try {
        await show15(t, f, DiaryEditor(diary: d, entry: e));
        await io15(t);
        await t.ensureVisible(find.text('Предпросмотр'));
        await t.tap(find.text('Предпросмотр'));
        await io15(t);
        expect(find.byType(DiaryReader), findsOneWidget);
        expect(t.widget<DiaryReader>(find.byType(DiaryReader)).preview, true);
        expect(d.reads.isRead(e), false);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          d.dispose();
          await f.close();
        });
      }
    },
  );
}
