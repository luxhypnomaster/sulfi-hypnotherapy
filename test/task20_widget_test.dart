import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/diary_audio.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/preview_diary_transport.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_home.dart';
import 'package:sulfi_hypnotherapy/ui/diary_home_banner.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';
import 'package:sulfi_hypnotherapy/ui/home_composition.dart';
import 'package:sulfi_hypnotherapy/ui/vitrine_settings_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_diary_test.dart' show entry15;

void main() {
  testWidgets('20 multipage text is marked only at last rendered page end', (
    t,
  ) async {
    final f = (await t.runAsync(Fixture15.open))!;
    final d = DiaryController(DiaryRepository(f.db));
    final e = entry15(
      'many',
      blocks: [
        DiaryBlock(
          id: 'text',
          type: DiaryBlockType.text,
          text: 'Проверка страниц. ' * 150,
        ),
      ],
    );
    var count = 0;
    await t.runAsync(() async {
      await d.repository.cache([e], {}, '1');
      await d.load();
    });
    try {
      await show15(
        t,
        f,
        DiaryReader(
          entry: e,
          diary: d,
          onLayout: (l, _, _) => count = l.pages.length,
        ),
        size: const Size(360, 640),
      );
      await io15(t);
      expect(count, greaterThan(1));
      expect(d.reads.isRead(e), false);
      for (var i = 1; i < count; i++) {
        await t.tap(find.byTooltip('Следующая страница'));
        await io15(t);
        if (i < count - 1) {
          expect(d.reads.isRead(e), false);
        }
      }
      await t.drag(
        find.byKey(ValueKey('diary-page-${count - 1}')),
        const Offset(0, -1000),
      );
      await io15(t);
      expect(d.reads.isRead(e), true);
      expect(find.byType(DiaryReader), findsOneWidget);
      expect(t.takeException(), null);
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        d.dispose();
        await f.close();
      });
    }
  });
  testWidgets(
    '20 reader own-audio manual mark without listening; ContentLink never invokes media downloader',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      var resolves = 0;
      final store = DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => const Duration(seconds: 3),
      );
      store.remoteResolver = (_) async {
        resolves++;
        throw StateError('must not request ContentLink bytes');
      };
      final d = DiaryController(DiaryRepository(f.db), mediaStore: store);
      DiaryController? linkedDiary;
      final own = entry15(
        'own',
        blocks: [
          const DiaryBlock(
            id: 'audio',
            type: DiaryBlockType.audio,
            durationMs: 1000,
            media: DiaryMedia(assetId: 'audio', mime: 'audio/mpeg', bytes: 10),
          ),
        ],
      );
      await t.runAsync(() async {
        await d.repository.cache([own], {}, '1');
        await d.load();
      });
      try {
        debugPrint('T20 reader fixture ready');
        await show15(t, f, DiaryReader(entry: own, diary: d));
        await io15(t);
        expect(d.reads.isRead(own), false);
        expect(find.text('Отметить прочитанным'), findsOneWidget);
        await t.tap(find.byKey(const Key('diary-text-end')));
        await io15(t);
        expect(d.reads.isRead(own), true);
        debugPrint('T20 explicit audio mark verified');
        expect(find.byType(DiaryReader), findsOneWidget);
        final linked = entry15('linked').copyWith(
          extra: {
            ...entry15('linked').extra,
            'contentLinks': [
              ContentLink(
                RevisionKey(
                  const ContentKey(ContentType.track, 'linked'),
                  'v1',
                  'a' * 64,
                ),
                ContentLinkAction.install,
              ).toMap(),
            ],
          },
        );
        await t.runAsync(() async {
          linkedDiary = DiaryController(
            DiaryRepository(f.db),
            mediaStore: store,
          );
          await linkedDiary!.repository.cache([linked], {'own'}, '2');
          await linkedDiary!.load();
          debugPrint('T20 independent link view ready');
        });
        await show15(
          t,
          f,
          Scaffold(
            body: SizedBox(
              height: 112,
              width: double.infinity,
              child: DiaryHomeBanner(
                diary: linkedDiary!,
                splash: const Text('SPLASH'),
              ),
            ),
          ),
        );
        await io15(t);
        await t.pump(const Duration(seconds: 3));
        expect(find.text('Послание linked'), findsOneWidget);
        expect(find.byKey(const Key('diary-home-play')), findsNothing);
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(seconds: 7));
          await t.pump(const Duration(seconds: 3));
        }
        expect(resolves, 0);
        debugPrint('T20 link no-download verified');
        expect(d.reads.isRead(linked), false);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          linkedDiary?.dispose();
          d.dispose();
          await f.close();
        });
      }
    },
  );
  testWidgets(
    '20 banner fake clock3/7, exact slot geometry, play uses shared preview and no read, revoke immediate',
    (t) async {
      final f = await t.runAsync(Fixture15.open);
      final fixture = f!;
      final store = DiaryMediaStore(
        Directory('${fixture.root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => const Duration(seconds: 3),
      );
      final b = (await t.runAsync(
        () => store.importFile(DiaryBlockType.audio, (
          name: 'a.m4a',
          path: 'test/fixtures/android_aac_isom.m4a',
        )),
      ))!;
      final d = DiaryController(
        DiaryRepository(fixture.db),
        mediaStore: store,
        audioFactory: () => DiaryAudio(
          transport: PreviewDiaryTransport(fixture.player),
          store: store,
        ),
      );
      final e = entry15('audio', blocks: [b]);
      await t.runAsync(() async {
        await d.repository.cache([e], {}, '1');
        await d.load();
      });
      try {
        await show15(
          t,
          fixture,
          Scaffold(
            body: SizedBox(
              key: const Key('slot'),
              height: 112,
              width: double.infinity,
              child: DiaryHomeBanner(diary: d, splash: const Text('SPLASH')),
            ),
          ),
        );
        await io15(t);
        expect(find.text('SPLASH'), findsOneWidget);
        final before = t.getRect(find.byKey(const Key('slot')));
        await t.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('diary-home-slide')), findsOneWidget);
        expect(t.getRect(find.byKey(const Key('slot'))), before);
        await t.tap(find.byKey(const Key('diary-home-play')));
        await io15(t);
        expect(fixture.player.playing, true);
        expect(d.reads.isRead(e), false);
        expect(find.byType(DiaryReader), findsNothing);
        await t.runAsync(() => d.textProgress(e, 0, end: true));
        await t.pump();
        expect(d.reads.isRead(e), true);
        expect(fixture.player.playing, true);
        expect(find.text('SPLASH'), findsOneWidget);
        await t.pump(const Duration(seconds: 60));
        expect(find.text('SPLASH'), findsOneWidget);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          d.dispose();
          await fixture.close();
        });
      }
    },
  );
  testWidgets(
    '20 MASTER board sticker and two tabs; CLIENT route denied and sticker absent',
    (t) async {
      for (final client in [false, true]) {
        final f = (await t.runAsync(() => Fixture15.open(client: client)))!;
        final d = DiaryController(
          DiaryRepository(f.db),
          policy: f.c.policy,
          authorRepository: DiaryAuthorRepository(f.db),
        );
        await t.runAsync(d.load);
        try {
          await show15(
            t,
            f,
            Scaffold(
              body: DiaryHomeBoard(
                diary: d,
                management: d,
                child: const SizedBox(),
              ),
            ),
          );
          expect(
            find.byKey(const Key('home-management')),
            client ? findsNothing : findsOneWidget,
          );
          await show15(t, f, PublicationsVitrineScreen(diary: d));
          await io15(t);
          if (client) {
            expect(find.text('Доступ недоступен'), findsOneWidget);
            expect(find.text('Настройки витрины'), findsNothing);
          } else {
            expect(find.text('Публикации'), findsWidgets);
            await t.tap(find.text('Настройки витрины'));
            await t.pumpAndSettle();
            await io15(t);
            final button = t.widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Опубликовать настройки'),
            );
            expect(button.onPressed, null);
            expect(find.textContaining('пока не подключена'), findsOneWidget);
          }
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(() async {
            d.dispose();
            await f.close();
          });
        }
      }
    },
  );
  testWidgets(
    '20 actual HOME 9:16 portrait/board/navigation unchanged through splash and entry',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final d = DiaryController(
        DiaryRepository(f.db),
        policy: f.c.policy,
        authorRepository: DiaryAuthorRepository(f.db),
      );
      late final SessionController c;
      await t.runAsync(() async {
        c = SessionController(
          repository: f.c.repository,
          library: f.c.library,
          capsules: f.c.capsules,
          diary: d,
          preview: f.player,
        );
        await c.initialize();
        await d.repository.cache([entry15('notice')], {}, '1');
        await d.load();
      });
      try {
        debugPrint('T20 HOME prepare complete');
        await show15(
          t,
          f,
          HomeComposition(
            controller: c,
            busy: false,
            player: f.player,
            onStructure: () {},
            onTemplates: () {},
            onLibrary: () {},
            onHistory: () {},
            onNotes: () {},
            onStart: () {},
            onPreview: (_) async {},
            clock: const Text('21.11 18:30'),
          ),
          size: const Size(360, 640),
        );
        final portrait = t.getRect(find.byKey(const Key('home-portrait'))),
            board = t.getRect(find.byKey(const Key('home-board-frame'))),
            nav = t.getRect(find.byKey(const Key('home-navigation')));
        debugPrint('T20 HOME before capture');
        await capture15(t, 'home20-splash');
        debugPrint('T20 HOME after capture');
        await t.pump(const Duration(seconds: 3));
        expect(find.byKey(const Key('diary-home-slide')), findsOneWidget);
        expect(t.getRect(find.byKey(const Key('home-portrait'))), portrait);
        expect(t.getRect(find.byKey(const Key('home-board-frame'))), board);
        expect(t.getRect(find.byKey(const Key('home-navigation'))), nav);
        await capture15(t, 'home20-entry');
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
}
