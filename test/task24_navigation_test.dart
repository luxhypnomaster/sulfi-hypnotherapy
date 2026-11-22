// Real Flutter Navigator/widgets + synthetic FFI store. Not Android/Google QA.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_queue_indicator.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_sync_screen.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';
import 'package:sulfi_hypnotherapy/ui/session_scope.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_diary_test.dart' show entry15;

class Routes24 extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = routes.indexOf(oldRoute!);
    if (index >= 0) routes[index] = newRoute!;
  }
}

// Only identity read is controlled here. Queue/navigation implementation is real;
// no actual Google account/role/server success is claimed.
class QueueController24 extends SessionController {
  QueueController24(Fixture15 f)
    : super(
        repository: f.c.repository,
        library: f.c.library,
        modules: f.c.modules,
        capsules: f.c.capsules,
      );
  @override
  String get transferOwner => 'synthetic-queue-owner24';
}

Future<void> show24(
  WidgetTester t,
  Fixture15 f,
  Widget page,
  GlobalKey<NavigatorState> navigator,
  Routes24 audit, {
  SessionController? queue,
}) async {
  await show15(t, f, const SizedBox(), size: const Size(360, 640));
  await t.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      navigatorKey: navigator,
      navigatorObservers: [audit],
      theme: sulfiTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (_, child) => SessionScope(
        controller: f.c,
        player: f.player,
        child: RepaintBoundary(
          key: const Key('task15-capture'),
          child: Column(
            children: [
              if (queue != null)
                AlchemistQueueIndicator(
                  controller: queue,
                  navigatorKey: navigator,
                ),
              Expanded(child: child!),
            ],
          ),
        ),
      ),
      home: page,
    ),
  );
  await io15(t);
}

Future<DiaryController> diary24(Fixture15 f, {bool longText = false}) async {
  final d = DiaryController(
    DiaryRepository(f.db),
    policy: f.c.policy,
    authorRepository: DiaryAuthorRepository(f.db),
  );
  await d.repository.cache(
    [
      for (var i = 0; i < 12; i++)
        entry15(
          'post-$i',
          blocks: longText && i == 0
              ? [
                  DiaryBlock(
                    id: 'long',
                    type: DiaryBlockType.text,
                    text: 'Длинный текст для независимой пагинации. ' * 160,
                  ),
                ]
              : null,
        ).copyWith(order: i),
    ],
    {},
    'synthetic24',
  );
  await d.load();
  return d;
}

