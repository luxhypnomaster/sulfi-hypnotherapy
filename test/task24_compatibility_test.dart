// Evidence for already implemented K025/026/027/029/030/037; no redesign.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';
import 'package:sulfi_hypnotherapy/ui/design.dart';
import 'package:sulfi_hypnotherapy/ui/home_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_detail_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/player_art.dart';
import 'package:sulfi_hypnotherapy/ui/run_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task24_navigation_test.dart' show diary24;
import 'v41_player_test.dart' show Fixture;

class Offline24 extends DiaryApi {
  Offline24() : super(Uri.parse('https://offline.invalid'));
  int signIns = 0;
  @override
  bool get supportsServerIdentity => true;
  @override
  Future<DiaryAuthorSession> authenticate(String token) async {
    signIns++;
    throw const DiaryApiException('No test sign-in');
  }

  @override
  Future<DiaryPage> feed({String? since, String? page}) async =>
      throw const DiaryApiException('Offline fixture');
}

void main() {
  testWidgets(
    '24 ALREADY_DONE K025 same-name occurrences and personal fork preserve exact identity, style and revert at9:16',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      try {
        final m = ModuleDefinition(
          id: 'official24',
          title: 'Одинаковое имя',
          origin: 'installed',
          items: const [
            SessionStep(
              id: 's1',
              kind: StepKind.silence,
              title: 'Первая пауза',
              durationMs: 1000,
            ),
            SessionStep(
              id: 's2',
              kind: StepKind.silence,
              title: 'Вторая пауза',
              durationMs: 2000,
            ),
          ],
        );
        final fork = ModuleDefinition(
          id: 'personal24',
          title: m.title,
          origin: 'personal',
          items: m.items.reversed.toList(),
        );
        late String phase;
        await t.runAsync(() async {
          // Synthetic previously-installed source, not changing a server ACL.
          await f.db.insert('module_definitions', {
            'id': m.id,
            'payload': jsonEncode(m.toMap()),
          });
          await f.c.modules.save(fork);
          phase = await f.c.createPhase('work');
          await f.c.addModule(phase, m);
          await f.c.addModule(phase, m);
          await f.c.addModule(phase, fork);
        });
        final original = f.c.draft.plan.phases!.single.children.first;
        final before = (await t.runAsync(
          () => f.db.query('module_definitions'),
        ))!;
        await t.runAsync(
          () => f.c.updateChild(
            phase,
            original.copyWith(items: original.items.reversed.toList()),
          ),
        );
        expect(
          f.c.draft.plan.phases!.single.children.map(
            f.c.moduleDiffersFromSource,
          ),
          [true, false, false],
        );
        await show15(
          t,
          f,
          ModularStructureScreen(controller: f.c, player: f.player),
          size: const Size(360, 640),
        );
        expect(find.text('(Изменено)'), findsOneWidget);
        final marker = t.widget<Text>(
          find.byKey(ValueKey('module-changed-${original.id}')),
        );
        expect(marker.style!.color, const Color(0xFFFFE66A));
        final titles = t
            .widgetList<Text>(find.text('Модуль: ${m.title}'))
            .toList();
        expect(
          titles.where(
            (w) =>
                w.style!.fontStyle == FontStyle.italic &&
                w.style!.color == neonPink,
          ),
          hasLength(1),
        );
        await capture15(t, 'task24-only-occurrence-A');
        await t.pumpWidget(const SizedBox());
        await io15(t);
        await t.runAsync(() => f.c.updateChild(phase, original));
        expect(
          f.c.draft.plan.phases!.single.children.map(
            f.c.moduleDiffersFromSource,
          ),
          [false, false, false],
        );
        expect(
          await t.runAsync(() => f.db.query('module_definitions')),
          before,
        );
        expect(
          f.c.draft.plan.phases!.single.children.last.definitionId,
          fork.id,
        );
        await show15(
          t,
          f,
          ModularStructureScreen(controller: f.c, player: f.player),
          size: const Size(360, 640),
        );
        expect(find.text('(Изменено)'), findsNothing);
        await capture15(t, 'task24-occurrence-reverted');
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(f.close);
      }
    },
  );

  testWidgets(
    '24 ALREADY_DONE K029 history Home action returns actual Home once and preserves history',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      try {
        final run = (await t.runAsync(() async {
          await f.c.addLoose(
            await f.c.createPhase('work'),
            const SessionStep(
              id: 'pause',
              kind: StepKind.silence,
              title: 'Пауза',
              durationMs: 1000,
            ),
          );
          final r = await f.c.repository.startRun(await f.c.snapshotForStart());
          await f.c.repository.checkpoint(
            r.checkpoint(status: RunStatus.completed, elapsedMs: 1000),
          );
          await f.c.repository.acknowledgeHistory(r.id);
          return r;
        }))!;
        final before = (await t.runAsync(f.c.repository.history))!
            .map((r) => r.toMap())
            .toList();
        await show15(
          t,
          f,
          HomeScreen(controller: f.c, player: f.player),
          size: const Size(360, 640),
        );
        final nav = Navigator.of(t.element(find.byType(HomeScreen)));
        nav.push<void>(
          MaterialPageRoute(
            builder: (_) => HistoryScreen(
              controller: f.c,
              player: f.player,
              selectedRunId: run.id,
            ),
          ),
        );
        await io15(t);
        expect(find.byType(HistoryDetailScreen), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('history-home')));
        await t.pumpAndSettle();
        await capture15(t, 'task24-history-home');
        await t.tap(find.byKey(const Key('history-home')));
        await io15(t);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(nav.canPop(), false);
        expect(find.byType(HistoryScreen), findsNothing);
        expect(find.byType(RunScreen), findsNothing);
        expect(
          (await t.runAsync(f.c.repository.history))!
              .map((r) => r.toMap())
              .toList(),
          before,
        );
        expect(f.player.playing, false);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(f.close);
      }
    },
  );

  for (final client in [false, true]) {
    testWidgets(
      '24 ALREADY_DONE K030 ${client ? 'CLIENT' : 'MASTER'} shield uses existing sheet at9:16 without server grants',
      (t) async {
        final f = (await t.runAsync(() => Fixture15.open(client: client)))!;
        try {
          await show15(
            t,
            f,
            HomeScreen(controller: f.c, player: f.player),
            size: const Size(360, 640),
          );
          final shield = find.byKey(const Key('home-space'));
          expect(shield.hitTestable(), findsOneWidget);
          expect(t.getRect(shield).top, greaterThanOrEqualTo(24));
          await capture15(t, 'task24-home-${client ? 'client' : 'master'}');
          await t.tap(shield);
          await io15(t);
          expect(find.text('Ваше пространство'), findsOneWidget);
          if (client) expect(find.text('Автор'), findsNothing);
          await capture15(t, 'task24-shield-${client ? 'client' : 'master'}');
          expect(f.c.policy.serverRole, isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(f.close);
        }
      },
    );
  }

  testWidgets(
    '24 ALREADY_DONE K037 offline local draft is reachable and editable without Google chooser',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!, api = Offline24();
      final d = DiaryController(
        DiaryRepository(f.db),
        api: api,
        policy: f.c.policy,
        authorRepository: DiaryAuthorRepository(f.db),
      );
      try {
        await t.runAsync(d.load);
        await show15(t, f, DiaryScreen(diary: d), size: const Size(360, 640));
        await t.tap(find.text('Новая запись'));
        await io15(t);
        expect(find.byType(DiaryEditor), findsOneWidget);
        await t.enterText(
          find.byKey(const Key('diary-title')),
          'Офлайн-черновик №24',
        );
        await t.pump(const Duration(milliseconds: 900));
        await io15(t);
        expect(api.signIns, 0);
        expect(d.authenticated, false);
        await capture15(t, 'task24-offline-editor');
        await t.binding.handlePopRoute();
        await io15(t);
        expect(find.byType(DiaryScreen), findsOneWidget);
        final rows = (await t.runAsync(() => f.db.query('diary_author')))!;
        expect(rows, hasLength(1));
        expect(
          jsonDecode(rows.single['payload'] as String)['title'],
          'Офлайн-черновик №24',
        );
        expect(
          jsonDecode(rows.single['payload'] as String)['_alchemistScope'],
          'local-device',
        );
      } finally {
        await t.pumpWidget(const SizedBox());
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );

  testWidgets('24 visual baseline and after reader same9:16 approved frame', (
    t,
  ) async {
    final f = (await t.runAsync(Fixture15.open))!,
        d = (await t.runAsync(() => diary24(f)))!;
    try {
      await show15(
        t,
        f,
        DiaryReader(entry: d.published.first, diary: d),
        size: const Size(360, 640),
      );
      await capture15(t, 'task24-reader9x16');
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox());
      d.dispose();
      await t.runAsync(f.close);
    }
  });

  testWidgets(
    '24 ALREADY_DONE K026 K027 timer yellow and nested phase/module/track9:16',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!,
          run = (await t.runAsync(() => Fixture.create(mixed: true)))!;
      try {
        await t.runAsync(PlayerArt.load);
        await show15(
          t,
          f,
          RunScreen(engine: run.engine),
          size: const Size(360, 640),
        );
        final time = t.widget<Text>(
          find.byKey(const Key('current-track-time')),
        );
        expect(time.style!.color, const Color(0xFFFFE34D));
        expect(time.style!.fontSize, 30);
        expect(
          find.descendant(
            of: find.byKey(const Key('player-context')),
            matching: find.byKey(const Key('current-track-time')),
          ),
          findsOneWidget,
        );
        final children = run.engine.timeline.phases.first.children;
        final group = find.byKey(ValueKey('module-group-${children[1].id}'));
        expect(
          find.descendant(of: group, matching: find.text('Веки тест 1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: group, matching: find.text('Прямой фокус')),
          findsNothing,
        );
        expect(find.textContaining('Модуль: Модуль:'), findsNothing);
        await capture15(t, 'task24-timer-hierarchy');
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(run.close);
        await t.runAsync(f.close);
      }
    },
  );
}
