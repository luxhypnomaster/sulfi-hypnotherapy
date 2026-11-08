import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/pause_edit_model.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/modules_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/pause_clock_art.dart';
import 'package:sulfi_hypnotherapy/ui/pause_editor.dart';
import 'package:sulfi_hypnotherapy/ui/structure_item_row.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const captureKey = Key('pause-final-capture');
  final artifactDir = Platform.environment['SULFI_PAUSE_ARTIFACT_DIR'];
  setUpAll(() async {
    await ApprovedPauseClock.load();
    await (FontLoader(
          'PauseSerif',
        )..addFont(rootBundle.load('assets/pause/LiberationSerif-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> open(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(360, 640),
    double textScale = 1,
    double inset = 0,
    double pixelRatio = 1,
    ValueNotifier<Offset?>? touches,
  }) async {
    t.view.devicePixelRatio = pixelRatio;
    t.view.physicalSize = size * pixelRatio;
    t.view.padding = FakeViewPadding(
      top: inset * pixelRatio,
      bottom: inset * pixelRatio,
    );
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    await t.pumpWidget(
      Listener(
        onPointerDown: (e) => touches?.value = e.position,
        onPointerMove: (e) => touches?.value = e.position,
        onPointerUp: (_) => touches?.value = null,
        onPointerCancel: (_) => touches?.value = null,
        child: RepaintBoundary(
          key: captureKey,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: sulfiTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: screen,
                ),
                if (touches != null)
                  ValueListenableBuilder(
                    valueListenable: touches,
                    builder: (context, point, _) => point == null
                        ? const SizedBox()
                        : Positioned(
                            left: point.dx - 12,
                            top: point.dy - 12,
                            child: IgnorePointer(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x55FFFFFF),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder wheel(bool minute) =>
      find.byKey(Key('wheel-${minute ? 'Минуты' : 'Секунды'}'));
  String value(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('pause-duration-value'))).data!;
  Future<void> saveImage(
    WidgetTester t,
    String path, {
    double ratio = 3,
  }) async {
    await t.pump();
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
          .toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<Uint8List> pixels(WidgetTester t) async => (await t.runAsync(() async {
    final image = await t
        .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
        .toImage();
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;

  test('integer seconds are the only value; existing 06:32 is not rounded', () {
    final m = PauseEditModel(392);
    addTearDown(m.dispose);
    expect(m.label, '06:32');
    expect(m.totalSeconds, 392);
    m.turnMinutes(2);
    expect(m.label, '08:32');
    m.turnSeconds(28);
    expect(m.label, '09:00');
    m.turnSeconds(-1);
    expect(m.label, '08:59');
  });
  test('second carry, borrow, lower and existing validated upper limit', () {
    final m = PauseEditModel(59);
    addTearDown(m.dispose);
    m.turnSeconds(1);
    expect(m.label, '01:00');
    m.turnSeconds(-1);
    expect(m.label, '00:59');
    m.turnSeconds(-100);
    expect(m.totalSeconds, 0);
    expect(m.turnSeconds(-1), false);
    m.turnSeconds(100000);
    expect(m.label, '99:55');
    expect(m.turnSeconds(1), false);
  });
  test('minute saturation preserves seconds even near the 99:55 bound', () {
    final m = PauseEditModel(59);
    addTearDown(m.dispose);
    m.turnMinutes(999);
    expect(m.label, '98:59');
    expect(m.turnMinutes(1), false);
    m.turnSeconds(-4);
    m.turnMinutes(1);
    expect(m.label, '99:55');
    m.turnMinutes(-1000);
    expect(m.label, '00:55');
    expect(m.turnMinutes(-1), false);
  });
  test(
    'invalid initial values are rejected instead of silently changing data',
    () {
      expect(() => PauseEditModel(-1), throwsFormatException);
      expect(() => PauseEditModel(5996), throwsFormatException);
      final legacy = PauseEditModel(7201, maxSeconds: 7201);
      addTearDown(legacy.dispose);
      expect(legacy.label, '120:01');
    },
  );

  testWidgets(
    'both wheels update before pointer release; seconds naturally cross a minute',
    (t) async {
      final m = PauseEditModel(59);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      );
      final second = await t.startGesture(t.getCenter(wheel(false)));
      await second.moveBy(const Offset(0, -20));
      await t.pump();
      expect(value(t), '01:00'); // finger is still down
      await second.up();
      await t.pumpAndSettle();
      await t.drag(wheel(true), const Offset(0, -28));
      await t.pumpAndSettle();
      expect(value(t), '03:00');
      await t.drag(wheel(true), const Offset(0, 28));
      await t.pumpAndSettle();
      expect(value(t), '01:00');
      await t.drag(wheel(false), const Offset(0, 20));
      await t.pumpAndSettle();
      expect(value(t), '00:59');
    },
  );
  testWidgets(
    'horizontal movement, eye, background and arrow taps cannot change time',
    (t) async {
      final m = PauseEditModel(70);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      );
      for (final minute in [true, false]) {
        await t.drag(wheel(minute), const Offset(90, 0));
      }
      await t.dragFrom(const Offset(180, 280), const Offset(0, -90));
      await t.dragFrom(const Offset(8, 85), const Offset(0, 50));
      await t.tapAt(const Offset(54, 281));
      await t.tapAt(const Offset(301, 345));
      await t.pumpAndSettle();
      expect(value(t), '01:10');
    },
  );
  testWidgets(
    'small movements accumulate; cancellation and next touch do not reuse residue',
    (t) async {
      final m = PauseEditModel(0);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      );
      final gesture = await t.startGesture(t.getCenter(wheel(false)));
      for (var i = 0; i < 7; i++) {
        await gesture.moveBy(const Offset(0, -4));
        await t.pump();
      }
      expect(m.totalSeconds, 2);
      await gesture.moveBy(const Offset(0, -5));
      await gesture.cancel();
      await t.pump();
      await t.drag(wheel(false), const Offset(0, -20));
      await t.pumpAndSettle();
      expect(m.totalSeconds, 3);
    },
  );
  testWidgets('metal texture moves continuously between numerical detents', (
    t,
  ) async {
    final m = PauseEditModel(0);
    addTearDown(m.dispose);
    await open(
      t,
      ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
    );
    final gesture = await t.startGesture(t.getCenter(wheel(true)));
    await gesture.moveBy(const Offset(0, -20));
    await t.pump();
    final label = value(t), before = await pixels(t);
    await gesture.moveBy(const Offset(0, -2));
    await t.pump();
    expect(value(t), label);
    final after = await pixels(t);
    var changed = 0;
    for (var y = 260; y < 372; y++) {
      for (var x = 60; x < 103; x++) {
        final i = (y * 360 + x) * 4;
        if (before[i] != after[i] ||
            before[i + 1] != after[i + 1] ||
            before[i + 2] != after[i + 2]) {
          changed++;
        }
      }
    }
    expect(changed, greaterThan(100));
    await gesture.up();
    await t.pumpAndSettle();
  });

  for (final density in [2.0, 3.0]) {
    testWidgets('detents use logical finger travel at pixel ratio $density', (
      t,
    ) async {
      final m = PauseEditModel(0);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
        pixelRatio: density,
      );
      await t.drag(wheel(true), const Offset(0, -28));
      await t.pumpAndSettle();
      expect(m.totalSeconds, 120);
    });
  }
  testWidgets('whole visible wheel surface accepts a vertical drag', (t) async {
    final m = PauseEditModel(0);
    addTearDown(m.dispose);
    await open(
      t,
      ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
    );
    for (final minute in [true, false]) {
      for (final offset in [
        const Offset(-42, 0),
        const Offset(40, 0),
        const Offset(0, -42),
      ]) {
        await t.dragFrom(
          t.getCenter(wheel(minute)) + offset,
          const Offset(0, -20),
        );
        await t.pumpAndSettle();
      }
    }
    expect(m.label, '03:03');
  });
  testWidgets('accepted detents request haptics; stopped wheels do not', (
    t,
  ) async {
    var clicks = 0;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') clicks++;
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final m = PauseEditModel(5995);
    addTearDown(m.dispose);
    await open(
      t,
      ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
    );
    await t.drag(wheel(false), const Offset(0, -28));
    await t.pumpAndSettle();
    expect(clicks, 0);
    expect(m.label, '99:55');
    await t.drag(wheel(false), const Offset(0, 28));
    await t.pumpAndSettle();
    expect(clicks, 2);
    expect(m.label, '99:53');
  });
  testWidgets(
    'screen has one timer, exactly three actions and no forms or scroll',
    (t) async {
      final m = PauseEditModel(392);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      );
      expect(find.text('06:32'), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(3));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Scrollable), findsNothing);
      expect(find.text('До паузы'), findsNothing);
      expect(find.text('Вручную'), findsNothing);
      if (artifactDir != null) {
        await saveImage(t, '$artifactDir/pause-06-32.png');
      }
    },
  );
  testWidgets(
    'accessible increase/decrease changes seconds without visible extra controls',
    (t) async {
      final handle = t.ensureSemantics();
      final m = PauseEditModel(59);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      );
      final node = t.getSemantics(find.bySemanticsLabel('Секунды'));
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.increase),
        true,
      );
      node.owner!.performAction(node.id, ui.SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(value(t), '01:00');
      node.owner!.performAction(node.id, ui.SemanticsAction.decrease);
      await t.pumpAndSettle();
      expect(value(t), '00:59');
      handle.dispose();
    },
  );
  for (final size in [
    const Size(360, 640),
    const Size(320, 600),
    const Size(412, 915),
  ]) {
    testWidgets('safe area and large text keep actions visible at $size', (
      t,
    ) async {
      final m = PauseEditModel(5995);
      addTearDown(m.dispose);
      await open(
        t,
        ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
        size: size,
        textScale: 2,
        inset: 24,
      );
      for (final label in ['Обнулить', 'Отмена', 'Применить']) {
        final button = find.widgetWithText(TextButton, label);
        expect(button.hitTestable(), findsOneWidget);
        final rect = t.getRect(button);
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
      }
      expect(t.takeException(), isNull);
      if (artifactDir != null && size.width == 412) {
        await saveImage(t, '$artifactDir/pause-tall-large-text.png', ratio: 2);
      }
    });
  }

  testWidgets(
    'pre-track Apply, reopen, reset/cancel, reset/apply and system back preserve the correct object',
    (t) async {
      final audio = MemoryRepository();
      await audio.save(sampleAsset());
      final repository = MemorySessionRepository();
      final c = SessionController(
        repository: repository,
        library: MemoryLibrary(audio),
      );
      await c.initialize();
      addTearDown(c.dispose);
      await c.addAudio(sampleAsset());
      final id = c.draft.plan.steps.single.id;
      await c.setDelay(id, 59);
      final player = MemoryPlayer();
      await open(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Открыть паузу'),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PauseEditor(controller: c, stepId: id, player: player),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> enter() async {
        await t.tap(find.text('Открыть паузу'));
        await t.pumpAndSettle();
      }

      await enter();
      expect(value(t), '00:59');
      await t.drag(wheel(false), const Offset(0, -20));
      await t.pumpAndSettle();
      expect(value(t), '01:00');
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 59);
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 60);
      await enter();
      expect(value(t), '01:00');
      await t.tap(find.text('Обнулить'));
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 60);
      await enter();
      await t.tap(find.text('Обнулить'));
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      await enter();
      await t.drag(wheel(false), const Offset(0, -28));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      expect(repository.savedRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'module pauses retain pending IDs/duration until explicit module Apply',
    (t) async {
      final c = SessionController(
        repository: MemorySessionRepository(),
        library: MemoryLibrary(MemoryRepository()),
      );
      await c.initialize();
      addTearDown(c.dispose);
      await c.modules.save(
        ModuleDefinition(id: 'test-module', title: 'Модуль проверки'),
      );
      await open(
        t,
        ModulesScreen(controller: c, player: MemoryPlayer()),
        size: const Size(412, 915),
      );
      await t.tap(find.text('Модуль проверки'));
      await t.pumpAndSettle();
      Future<void> addPause(int pixels) async {
        await t.tap(find.text('Добавить паузу'));
        await t.pumpAndSettle();
        expect(find.byType(ApprovedPauseClock), findsOneWidget);
        await t.drag(wheel(false), Offset(0, -pixels.toDouble()));
        await t.pumpAndSettle();
        await t.tap(find.text('Применить'));
        await t.pumpAndSettle();
      }

      await addPause(28);
      final first = t
          .widget<StructureItemRow>(find.byType(StructureItemRow))
          .step;
      expect(first.durationMs, 2000);
      expect(c.modules.entries.single.items, isEmpty);
      await t.tap(find.byTooltip('Изменить длительность паузы'));
      await t.pumpAndSettle();
      expect(value(t), '00:02');
      await t.tap(find.text('Обнулить'));
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<StructureItemRow>(find.byType(StructureItemRow))
            .step
            .durationMs,
        2000,
      );
      await addPause(70);
      final second = t
          .widgetList<StructureItemRow>(find.byType(StructureItemRow))
          .last
          .step;
      expect(second.durationMs, 5000);
      final from = t.getCenter(find.byKey(ValueKey('drag-${first.id}'))),
          to =
              t.getCenter(find.byKey(ValueKey('drag-${second.id}'))) +
              const Offset(0, 20);
      final gesture = await t.startGesture(from);
      await gesture.moveBy(const Offset(0, 24));
      await t.pump(const Duration(milliseconds: 50));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(
          Offset.lerp(from + const Offset(0, 24), to, i / 8)!,
        );
        await t.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        t
            .widgetList<StructureItemRow>(find.byType(StructureItemRow))
            .map((w) => w.step.durationMs),
        [5000, 2000],
      );
      await t.tap(
        find.descendant(
          of: find.byKey(ValueKey(second.id)),
          matching: find.byTooltip('Действия элемента'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Удалить ссылку из модуля'));
      await t.pumpAndSettle();
      expect(
        t.widget<StructureItemRow>(find.byType(StructureItemRow)).step.id,
        first.id,
      );
      await t.tap(find.text('Сохранить\nизменения'));
      await t.pumpAndSettle();
      expect(c.modules.entries.single.items.single.id, first.id);
      expect(c.modules.entries.single.items.single.durationMs, 2000);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'session clock edits remain staged until structure Apply and retain ID',
    (t) async {
      final c = SessionController(
        repository: MemorySessionRepository(),
        library: MemoryLibrary(MemoryRepository()),
      );
      await c.initialize();
      addTearDown(c.dispose);
      await c.createPhase('work');
      await open(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
        size: const Size(412, 915),
      );
      await t.tap(find.text('Добавить'));
      await t.pumpAndSettle();
      await t.tap(find.text('Добавить паузу'));
      await t.pumpAndSettle();
      await t.drag(wheel(false), const Offset(0, -28));
      await t.pumpAndSettle();
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      final saved = t
          .widget<StructureItemRow>(find.byType(StructureItemRow))
          .step;
      expect(saved.durationMs, 2000);
      expect(c.draft.plan.steps, isEmpty);
      await t.tap(find.byKey(ValueKey('menu-${saved.id}')));
      await t.pumpAndSettle();
      await t.tap(find.text('Изменить длительность'));
      await t.pumpAndSettle();
      expect(value(t), '00:02');
      await t.tap(find.text('Обнулить'));
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.id, saved.id);
      expect(c.draft.plan.steps.single.durationMs, 0);
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('working screen and real pointer gesture demonstration', (
    t,
  ) async {
    final m = PauseEditModel(58);
    addTearDown(m.dispose);
    final touches = ValueNotifier<Offset?>(null);
    addTearDown(touches.dispose);
    await open(
      t,
      ApprovedPauseClock(model: m, onCancel: () {}, onApply: () {}),
      touches: touches,
    );
    var frame = 0;
    Future<void> capture() async {
      if (artifactDir != null) {
        await saveImage(
          t,
          '$artifactDir/frames/${(frame++).toString().padLeft(4, '0')}.png',
          ratio: 2,
        );
      }
    }

    Future<void> hold(int n) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 80));
        await capture();
      }
    }

    Future<void> turn(bool minute, int pixels) async {
      final pointer = await t.startGesture(t.getCenter(wheel(minute)));
      await hold(2);
      final count = pixels.abs() ~/ 7;
      for (var i = 0; i < count; i++) {
        await pointer.moveBy(Offset(0, pixels.sign * 7.0));
        await t.pump();
        await capture();
      }
      await pointer.up();
      await hold(5);
    }

    if (artifactDir != null) await saveImage(t, '$artifactDir/pause-00-58.png');
    await hold(6);
    await turn(true, -84);
    expect(m.label, '06:58');
    await turn(false, -84);
    expect(m.label, '07:04');
    await turn(false, 84);
    expect(m.label, '06:58');
    await turn(true, 84);
    expect(m.label, '00:58');
    await t.tap(find.text('Обнулить'));
    await hold(6);
    expect(m.label, '00:00');
    if (artifactDir != null) await saveImage(t, '$artifactDir/pause-00-00.png');
    await t.pumpWidget(const SizedBox());
  });
}