void main() {
  for (final client in [false, true]) {
    testWidgets(
      '24 RED→GREEN ${client ? 'CLIENT' : 'MASTER'} queue overlay 10 taps has one route; system Back restores exact parent and saved task',
      (t) async {
        final f = (await t.runAsync(() => Fixture15.open(client: client)))!,
            c = QueueController24(f),
            navigator = GlobalKey<NavigatorState>(),
            audit = Routes24();
        await t.runAsync(() async {
          await c.reload();
          await f.db.insert('app_settings', {
            'name': 'alchemist_download:task24',
            'value': jsonEncode({
              'ownerBinding': c.transferOwner,
              '_work': {
                'phase': 'paused',
                'pauseReason': 'USER_PAUSED',
                'stage': 'paused',
              },
            }),
          });
        });
        try {
          await show24(
            t,
            f,
            const Scaffold(body: Text('Логический родитель очереди')),
            navigator,
            audit,
            queue: c,
          );
          final before = (await t.runAsync(
            () => f.db.query(
              'app_settings',
              where: 'name=?',
              whereArgs: ['alchemist_download:task24'],
            ),
          ))!;
          final badge = find.byType(AlchemistQueueIndicator);
          final tap = t
              .widget<InkWell>(
                find
                    .descendant(of: badge, matching: find.byType(InkWell))
                    .first,
              )
              .onTap!;
          for (var i = 0; i < 10; i++) {
            tap();
            await t.pump();
          }
          await io15(t);
          expect(
            audit.routes.length,
            2,
            reason: 'root + one queue; no queue stack',
          );
          expect(
            find.byType(AlchemistSyncScreen, skipOffstage: false),
            findsOneWidget,
          );
          await capture15(t, 'task24-queue-${client ? 'client' : 'master'}');
          await t.binding.handlePopRoute();
          await io15(t);
          expect(audit.routes.length, 1);
          expect(find.text('Логический родитель очереди'), findsOneWidget);
          expect(
            await t.runAsync(
              () => f.db.query(
                'app_settings',
                where: 'name=?',
                whereArgs: ['alchemist_download:task24'],
              ),
            ),
            before,
          );
        } finally {
          await t.pumpWidget(const SizedBox());
          c.dispose();
          await t.runAsync(f.close);
        }
      },
    );
  }

  testWidgets(
    '24 RED→GREEN reader -> journal replaces reader, Back returns home without reader loop',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!,
          navigator = GlobalKey<NavigatorState>(),
          audit = Routes24();
      final d = (await t.runAsync(() => diary24(f)))!;
      try {
        await show24(
          t,
          f,
          const Scaffold(body: Text('Главная-контекст')),
          navigator,
          audit,
        );
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => DiaryReader(entry: d.published.first, diary: d),
          ),
        );
        await io15(t);
        await t.tap(find.text('К списку записей'));
        await io15(t);
        expect(find.byType(DiaryScreen), findsOneWidget);
        await t.binding.handlePopRoute();
        await io15(t);
        expect(find.text('Главная-контекст'), findsOneWidget);
        expect(audit.routes.length, 1);
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );

  testWidgets(
    '24 RED→GREEN next-post replaces ten siblings; Back restores original journal filter',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!,
          navigator = GlobalKey<NavigatorState>(),
          audit = Routes24();
      final d = (await t.runAsync(() => diary24(f)))!;
      try {
        await show24(t, f, DiaryScreen(diary: d), navigator, audit);
        await t.enterText(find.byType(TextField).first, 'post');
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => DiaryReader(
              entry: d.published.first,
              diary: d,
              fromJournal: true,
            ),
          ),
        );
        await io15(t);
        expect(find.byKey(const Key('diary-next-post')), findsOneWidget);
        for (var i = 0; i < 10; i++) {
          await t.tap(find.byKey(const Key('diary-next-post')));
          await io15(t);
          expect(audit.routes.length, 2);
          expect(find.text('Название post-${i + 1}'), findsOneWidget);
        }
        await capture15(t, 'task24-post-siblings');
        await t.binding.handlePopRoute();
        await io15(t);
        expect(find.byType(DiaryScreen), findsOneWidget);
        expect(
          t.widget<TextField>(find.byType(TextField).first).controller!.text,
          'post',
        );
        expect(audit.routes.length, 1);
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );

  testWidgets(
    '24 RED→GREEN root deep-link reader system Back has deterministic journal fallback',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!,
          navigator = GlobalKey<NavigatorState>(),
          audit = Routes24();
      final d = (await t.runAsync(() => diary24(f)))!;
      try {
        await show24(
          t,
          f,
          DiaryReader(entry: d.published.first, diary: d),
          navigator,
          audit,
        );
        await t.binding.handlePopRoute();
        await io15(t);
        expect(find.byType(DiaryScreen), findsOneWidget);
        expect(audit.routes.length, 1);
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );

  testWidgets(
    '24 in-post next-page preserves publication ID and route; post controls remain distinct',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!,
          navigator = GlobalKey<NavigatorState>(),
          audit = Routes24();
      final d = (await t.runAsync(() => diary24(f, longText: true)))!;
      try {
        await show24(t, f, const Scaffold(), navigator, audit);
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => DiaryReader(entry: d.published.first, diary: d),
          ),
        );
        await io15(t);
        final before = t
            .widget<Text>(find.byKey(const Key('diary-pagination')))
            .data!;
        await t.tap(find.byTooltip('Следующая страница'));
        await io15(t);
        expect(
          t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
          isNot(before),
        );
        expect(find.text('Название post-0'), findsOneWidget);
        expect(audit.routes.length, 2);
        expect(find.byKey(const Key('diary-next-post')), findsOneWidget);
        await capture15(t, 'task24-pages-not-posts');
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
}
