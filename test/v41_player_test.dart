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
    'P01 P02 P03 P10 P11 P18 P20 P28: real controls and current phase only',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create()))!;
      await open(t, f);
      expect(find.text('Время трансформации'), findsOneWidget);
      expect(
        t.widget<Text>(find.text('Время трансформации')).style!.color,
        const Color(0xffff168f),
      );
      expect(find.byKey(const Key('watch-play-pause')), findsOneWidget);
      expect(find.text('Завершить сессию'), findsOneWidget);
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
      expect(find.text('Первый рабочий модуль — трек 1'), findsNothing);
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
      expect(find.text('Личная подготовка — трек 2'), findsNothing);
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
      await t.tap(find.text('Завершить сессию'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pumpAndSettle();
      expect(find.text('Перейти к выходу'), findsNothing);
      expect(find.text('Прервать сейчас'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      await t.tap(find.text('Прервать сейчас'));
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
    'P17 P19: slider gesture seeks real transport while staying paused',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      final plays = f.transport.plays;
      await t.drag(find.byKey(const Key('track-seek')), const Offset(35, 0));
      await settleEngine(t, f);
      expect(f.transport.position.inMilliseconds, greaterThan(0));
      expect(f.transport.position.inMilliseconds, lessThanOrEqualTo(65000));
      expect(f.transport.plays, plays);
      expect(f.engine.paused, isTrue);
      await close(t, f);
    },
  );
  testWidgets(
    'P29 P30: available Exit is distinct from cancel and interruption',
    (t) async {
      final f = (await t.runAsync(() => Fixture.create(workTracks: 2)))!;
      await open(t, f);
      Future<void> dialog() async {
        await t.tap(find.text('Завершить сессию'));
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
      await t.tap(find.text('Завершить работу'));
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
      await t.tap(find.text('Завершить работу'));
      await settleEngine(t, f);
      expect(f.engine.run!.status, RunStatus.completed);
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
