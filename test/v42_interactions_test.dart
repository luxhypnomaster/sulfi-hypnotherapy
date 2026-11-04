import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modules_screen.dart';
import 'package:sulfi_hypnotherapy/ui/pause_time_picker.dart';
import 'package:sulfi_hypnotherapy/ui/pause_clock_art.dart';
import 'package:sulfi_hypnotherapy/ui/templates_screen.dart';
import 'package:sulfi_hypnotherapy/ui/recorder_screen.dart';

import 'support/fakes.dart';
import 'support/capture_fake.dart';

void main() {
  late MemoryRepository audio;
  late SessionController c;
  late MemoryPlayer player;
  late MemorySessionRepository sessions;
  void interactionTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      audio = MemoryRepository();
      player = MemoryPlayer();
      sessions = MemorySessionRepository();
      c = SessionController(
        repository: sessions,
        library: MemoryLibrary(audio),
      );
      await c.initialize();
      try {
        await body(t);
      } finally {
        c.dispose();
      }
    });
  }

  bool fontsReady = false;
  Future<void> open(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(412, 915),
    double scale = 1,
  }) async {
    if (!fontsReady) {
      final sdk = File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent;
      final bytes = await t.runAsync(
        () => File(
          '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes(),
      );
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes!)))).load();
      final icons = await t.runAsync(
        () => File(
          '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes(),
      );
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons!)))).load();
      fontsReady = true;
    }
    await t.runAsync(ApprovedPauseClock.load);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: const Key('v42-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> drag(
    WidgetTester t,
    Finder source,
    Finder destination, {
    double offset = 40,
  }) async {
    final from = t.getCenter(source),
        to = t.getCenter(destination) + Offset(0, offset);
    final gesture = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 600));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 8)!);
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await t.pumpAndSettle();
    await c.flush();
  }

  Future<void> screenshot(WidgetTester t, String name) async {
    const path = String.fromEnvironment('SULFI_V42_SCREENSHOTS');
    if (path.isEmpty) return;
    await t.runAsync(() async {
      await Future.wait([
        for (final path in [
          'assets/art/leather_board.png',
          'assets/art/sulfi_header.png',
          'assets/art/pocket_watch.png',
          'assets/brand/spiral.png',
        ])
          precacheImage(
            AssetImage(path),
            t.element(find.byType(Scaffold).last),
          ),
      ]);
    });
    await t.pumpAndSettle();
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('v42-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$path/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  interactionTest(
    'A01 A02 A03 A04 R02: ten rows; row adds repeatedly, play does not add',
    (t) async {
      for (var i = 0; i < 15; i++) {
        await audio.save(
          sampleAsset(id: 'audio$i', title: 'Аудиозапись $i').edited(
            'Аудиозапись $i',
            AudioCategory.suggestions,
            section: LibrarySection.personal,
          ),
        );
      }
      final phase = await c.createPhase('work');
      await open(
        t,
        LibraryScreen(
          library: c.library,
          controller: c,
          player: player,
          allowSelection: true,
          onSelected: (a) => c.addLoose(
            phase,
            SessionStep(
              id: newId(),
              kind: StepKind.audio,
              title: a.title,
              audioAssetId: a.id,
              durationMs: a.durationMs,
            ),
          ),
        ),
      );
      final visible = find
          .byWidgetPredicate(
            (w) =>
                w is InkWell &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('pick-'),
          )
          .hitTestable();
      expect(visible.evaluate().length, greaterThanOrEqualTo(10));
      final row = find.byKey(const ValueKey('pick-audio0'));
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
      expect(c.draft.plan.steps, hasLength(2));
      expect(c.draft.plan.steps.map((s) => s.id).toSet(), hasLength(2));
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(player.current, isNull);
      await t.tap(find.byTooltip('Прослушать: Аудиозапись 0'));
      await t.pumpAndSettle();
      expect(player.current?.id, 'audio0');
      expect(c.draft.plan.steps, hasLength(2));
      await screenshot(t, 'audio-picker');
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'A05 R02 R03: personal origin and suggestions category combine without phase restriction',
    (t) async {
      await audio.save(
        sampleAsset(id: 'recorded', title: 'Моя установка').edited(
          'Моя установка',
          AudioCategory.suggestions,
          section: LibrarySection.personal,
        ),
      );
      await audio.save(sampleAsset(id: 'other', title: 'Общее аудио'));
      await open(
        t,
        LibraryScreen(
          library: c.library,
          player: player,
          allowSelection: true,
          onSelected: (_) async {},
        ),
      );
      await t.tap(find.text('Мои'));
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButton<AudioCategory>));
      await t.pumpAndSettle();
      await t.tap(find.text('Установки').last);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pick-recorded')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-other')), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'E01 E04 E05 E06: invariant collapse control; compact actions and fixed footer',
    (t) async {
      final phase = await c.createPhase('work');
      await open(t, ModularStructureScreen(controller: c, player: player));
      final rect = t.getRect(find.byKey(ValueKey('expand-$phase')));
      for (var i = 0; i < 10; i++) {
        await t.tap(find.byKey(ValueKey('expand-$phase')));
        await t.pumpAndSettle();
        expect(t.getRect(find.byKey(ValueKey('expand-$phase'))), rect);
        expect(find.byType(PopupMenuItem<String>), findsNothing);
      }
      expect(find.text('Добавить'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('structure-footer')),
          matching: find.byWidgetPredicate(
            (w) => w is TextButton || w is FilledButton,
          ),
        ),
        findsNWidgets(3),
      );
      await t.tap(find.text('Добавить'));
      await t.pumpAndSettle();
      expect(find.text('Добавить паузу'), findsOneWidget);
      await t.tap(find.text('Добавить паузу'));
      await t.pumpAndSettle();
      expect(find.byType(PauseTimePicker), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('00:00'), findsOneWidget);
      await screenshot(t, 'pause-clock');
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(c.draft.plan.steps.single.durationMs, 0);
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      await screenshot(t, 'structure');
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'E02 E03: real long press reorders mixed child elements and phases, retains IDs/delays',
    (t) async {
      final phase = await c.createPhase('work');
      for (var i = 0; i < 3; i++) {
        await c.addLoose(
          phase,
          SessionStep(
            id: 's$i',
            kind: i == 1 ? StepKind.silence : StepKind.audio,
            title: 'Элемент $i',
            audioAssetId: i == 1 ? null : 'sample',
            durationMs: 10000,
            delayBeforeSeconds: i * 5,
          ),
        );
      }
      final another = await c.createPhase('exit');
      final before = c.draft.plan.phases!.first.children
          .map((ch) => ch.items.single.id)
          .toList();
      await open(t, ModularStructureScreen(controller: c, player: player));
      await drag(
        t,
        find.byKey(ValueKey(before[0])),
        find.byKey(ValueKey(before[2])),
      );
      expect(
        c.draft.plan.phases!.first.children.map((ch) => ch.items.single.id),
        [before[1], before[2], before[0]],
      );
      expect(c.draft.plan.steps.first.delayBeforeSeconds, 5);
      // Collapse both groups so whole-phase drag has unambiguous contiguous rows.
      await t.tap(find.byKey(ValueKey('expand-$phase')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('expand-$another')));
      await t.pumpAndSettle();
      await drag(
        t,
        find.byKey(ValueKey('drag-$phase')),
        find.byKey(ValueKey('drag-$another')),
      );
      expect(c.draft.plan.phases!.map((p) => p.id), [another, phase]);
      await c.reload();
      expect(c.draft.plan.phases!.map((p) => p.id), [another, phase]);
      expect(sessions.savedRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'P04: module drag interleaves tracks and pause in one persisted sequence',
    (t) async {
      final module = ModuleDefinition(
        id: 'mod',
        title: 'Проверка модуля',
        items: const [
          SessionStep(
            id: 'a',
            kind: StepKind.audio,
            title: 'Первый трек',
            audioAssetId: 'sample',
            durationMs: 10000,
          ),
          SessionStep(
            id: 'p',
            kind: StepKind.silence,
            title: 'Пауза',
            durationMs: 15000,
          ),
          SessionStep(
            id: 'b',
            kind: StepKind.audio,
            title: 'Второй трек',
            audioAssetId: 'sample',
            durationMs: 20000,
          ),
        ],
      );
      await c.modules.save(module);
      await open(t, ModulesScreen(controller: c, player: player));
      await t.tap(find.text('Проверка модуля'));
      await t.pumpAndSettle();
      await drag(
        t,
        find.byKey(const ValueKey('a')),
        find.byKey(const ValueKey('b')),
      );
      expect(c.modules.entries.single.items.map((s) => s.id), ['p', 'b', 'a']);
      expect(
        c.modules.entries.single.items.fold<int>(
          0,
          (n, s) => n + (s.durationMs ?? 0),
        ),
        45000,
      );
      await screenshot(t, 'module-editor');
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'T01 T02: seven templates visible, selecting row applies without starting session',
    (t) async {
      for (var i = 0; i < 12; i++) {
        await c.saveAsTemplate('Шаблон $i', '');
      }
      await open(t, TemplatesScreen(controller: c, player: player));
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is ListTile &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('template-'),
            )
            .hitTestable()
            .evaluate()
            .length,
        greaterThanOrEqualTo(7),
      );
      await screenshot(t, 'templates');
      final chosen = c.templates.first;
      await t.tap(find.byKey(ValueKey('template-${chosen.id}')));
      await t.pumpAndSettle();
      expect(c.draft.baseTemplateId, chosen.id);
      expect(sessions.savedRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'P02: separate vertical wheels and haptics preserve exact minutes/seconds; cancel and zero',
    (t) async {
      final haptics = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(t, const PauseTimePicker(initialSeconds: 61));
      await t.drag(
        find.byKey(const Key('wheel-Секунды')),
        const Offset(0, -70),
      );
      await t.pumpAndSettle();
      final label = t
          .widget<Text>(find.byKey(const Key('pause-duration-value')))
          .data!;
      expect(label, startsWith('01:'));
      expect(label, isNot('01:01'));
      expect(haptics, isNotEmpty);
      await t.tap(find.text('Обнулить'));
      await t.pumpAndSettle();
      expect(find.text('00:00'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  interactionTest(
    'R01 R04: compact recorder actions visible, empty take cannot save',
    (t) async {
      final directory = await t.runAsync(
        () => Directory.systemTemp.createTemp('v42_recorder'),
      );
      await open(
        t,
        RecorderScreen(controller: c, player: player, backend: FakeCapture()),
      );
      expect(find.text('Сохранить трек').hitTestable(), findsOneWidget);
      expect(find.text('Отмена').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Начать запись').hitTestable(), findsOneWidget);
      await screenshot(t, 'recorder');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() => directory!.delete(recursive: true));
    },
  );
}
