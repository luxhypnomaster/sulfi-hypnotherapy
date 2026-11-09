import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_timeline.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_engine.dart';
import 'package:sulfi_hypnotherapy/ui/player_art.dart';
import 'package:sulfi_hypnotherapy/ui/run_screen.dart';

import 'support/fakes.dart';
import 'support/session_transport_fake.dart';

class Fixture {
  Fixture(this.dir, this.controller, this.engine, this.transport, this.clock);
  final Directory dir;
  final SessionController controller;
  final SessionEngine engine;
  final TestTransport transport;
  final ValueNotifier<int> clock;
  static Future<Fixture> create({
    int workTracks = 24,
    bool exit = true,
    bool unknownWork = false,
    bool longSession = false,
    bool mixed = false,
    bool shortPhase = false,
    bool pauseOnly = false,
    int pauseDurationMs = 8000,
  }) async {
    final dir = await Directory.systemTemp.createTemp('sulfi_v41_ui');
    final audio = MemoryRepository();
    final library = LibraryService(
      repository: audio,
      directory: Directory('${dir.path}/audio'),
      pick: () async => null,
      probe: (_) async => const Duration(seconds: 65),
    );
    await library.initialize();
    await audio.save(sampleAsset());
    await library.fileFor(sampleAsset()).writeAsBytes([0]);
    final c = SessionController(
      repository: MemorySessionRepository(),
      library: library,
    );
    await c.initialize();
    final prep = await c.createPhase('preparation'),
        work = await c.createPhase('work');
    ModuleDefinition module(String id, String title, int count) =>
        ModuleDefinition(
          id: id,
          title: title,
          items: [
            for (var i = 1; i <= count; i++)
              SessionStep(
                id: '$id-$i',
                kind: StepKind.audio,
                title: '$title — трек $i',
                audioAssetId: sampleAsset().id,
                durationMs: 65000,
              ),
          ],
        );
    await c.addModule(prep, module('prep', 'Личная подготовка', 2));
    await c.addModule(
      work,
      module('work1', 'Первый рабочий модуль', workTracks),
    );
    await c.addModule(work, module('work2', 'Второй рабочий модуль', 2));
    if (exit) {
      final phase = await c.createPhase('exit');
      await c.addModule(phase, module('exit', 'Личный выход', 1));
    }
    await c.setText(topic: 'Тестовая сессия');
    if (unknownWork) {
      await c.clearPlan();
      final phase = await c.createPhase('work');
      await c.addLoose(
        phase,
        const SessionStep(
          id: 'unknown',
          kind: StepKind.freeWork,
          title: 'Работа без ограничения',
          durationMs: null,
        ),
      );
    }
    if (longSession) {
      await c.clearPlan();
      for (var i = 0; i < 6; i++) {
        final phase = await c.createPhase('work');
        await c.addModule(
          phase,
          ModuleDefinition(
            id: 'long-$i',
            title: 'Индукция Элман v2',
            items: [
              SessionStep(
                id: 'a-$i',
                kind: StepKind.audio,
                title: 'Внешний фокус',
                audioAssetId: sampleAsset().id,
                durationMs: 150000,
              ),
              SessionStep(
                id: 'p-$i',
                kind: StepKind.silence,
                title: 'Пауза',
                durationMs: 41000,
              ),
              SessionStep(
                id: 'b-$i',
                kind: StepKind.audio,
                title: 'Углубление погружения',
                audioAssetId: sampleAsset().id,
                durationMs: 180000,
              ),
            ],
          ),
        );
      }
      await c.setText(
        topic: 'Длинная тема сессии для проверки безопасной разметки',
      );
    }
    if (shortPhase || mixed) {
      await c.clearPlan();
      for (var n = 0; n < (mixed ? 6 : 1); n++) {
        final phase = await c.createPhase('work');
        SessionStep audio(String id, String name) => SessionStep(
          id: id,
          kind: StepKind.audio,
          title: name,
          audioAssetId: sampleAsset().id,
          durationMs: 65000,
        );
        await c.addLoose(
          phase,
          pauseOnly
              ? SessionStep(
                  id: 'pause-only',
                  kind: StepKind.silence,
                  title: 'Пауза',
                  durationMs: pauseDurationMs,
                )
              : audio('direct-$n', 'Прямой фокус'),
        );
        if (mixed) {
          await c.addModule(
            phase,
            ModuleDefinition(
              id: 'mixed-$n',
              title: 'Модуль: Индукция Элман v2',
              items: [
                for (var i = 1; i <= 5; i++)
                  audio('nested-$n-$i', 'Веки тест $i'),
              ],
            ),
          );
          await c.addLoose(
            phase,
            SessionStep(
              id: 'direct-pause-$n',
              kind: StepKind.silence,
              title: 'Пауза',
              durationMs: 41000,
            ),
          );
          await c.addModule(phase, module('second-$n', 'Ресурс', 2));
          await c.addLoose(phase, audio('last-$n', 'Прямой выход'));
        }
      }
      await c.setText(
        topic: mixed
            ? 'Длинная тема сессии — проверка реальной вложенности'
            : 'Короткая сессия',
      );
    }
    final transport = TestTransport();
    final clock = ValueNotifier<int>(0);
    final engine = SessionEngine(
      controller: c,
      transport: transport,
      nowMs: () => clock.value,
    );
    await engine.start();
    engine.tick();
    await engine.flush();
    await engine.pause();
    return Fixture(dir, c, engine, transport, clock);
  }

