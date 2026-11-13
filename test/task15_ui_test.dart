import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/ui/home_screen.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/design.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';

void main() {
  late Fixture15 f;
  setUp(() async => f = await Fixture15.open());
  tearDown(() async => f.close());
  for (final size in [
    const Size(320, 600),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('G1 shared shield safe area ${size.width} scale $scale', (
        t,
      ) async {
        await show15(
          t,
          f,
          HomeScreen(controller: f.c, player: f.player),
          size: size,
          scale: scale,
        );
        final shield = find.byKey(const Key('home-space'));
        final rect = t.getRect(shield);
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(shield.hitTestable(), findsOneWidget);
        await capture15(t, 'g1-home-${size.width.toInt()}-$scale');
        await t.tap(shield);
        await io15(t);
        expect(find.text('Ваше пространство'), findsOneWidget);
        await t.ensureVisible(find.text('Клиент'));
        await t.tap(find.text('Клиент'));
        for (
          var wait = 0;
          wait < 40 && f.c.policy.mode != LocalMode.client;
          wait++
        ) {
          await io15(t);
        }
        await io15(t);
        expect(f.c.policy.mode, LocalMode.client);
        expect(find.text('Режим: Клиент'), findsOneWidget);
        await t.runAsync(f.c.policy.load);
        expect(f.c.policy.mode, LocalMode.client);
        Navigator.of(t.element(find.text('Ваше пространство'))).pop();
        await io15(t);
        final nav = Navigator.of(t.element(find.byType(HomeScreen)));
        nav.push<void>(
          MaterialPageRoute(
            builder: (_) => LibraryScreen(
              library: f.c.library,
              player: f.player,
              controller: f.c,
            ),
          ),
        );
        await io15(t);
        await t.tap(find.byTooltip('О приложении и данных'));
        await io15(t);
        expect(find.text('Режим: Клиент'), findsOneWidget);
        await t.ensureVisible(find.text('Автор'));
        await t.tap(find.text('Автор'));
        for (
          var wait = 0;
          wait < 40 && f.c.policy.mode != LocalMode.author;
          wait++
        ) {
          await io15(t);
        }
        await io15(t);
        expect(f.c.policy.mode, LocalMode.author);
        Navigator.of(t.element(find.text('Ваше пространство'))).pop();
        await io15(t);
        nav.pop();
        await io15(t);
        await t.tap(shield);
        await io15(t);
        expect(find.text('Режим: Автор'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await io15(t);
      });
    }
  }
  testWidgets(
    'G1 module marker belongs to A, separate yellow label; template marker and Undo',
    (t) async {
      await t.runAsync(() async {
        await f.c.library.save((await f.c.library.prepareImport())!);
        await f.c.reload();
      });
      final m = ModuleDefinition(
        id: 'source',
        title: 'Имя изменено автором',
        items: [
          SessionStep(
            id: 'a',
            kind: StepKind.audio,
            title: 'Аудио',
            audioAssetId: f.c.assets.single.id,
            durationMs: 60000,
          ),
          const SessionStep(
            id: 'p',
            kind: StepKind.silence,
            title: 'Пауза',
            durationMs: 5000,
          ),
        ],
      );
      await t.runAsync(() async {
        await f.c.modules.save(m);
        final p = await f.c.createPhase('induction');
        await f.c.addModule(p, m);
        await f.c.addModule(p, m);
        final template = await f.c.saveAsTemplate('Активный шаблон', '');
        await f.c.loadTemplate(template);
      });
      final phase = f.c.draft.plan.phases!.single;
      final a = phase.children.first;
      await t.runAsync(
        () => f.c.updateChild(
          phase.id,
          a.copyWith(items: a.items.reversed.toList()),
        ),
      );
      await show15(
        t,
        f,
        ModularStructureScreen(controller: f.c, player: f.player),
      );
      final markers = find.text('(Изменено)');
      expect(markers, findsOneWidget);
      final marker = t.widget<Text>(
        find.byKey(ValueKey('module-changed-${a.id}')),
      );
      expect(marker.style!.color, const Color(0xFFFFE66A));
      final titles = t
          .widgetList<Text>(find.text('Модуль: ${m.title}'))
          .toList();
      expect(titles, hasLength(2));
      expect(
        titles.where((x) => x.style!.fontStyle == FontStyle.italic),
        hasLength(1),
      );
      expect(titles.where((x) => x.style!.color == neonPink), hasLength(1));
      await capture15(t, 'g1-only-A-changed');
      await show15(t, f, HomeScreen(controller: f.c, player: f.player));
      expect(find.byKey(const Key('template-changed')), findsOneWidget);
      await capture15(t, 'g1-template-marker');
      await t.runAsync(() => f.c.updateChild(phase.id, a));
      await io15(t);
      expect(find.byKey(const Key('template-changed')), findsNothing);
      expect(
        f.c.draft.plan.phases!.single.children.every((v) => v.title == m.title),
        true,
      );
      await t.pumpWidget(const SizedBox());
      await io15(t);
    },
  );
  testWidgets('G1 client edition shield cannot grant author mode', (t) async {
    final client = await t.runAsync(() => Fixture15.open(client: true));
    try {
      await show15(
        t,
        client!,
        HomeScreen(controller: client.c, player: client.player),
      );
      await t.tap(find.byKey(const Key('home-space')));
      await io15(t);
      expect(find.text('Режим: Клиент'), findsOneWidget);
      expect(find.text('Автор'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await io15(t);
    } finally {
      await t.runAsync(() => client!.close());
    }
  });
}