  Future<void> close() async {
    await engine.close();
    controller.dispose();
    clock.dispose();
    await dir.delete(recursive: true);
  }
}

void main() {
  var fontsReady = false;
  Future<void> settleEngine(WidgetTester t, Fixture f) async {
    await t.pumpAndSettle();
    for (var i = 0; i < 100; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
      if (i >= 2 && !f.engine.busy) break;
    }
    expect(f.engine.busy, isFalse);
    await t.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester t,
    Fixture f, {
    Size size = const Size(412, 915),
    double scale = 1,
    bool systemBars = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    if (systemBars) {
      t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(t.view.resetPadding);
    }
    if (!fontsReady) {
      const supplied = String.fromEnvironment('SULFI_TEST_FONT');
      final sdk = File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent;
      final file = File(
        supplied.isNotEmpty
            ? supplied
            : '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      final data = await t.runAsync(file.readAsBytes);
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(data!)))).load();
      final iconBytes = await t.runAsync(
        () => File(
          '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes(),
      );
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(iconBytes!)))).load();
      fontsReady = true;
    }
    await t.runAsync(PlayerArt.load);
    await t.pumpWidget(
      RepaintBoundary(
        key: const Key('player-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RunScreen(engine: f.engine),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t, Fixture f) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(f.close);
  }

  testWidgets(
    'P01 P02 P03 P10 P11 P18 P20 P28: real controls and future phases stay open',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create()))!;
      await open(t, f);
      expect(find.text('Время трансформации'), findsNothing);
      expect(find.text('Предыдущий\nтрек'), findsOneWidget);
      expect(find.text('Следующий\nмодуль'), findsOneWidget);
      expect(find.text('Предыдущая\nфаза'), findsOneWidget);
      expect(find.byKey(const Key('watch-play-pause')), findsOneWidget);
      expect(find.text('Закончить сеанс'), findsOneWidget);
      for (final unit in NavigationUnit.values) {
        for (final direction in ['previous', 'next']) {
          expect(
            find.byKey(ValueKey('nav-${unit.name}-$direction')),
            findsOneWidget,
          );
        }
      }
      expect(find.text('Личная подготовка — трек 1'), findsWidgets);
      expect(find.text('Личная подготовка — трек 2'), findsOneWidget);
      expect(find.text('Первый рабочий модуль — трек 1'), findsOneWidget);
      expect(find.text('Модуль: Первый рабочий модуль'), findsOneWidget);
      expect(find.text('Модуль: Второй рабочий модуль'), findsOneWidget);
      final button = t.widget<OutlinedButton>(
        find.byKey(const ValueKey('nav-phase-previous')),
      );
      expect(button.onPressed, isNull);
      expect(t.takeException(), isNull);
      await close(t, f);
    },
  );
  testWidgets(
    'P12 P13 P14 P16 P24: phase expansion and only scale scrolls; paused never starts sound',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create()))!;
      await open(t, f);
      final plays = f.transport.plays;
      await t.tap(find.byKey(const ValueKey('nav-phase-next')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await settleEngine(t, f);
      expect(f.engine.paused, isTrue);
      expect(f.transport.plays, plays);
      expect(
        find.text('Личная подготовка — трек 2'),
        findsOneWidget,
      ); // skipped, not completed
      expect(find.text('Первый рабочий модуль — трек 24'), findsOneWidget);
      expect(find.text('Второй рабочий модуль — трек 2'), findsOneWidget);
      final nav = t.getTopLeft(find.byKey(const Key('player-navigation')));
      final stop = t.getTopLeft(find.byKey(const Key('finish-session')));
      final context = t.getTopLeft(find.byKey(const Key('player-context')));
      await t.scrollUntilVisible(
        find.text('Второй рабочий модуль — трек 2'),
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      expect(t.getTopLeft(find.byKey(const Key('player-navigation'))), nav);
      expect(t.getTopLeft(find.byKey(const Key('finish-session'))), stop);
      expect(t.getTopLeft(find.byKey(const Key('player-context'))), context);
      final index = f.engine.run!.stepIndex;
      await t.tap(
        find.text('Модуль: Второй рабочий модуль'),
        warnIfMissed: false,
      );
      await t.pump();
      expect(f.engine.run!.stepIndex, index);
      await t.runAsync(() => f.engine.navigate(NavigationUnit.phase, true));
      await t.pumpAndSettle();
      expect(find.text('Личный выход — трек 1').hitTestable(), findsWidgets);
      expect(t.getTopLeft(find.byKey(const Key('finish-session'))), stop);
      expect(t.takeException(), isNull);
      await close(t, f);
    },
  );
  testWidgets(
    'P29 P30: finish confirmation stops without pretending completed',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(exit: false)))!;
      await open(t, f);
      await t.tap(find.text('Закончить сеанс'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pumpAndSettle();
      expect(find.text('Перейти к выходу'), findsNothing);
      expect(find.text('Закончить сейчас'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      await t.tap(find.text('Закончить сейчас'));
      await settleEngine(t, f);
      expect(f.engine.run!.status, RunStatus.interrupted);
      expect(find.byKey(const Key('watch-play-pause')), findsNothing);
      expect(find.text('На главную'), findsOneWidget);
      await close(t, f);
    },
  );
  for (final config in [
    (const Size(320, 600), 1.6),
    (const Size(800, 360), 1.0),
  ]) {
    testWidgets('P32: safe layout ${config.$1} scale ${config.$2}', (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f, size: config.$1, scale: config.$2, systemBars: true);
      expect(
        find.byKey(const Key('finish-session')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('watch-play-pause')).hitTestable(),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await close(t, f);
    });
  }
  testWidgets(
    'P17 P19 L06: circular rim gesture seeks real transport while staying paused',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      final plays = f.transport.plays;
      final ring = t.getRect(find.byKey(const Key('track-seek')));
      await t.tapAt(
        ring.topLeft +
            Offset(ring.width * (221.5 + 164) / 470, ring.height * 318.5 / 595),
      );
      await settleEngine(t, f);
      expect(f.transport.position.inMilliseconds, greaterThan(0));
      expect(f.transport.position.inMilliseconds, lessThanOrEqualTo(65000));
      expect(f.transport.plays, plays);
      expect(f.engine.paused, isTrue);
      expect(f.transport.position.inMilliseconds, closeTo(16250, 100));
      final center =
          ring.topLeft +
          Offset(ring.width * 221.5 / 470, ring.height * 318.5 / 595);
      final radius = ring.width * 164 / 470;
      final drag = await t.startGesture(center + Offset(radius, 0));
      await drag.moveTo(center + Offset(radius * .707, radius * .707));
      await t.pump();
      await drag.moveTo(center + Offset(0, radius));
      await drag.up();
      await settleEngine(t, f);
      expect(f.transport.position.inMilliseconds, closeTo(32500, 100));
      expect(f.transport.plays, plays);
      await close(t, f);
    },
  );
  testWidgets(
    'L05: external previous/next and watch PlayPause control the same run',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      final run = f.engine.run!.id, first = f.engine.step!.id;
      expect(find.byKey(const Key('watch-next')), findsNothing);
      expect(find.byKey(const Key('watch-previous')), findsNothing);
      await t.tap(find.byKey(const Key('nav-track-next')));
      await settleEngine(t, f);
      expect(f.engine.step!.id, isNot(first));
      expect(f.engine.paused, isTrue);
      await t.tap(find.byKey(const Key('nav-track-previous')));
      await settleEngine(t, f);
      expect(f.engine.step!.id, first);
      await t.tap(find.byKey(const Key('watch-play-pause')));
      await settleEngine(t, f);
      expect(f.engine.paused, isFalse);
      expect(f.transport.plays, greaterThan(0));
      await t.tap(find.byKey(const Key('watch-play-pause')));
      await settleEngine(t, f);
      expect(f.engine.paused, isTrue);
      expect(f.engine.run!.id, run);
      await close(t, f);
    },
  );
  testWidgets(
    'P29 P30: available Exit is distinct from cancel and interruption',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      Future<void> dialog() async {
        await t.tap(find.text('Закончить сеанс'));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pumpAndSettle();
      }

      await dialog();
      expect(find.text('Перейти к выходу'), findsOneWidget);
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(f.engine.run!.status, RunStatus.paused);
      await dialog();
      await t.tap(find.text('Перейти к выходу'));
      await settleEngine(t, f);
      expect(f.engine.run!.status, RunStatus.exitingEarly);
      f.transport.completed = true;
      await t.runAsync(() async {
        f.engine.tick();
        await f.engine.flush();
      });
      await t.pumpAndSettle();
      expect(f.engine.run!.status, RunStatus.completedEarlyWithExit);
      expect(f.engine.forecast.liquidFraction, 0);
      expect(f.engine.run!.skippedStepIds, isNotEmpty);
      expect(find.byKey(const Key('watch-play-pause')), findsNothing);
      await close(t, f);
    },
  );
  testWidgets(
    'V4 FreeWork actions remain available through details without extra main controls',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(exit: false)))!;
      await t.runAsync(() async {
        await f.engine.interrupt();
        await f.controller.clearPlan();
        final phase = await f.controller.createPhase('work');
        await f.controller.addLoose(
          phase,
          const SessionStep(
            id: 'w',
            kind: StepKind.freeWork,
            title: 'Самостоятельная работа',
            durationMs: 30000,
          ),
        );
        await f.engine.start();
        f.engine.tick();
        await f.engine.flush();
        await f.engine.pause();
      });
      await open(t, f);
      final frozen = f.engine.run!.snapshot.plan.fingerprint;
      expect(find.text('+5 минут'), findsNothing);
      await t.tap(find.byTooltip('Подробности сессии'));
      await t.pumpAndSettle();
      await t.tap(find.text('+5 минут'));
      await settleEngine(t, f);
      expect(f.engine.forecast.totalMs, 330000);
      expect(f.engine.run!.snapshot.plan.fingerprint, frozen);
      await t.tap(find.byTooltip('Подробности сессии'));
      await t.pumpAndSettle();
      await t.tap(find.text('Завершить паузу'));
      await settleEngine(t, f);
      expect(f.engine.run!.status, RunStatus.completed);
      expect(find.byKey(const Key('watch-play-pause')), findsNothing);
      await close(t, f);
    },
  );
  testWidgets(
    'P27: indefinite work disables fake extension while allowing manual finish',
    (t) async {
      final f = (await t.runAsync(
        () => Fixture.create(exit: false, unknownWork: true),
      ))!;
      await open(t, f);
      expect(f.engine.forecast.progress, isNull);
      expect(find.byKey(const Key('track-seek')), findsNothing);
      await t.tap(find.byTooltip('Подробности сессии'));
      await t.pumpAndSettle();
      final plus = t.widget<TextButton>(
        find.ancestor(
          of: find.text('+5 минут'),
          matching: find.byType(TextButton),
        ),
      );
      expect(plus.onPressed, isNull);
      await t.tap(find.text('Завершить паузу'));
      await settleEngine(t, f);
      expect(f.engine.run!.status, RunStatus.completed);
      await close(t, f);
    },
  );
  testWidgets(
    'Task4 counters stay on right, flask percent on left and watch time below its control',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      expect(
        t.getRect(find.byKey(const Key('session-totals'))).left,
        greaterThan(206),
      );
      expect(
        t.getRect(find.byKey(const Key('flask-percent'))).center.dx,
        lessThan(206),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final play = t.getRect(find.byKey(const Key('watch-play-pause'))),
          time = t.getRect(find.byKey(const Key('watch-time')));
      expect(time.top, greaterThanOrEqualTo(play.bottom));
      expect(find.byKey(const Key('watch-next')), findsNothing);
      expect(find.byKey(const Key('watch-previous')), findsNothing);
      await close(t, f);
    },
  );
  testWidgets(
    'Task4 naturally completed phase is green and collapsed; seek-to-end still completes',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      final phase = f.engine.currentEntry!.phase.id;
      await t.runAsync(f.engine.resume);
      await settleEngine(t, f);
      for (var i = 0; i < 2; i++) {
        if (f.engine.run!.phase == 'delay') {
          f.engine.tick();
          await settleEngine(t, f);
        }
        await t.runAsync(
          () => f.engine.seek(const Duration(milliseconds: 64900)),
        );
        f.transport.completed = true;
        f.engine.tick();
        await settleEngine(t, f);
      }
      expect(f.engine.currentEntry!.phase.id, isNot(phase));
      expect(find.text('Личная подготовка — трек 1'), findsNothing);
      expect(find.text('Личная подготовка — трек 2'), findsNothing);
      final row = find.byKey(ValueKey('player-phase-$phase'));
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      final text = t.widget<Text>(
        find.descendant(of: row, matching: find.byType(Text)).first,
      );
      expect(text.style!.color, const Color(0xffa6ed49));
      expect(
        find.text('Личный выход — трек 1'),
        findsOneWidget,
      ); // future remains open
      await close(t, f);
    },
  );
  testWidgets('Task4 manually skipped phase stays incomplete and expanded', (
    t,
  ) async {
    final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
    await open(t, f);
    final phase = f.engine.currentEntry!.phase.id;
    await t.runAsync(() => f.engine.navigate(NavigationUnit.phase, true));
    await settleEngine(t, f);
    final row = find.byKey(ValueKey('player-phase-$phase'));
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.check_circle)),
      findsNothing,
    );
    expect(find.text('Личная подготовка — трек 1'), findsOneWidget);
    expect(find.text('Личная подготовка — трек 2'), findsOneWidget);
    await close(t, f);
  });
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    for (final scale in [1.0, 1.3]) {
      for (final longSession in [false, true]) {
        testWidgets('Task12 $size scale=$scale long=$longSession', (t) async {
          final f = (await t.runAsync(
            () => Fixture.create(workTracks: 3, longSession: longSession),
          ))!;
          await open(t, f, size: size, scale: scale, systemBars: true);
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await t.pumpAndSettle();
          expect(f.engine.timeline.phases.length, longSession ? 6 : 3);
          expect(
            find.byKey(const Key('finish-session')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('watch-play-pause')).hitTestable(),
            findsOneWidget,
          );
          final left = t.getRect(find.byKey(const Key('phase-scale')));
          final right = t.getRect(find.byKey(const Key('player-context')));
          expect(left.right, lessThanOrEqualTo(right.left));
          expect(t.takeException(), isNull);
          const output = String.fromEnvironment('SULFI_TASK12_SCREENSHOTS');
          if (output.isNotEmpty) {
            await t.runAsync(() async {
              final b = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('player-capture')),
              );
              final image = await b.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final path = Directory(output);
              await path.create(recursive: true);
              await File(
                '${path.path}/${size.width.toInt()}x${size.height.toInt()}-$scale-${longSession ? 'long' : 'short'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await close(t, f);
        });
      }
    }
  }
  Future<void> capture13(WidgetTester t, String name) async {
    const output = String.fromEnvironment('SULFI_TASK13_SCREENSHOTS');
    if (output.isEmpty) return;
    // Repaint retained text layers after playback/scroll changes before readback.
    // This changes the test capture only, not application rendering or state.
    void repaint(RenderObject node) {
      node.visitChildren(repaint);
      node.markNeedsPaint();
    }

    repaint(
      t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('player-capture')),
      ),
    );
    await t.pump();
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('player-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  String timer(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('current-track-time'))).data!;
  for (final size in [const Size(360, 800), const Size(412, 915)]) {
    for (final scale in [1.0, 1.3]) {
      for (final mixed in [false, true]) {
        testWidgets('Task13 matrix $size $scale mixed=$mixed', (t) async {
          final f = (await t.runAsync(
            () => Fixture.create(shortPhase: !mixed, mixed: mixed),
          ))!;
          await open(t, f, size: size, scale: scale, systemBars: true);
          expect(f.engine.timeline.phases.length, mixed ? 6 : 1);
          expect(
            find.byKey(const Key('finish-session')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('watch-play-pause')).hitTestable(),
            findsOneWidget,
          );
          final context = find.byKey(const Key('player-context'));
          expect(
            find.descendant(
              of: context,
              matching: find.byKey(const Key('current-track-time')),
            ),
            findsOneWidget,
          );
          final clock = t.getRect(find.byKey(const Key('watch-time')));
          final ring = t.getRect(find.byKey(const Key('track-seek')));
          expect(clock.overlaps(ring), isFalse);
          final time = t.widget<Text>(
            find.byKey(const Key('current-track-time')),
          );
          expect(time.style!.fontSize, 30);
          expect(time.style!.color, const Color(0xffffe34d));
          expect(
            t.getRect(find.byKey(const Key('phase-scale'))).right,
            lessThanOrEqualTo(t.getRect(context).left),
          );
          if (mixed) {
            final phase = f.engine.timeline.phases.first;
            final children = phase.children;
            expect(children.map((x) => x.isModule).toList(), [
              false,
              true,
              false,
              true,
              false,
            ]);
            final module = find.byKey(
              ValueKey('module-group-${children[1].id}'),
            );
            expect(
              find.descendant(of: module, matching: find.text('Веки тест 1')),
              findsOneWidget,
            );
            expect(
              find.descendant(of: module, matching: find.text('Прямой фокус')),
              findsNothing,
            );
            expect(
              find.descendant(of: module, matching: find.text('Пауза')),
              findsNothing,
            );
            expect(find.textContaining('Модуль: Модуль:'), findsNothing);
            final direct = f.engine.timeline.entries.first;
            final directRow = find
                .byWidgetPredicate(
                  (w) =>
                      w is Semantics &&
                      (w.properties.label ?? '').startsWith('Прямой фокус.'),
                )
                .first;
            final numbers = find.descendant(
              of: directRow,
              matching: find.text('1:05'),
            );
            expect(
              t.widget<Text>(numbers).style!.color,
              const Color(0xffff168f),
            );
            expect(direct.moduleId, isNull);
          }
          expect(t.takeException(), isNull);
          await capture13(
            t,
            '${size.width.toInt()}x${size.height.toInt()}-$scale-${mixed ? 'mixed-six-phases' : 'short'}',
          );
          await close(t, f);
        });
      }
    }
  }
  testWidgets(
    'Task13 timer playing pause ring seek and next track use same source',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(mixed: true)))!;
      await open(t, f);
      expect(timer(t), '0:00 / 1:05');
      await t.runAsync(f.engine.resume);
      await settleEngine(t, f);
      f.transport.position = const Duration(seconds: 6);
      f.engine.tick();
      await t.pump();
      expect(timer(t), '0:06 / 1:05');
      await t.runAsync(f.engine.pause);
      await settleEngine(t, f);
      f.clock.value += 2000;
      f.engine.tick();
      await t.pump();
      expect(timer(t), '0:06 / 1:05');
      final ring = t.getRect(find.byKey(const Key('track-seek')));
      await t.tapAt(
        ring.topLeft +
            Offset(ring.width * (221.5 + 164) / 470, ring.height * 318.5 / 595),
      );
      await settleEngine(t, f);
      expect(timer(t), '0:16 / 1:05');
      await t.tap(find.byKey(const Key('nav-track-next')));
      await settleEngine(t, f);
      expect(timer(t), '0:00 / 1:05');
      expect(f.engine.currentEntry!.moduleId, isNotNull);
      expect(find.textContaining('Модуль: Модуль:'), findsNothing);
      await capture13(t, 'current-in-module');
      await close(t, f);
    },
  );
  testWidgets('Task13 pause element elapsed total and unknown duration', (
    t,
  ) async {
    final f = (await t.runAsync(
      () => Fixture.create(shortPhase: true, pauseOnly: true),
    ))!;
    await open(t, f);
    expect(timer(t), '0:00 / 0:08');
    await t.runAsync(f.engine.resume);
    await settleEngine(t, f);
    f.clock.value += 2000;
    f.engine.tick();
    await t.pump();
    expect(timer(t), '0:02 / 0:08');
    await capture13(t, 'pause-element');
    await close(t, f);
    final unknown = (await t.runAsync(
      () => Fixture.create(unknownWork: true),
    ))!;
    await open(t, unknown);
    expect(timer(t), '0:00 / ≈');
    await close(t, unknown);
  });
  testWidgets(
    'Task13 completed module reopens green with green child durations',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(mixed: true)))!;
      await open(t, f);
      await t.runAsync(f.engine.resume);
      await settleEngine(t, f);
      for (var i = 0; i < 6; i++) {
        if (f.engine.run!.phase == 'delay') {
          f.engine.tick();
          await settleEngine(t, f);
        }
        f.clock.value += 65000;
        await t.runAsync(
          () => f.engine.seek(const Duration(milliseconds: 64900)),
        );
        f.transport.completed = true;
        f.engine.tick();
        await settleEngine(t, f);
      }
      if (f.engine.run!.phase == 'delay') {
        f.engine.tick();
        await settleEngine(t, f);
      }
      await t.runAsync(f.engine.pause);
      await settleEngine(t, f);
      expect(f.engine.step!.kind, StepKind.silence);
      expect(timer(t), '0:00 / 0:41');
      final moduleId = f.engine.timeline.phases.first.children[1].id;
      final moduleRow = find.byKey(ValueKey('player-module-$moduleId'));
      expect(
        find.text('Веки тест 1'),
        findsNWidgets(5),
      ); // only the five future phases remain expanded
      await t.ensureVisible(moduleRow);
      await t.tap(moduleRow);
      await t.pumpAndSettle();
      final group = find.byKey(ValueKey('module-group-$moduleId'));
      expect(
        find.descendant(of: group, matching: find.text('Веки тест 1')),
        findsOneWidget,
      );
      for (final text in t.widgetList<Text>(
        find.descendant(of: group, matching: find.byType(Text)),
      )) {
        expect(text.style!.color, const Color(0xffa6ed49));
      }
      await t.ensureVisible(
        find.byKey(
          ValueKey('player-phase-${f.engine.timeline.phases.first.id}'),
        ),
      );
      await t.pumpAndSettle();
      await capture13(t, 'completed-green-manually-expanded');
      await t.tap(moduleRow);
      await t.pump();
      expect(
        find.descendant(of: group, matching: find.text('Веки тест 1')),
        findsNothing,
      );
      await close(t, f);
    },
  );
  testWidgets(
    'Task13 hour timer fits narrow summary and semantic yellow stays local',
    (t) async {
      final f = (await t.runAsync(
        () => Fixture.create(
          shortPhase: true,
          pauseOnly: true,
          pauseDurationMs: 4215000,
        ),
      ))!;
      await open(
        t,
        f,
        size: const Size(360, 800),
        scale: 1.3,
        systemBars: true,
      );
      await t.runAsync(f.engine.resume);
      await settleEngine(t, f);
      f.clock.value += 3723000;
      f.engine.tick();
      await settleEngine(t, f);
      expect(timer(t), '1:02:03 / 1:10:15');
      final frame = t.getRect(find.byKey(const Key('player-context')));
      final time = t.getRect(find.byKey(const Key('watch-time')));
      expect(time.left, greaterThanOrEqualTo(frame.left));
      expect(time.right, lessThanOrEqualTo(frame.right));
      final totals = t.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('session-totals')),
          matching: find.byType(Text),
        ),
      );
      expect(
        totals.where((x) => x.style?.color == const Color(0xffffe34d)).length,
        3,
      );
      final previous = t.widget<OutlinedButton>(
        find.byKey(const Key('nav-track-previous')),
      );
      expect(
        previous.style!.foregroundColor!.resolve({WidgetState.disabled}),
        const Color(0xff66555f),
      );
      expect(t.takeException(), isNull);
      await capture13(t, 'hour-timer-narrow');
      await close(t, f);
    },
  );
  testWidgets('optional V41 rendered screenshots', (t) async {
    const output = String.fromEnvironment('SULFI_V41_SCREENSHOTS');
    if (output.isEmpty) return;
    const font = String.fromEnvironment('SULFI_TEST_FONT');
    if (font.isNotEmpty) {
      final bytes = await t.runAsync(() => File(font).readAsBytes());
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes!)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final f = (await t.runAsync(() => Fixture.create(workTracks: 4)))!;
    await open(t, f);
    Future<void> capture(String name) async {
      await t.pump();
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('player-capture')),
        );
        final picture = await boundary
            .toImage(pixelRatio: 2)
            .timeout(const Duration(seconds: 10));
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final path = Directory(output);
        await path.create(recursive: true);
        await File('${path.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    await capture('player-zero');
    await t.runAsync(() => f.engine.navigate(NavigationUnit.phase, true));
    await t.pumpAndSettle();
    await capture('player-paused');
    await t.runAsync(f.engine.interrupt);
    await t.pumpAndSettle();
    await capture('player-interrupted');
    await t.runAsync(() async {
      await f.controller.clearPlan();
      final phase = await f.controller.createPhase('work');
      await f.controller.addLoose(
        phase,
        const SessionStep(
          id: 'render-time',
          kind: StepKind.silence,
          title: 'Тихий интервал',
          durationMs: 100000,
        ),
      );
      await f.engine.start();
      f.engine.tick();
      await f.engine.flush();
      f.clock.value = 25000;
      f.engine.tick();
      await f.engine.flush();
    });
    await t.pumpAndSettle();
    await capture('player-25');
    await t.runAsync(() async {
      f.clock.value = 75000;
      f.engine.tick();
      await f.engine.flush();
    });
    await t.pumpAndSettle();
    await capture('player-75');
    await t.runAsync(() async {
      f.clock.value = 100000;
      f.engine.tick();
      await f.engine.flush();
    });
    await t.pumpAndSettle();
    await capture('player-completed');
    await close(t, f);
  });
}
