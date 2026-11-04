import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/services/pause_edit_model.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/pause_editor.dart';
import 'package:sulfi_hypnotherapy/ui/structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/templates_screen.dart';

import 'support/fakes.dart';

void main() {
  late MemoryRepository audio;
  late MemorySessionRepository repository;
  late MemoryLibrary library;
  late MemoryPlayer player;
  late SessionController c;
  setUp(() async {
    audio = MemoryRepository();
    repository = MemorySessionRepository();
    library = MemoryLibrary(audio);
    player = MemoryPlayer();
    await audio.save(sampleAsset());
  });
  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: sulfiTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> manual(
    WidgetTester tester,
    String minutes,
    String seconds,
  ) async {
    await tester.tap(find.byKey(const Key('pause-time-input')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), minutes);
    await tester.enterText(find.byType(TextFormField).at(1), seconds);
    await tester.tap(find.text('Установить'));
    await tester.pumpAndSettle();
  }

  test(
    'minute and second wheels are independent, wrap seconds and clamp minutes',
    () {
      final m = PauseEditModel(6 * 60 + 55);
      m.turnSeconds(1);
      expect(m.label, '06:00');
      m.turnSeconds(-1);
      expect(m.label, '06:55');
      m.turnMinutes(1);
      expect(m.label, '07:55');
      m.turnMinutes(-99);
      expect(m.label, '00:55');
      expect(m.turnMinutes(-1), isFalse);
      m.manual(6, 32);
      expect(m.label, '06:30');
      m.reset();
      expect(m.label, '00:00');
      m.dispose();
    },
  );
  void workspaceTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      c = SessionController(repository: repository, library: library);
      await c.initialize();
      try {
        await body(tester);
      } finally {
        c.dispose();
      }
    });
  }

  workspaceTest(
    'home has one navigation row and opening it does not create a history record',
    (tester) async {
      await open(
        tester,
        SulfiApp(library: library, player: player, controller: c),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сульфи'), findsOneWidget);
      expect(find.text('Ваш внутренний\nнавигатор'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('История'), findsOneWidget);
      expect(repository.savedRuns, isEmpty);
      expect(await repository.nextNumber(), 1);
      await open(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  workspaceTest(
    'small phone keeps start and navigation visible and returns from clock through structure',
    (tester) async {
      for (var i = 0; i < 6; i++) {
        final asset = sampleAsset(id: 'navigation$i', title: 'Трек ${i + 1}');
        await audio.save(asset);
        await c.addAudio(asset);
      }
      await c.reload();
      await open(
        tester,
        SulfiApp(library: library, player: player, controller: c),
      );
      tester.view.physicalSize = const Size(360, 720);
      await tester.pumpAndSettle();
      for (final label in [
        'НАЧАТЬ ТРАНСФОРМАЦИЮ',
        'Библиотека',
        'Шаблоны',
        'История',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(
        find.byKey(const Key('active-template')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Структура сессии'));
      await tester.pumpAndSettle();
      expect(find.byType(ModularStructureScreen), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(Key('pause-${c.draft.plan.steps.first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('pause-${c.draft.plan.steps.first.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(PauseEditor), findsOneWidget);
      expect(
        player.current,
        isNull,
      ); // Opening the mini-player never autoplays.
      await tester.tap(find.byTooltip('Прослушать трек'));
      await tester.pumpAndSettle();
      expect(player.current?.id, 'navigation0');
      await tester.tap(find.byTooltip('Закрыть редактор паузы'));
      await tester.pumpAndSettle();
      expect(find.byType(PauseEditor), findsNothing);
      expect(player.current, isNull);
      await tester.tap(find.byTooltip('Назад').last);
      await tester.pumpAndSettle();
      expect(find.text('НАЧАТЬ ТРАНСФОРМАЦИЮ').hitTestable(), findsOneWidget);
      expect(repository.savedRuns, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  workspaceTest(
    'default sections are described and section add assigns a zero pause',
    (tester) async {
      final fingerprint = c.draft.plan.fingerprint;
      await open(tester, StructureScreen(controller: c, player: player));
      for (final group in defaultStageGroups) {
        expect(find.text(group.name), findsOneWidget);
        expect(find.text(group.description), findsOneWidget);
      }
      expect(c.draft.plan.fingerprint, fingerprint);
      await tester.tap(find.byTooltip('Добавить трек: Подготовка'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pick-${sampleAsset().id}')));
      await tester.pumpAndSettle();
      final step = c.draft.plan.steps.single;
      expect(c.draft.plan.groupName(step.groupId), 'Подготовка');
      expect(step.delayBeforeSeconds, 0);
      expect(find.byKey(Key('pause-${step.id}')).hitTestable(), findsOneWidget);
      expect(repository.savedRuns, isEmpty);
    },
  );
  workspaceTest(
    'session card distinguishes empty plan and duration with explicit units',
    (tester) async {
      await open(
        tester,
        SulfiApp(library: library, player: player, controller: c),
      );
      expect(find.textContaining('0 треков'), findsOneWidget);
      expect(find.textContaining('Добавьте фазу'), findsOneWidget);
      await c.addAudio(sampleAsset());
      await tester.pumpAndSettle();
      expect(find.textContaining('1 мин 05 с'), findsOneWidget);
      expect(find.text('Треки не добавлены'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  workspaceTest(
    'clock stays on one screen and only vertical wheel drags change local time',
    (tester) async {
      await c.addAudio(sampleAsset());
      final id = c.draft.plan.steps.single.id;
      await open(
        tester,
        PauseEditor(controller: c, stepId: id, player: player),
      );
      for (final scale in [1.0, 1.6]) {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(PauseEditor),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        expect(find.text('Применить').hitTestable(), findsOneWidget);
        expect(find.text('Обнулить').hitTestable(), findsOneWidget);
        expect(find.byTooltip('Прослушать трек').hitTestable(), findsOneWidget);
        final initial = tester.getCenter(
          find.byKey(const Key('pause-time-input')),
        );
        await tester.dragFrom(const Offset(4, 220), const Offset(0, -90));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const Key('pause-time-input'))),
          initial,
        );
        await tester.drag(
          find.byKey(const Key('wheel-Минуты')),
          const Offset(80, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('00:00'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('wheel-Минуты')),
          const Offset(0, -70),
        );
        await tester.pumpAndSettle();
        final minutes = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('pause-time-input')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(minutes, isNot('00:00'));
        expect(minutes.endsWith(':00'), isTrue);
        await tester.drag(
          find.byKey(const Key('wheel-Секунды')),
          const Offset(0, -70),
        );
        await tester.pumpAndSettle();
        final both = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('pause-time-input')),
                matching: find.byType(Text),
              ),
            )
            .data!;
        expect(both.split(':').first, minutes.split(':').first);
        expect(both.endsWith(':00'), isFalse);
        expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
        await tester.tap(find.text('Обнулить'));
        await tester.pumpAndSettle();
        expect(find.text('00:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetPadding();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  workspaceTest(
    'clock neighbor buttons preview the adjacent files without starting a session',
    (tester) async {
      for (var i = 0; i < 2; i++) {
        final a = sampleAsset(id: 'neighbor$i', title: 'Трек $i');
        await audio.save(a);
        await c.addAudio(a);
      }
      await c.reload();
      await open(
        tester,
        PauseEditor(
          controller: c,
          stepId: c.draft.plan.steps[1].id,
          player: player,
        ),
      );
      await tester.tap(find.text('До паузы'));
      await tester.pumpAndSettle();
      expect(player.current?.id, 'neighbor0');
      await tester.tap(find.text('После паузы'));
      await tester.pumpAndSettle();
      expect(player.current?.id, 'neighbor1');
      expect(repository.savedRuns, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  workspaceTest(
    'structure imports a selection from real library UI with zero initial delay',
    (tester) async {
      await open(tester, StructureScreen(controller: c, player: player));
      await tester.tap(find.text('Добавить трек'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pick-${sampleAsset().id}')));
      await tester.pumpAndSettle();
      expect(c.draft.plan.steps, hasLength(1));
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      expect(find.text('00:00'), findsOneWidget);
      expect(repository.savedRuns, isEmpty);
    },
  );
  workspaceTest(
    'pause editor keeps manual changes local until Apply and protects original template',
    (tester) async {
      await c.addAudio(sampleAsset());
      final template = await c.saveAsTemplate('Источник', 'Описание');
      await c.loadTemplate(template);
      final id = c.draft.plan.steps.single.id;
      await open(tester, StructureScreen(controller: c, player: player));
      await tester.tap(find.byKey(Key('pause-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(PauseEditor), findsOneWidget);
      expect(find.text('00:00'), findsWidgets);
      await manual(tester, '6', '30');
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
      await Scrollable.ensureVisible(
        tester.element(find.text('Применить')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(c.draft.plan.steps.single.delayBeforeSeconds, 390);
      expect(c.draft.modified, isTrue);
      expect(
        repository
            .savedTemplates[template.id]!
            .plan
            .steps
            .single
            .delayBeforeSeconds,
        0,
      );
      expect(c.draft.plan.totalMs, 455000);
      expect(repository.savedRuns, isEmpty);
    },
  );
  workspaceTest('closing clock editor discards only pending pause edit', (
    tester,
  ) async {
    await c.addAudio(sampleAsset());
    final id = c.draft.plan.steps.single.id;
    await open(tester, StructureScreen(controller: c, player: player));
    await tester.tap(find.byKey(Key('pause-$id')));
    await tester.pumpAndSettle();
    await manual(tester, '2', '25');
    await tester.tap(find.byTooltip('Закрыть редактор паузы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не сохранять'));
    await tester.pumpAndSettle();
    expect(c.draft.plan.steps.single.delayBeforeSeconds, 0);
    expect(find.byType(PauseEditor), findsNothing);
  });
  workspaceTest(
    'wheel emits one haptic click for each accepted detent and none at minute boundary',
    (tester) async {
      final clicks = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') clicks.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var count = 0;
      await open(
        tester,
        Center(
          child: SizedBox(
            width: 110,
            height: 160,
            child: MechanicalWheel(
              label: 'Тест',
              value: '0',
              onDetent: (delta) {
                count++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const Key('wheel-Тест')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      expect(count, 0);
      expect(clicks, isEmpty);
      await tester.drag(
        find.byKey(const Key('wheel-Тест')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(count, greaterThan(1));
      expect(clicks, hasLength(count));
      expect(
        clicks.every(
          (call) => call.arguments == 'HapticFeedbackType.selectionClick',
        ),
        isTrue,
      );
    },
  );
  workspaceTest(
    '25 blocks scroll, groups collapse, and menu reorder keeps attached delay',
    (tester) async {
      for (var i = 0; i < 25; i++) {
        final a = sampleAsset(id: 's$i', title: 'Дорожка ${i + 1}');
        await audio.save(a);
        await c.addAudio(a);
      }
      await c.reload();
      final first = c.draft.plan.steps.first.id;
      await c.setDelay(first, 30);
      await open(tester, StructureScreen(controller: c, player: player));
      await tester.tap(find.byTooltip('Действия блока 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ниже'));
      await tester.pumpAndSettle();
      expect(c.draft.plan.steps[1].id, first);
      expect(c.draft.plan.steps[1].delayBeforeSeconds, 30);
      await tester.scrollUntilVisible(
        find.byTooltip('Действия блока 25'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(ReorderableListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Дорожка 25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  workspaceTest('switching modified draft can cancel without losing changes', (
    tester,
  ) async {
    await c.addAudio(sampleAsset());
    final template = await c.saveAsTemplate('Источник', '');
    await c.setDelay(c.draft.plan.steps.single.id, 30);
    await open(
      tester,
      TemplatesScreen(controller: c, player: player, selecting: true),
    );
    await tester.tap(find.byKey(ValueKey('template-${template.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(c.draft.plan.steps.single.delayBeforeSeconds, 30);
    expect(
      repository
          .savedTemplates[template.id]!
          .plan
          .steps
          .single
          .delayBeforeSeconds,
      0,
    );
  });
  workspaceTest(
    'home and structure adapt to a narrow short screen with large text',
    (tester) async {
      await c.addAudio(sampleAsset());
      await open(tester, StructureScreen(controller: c, player: player));
      tester.view.physicalSize = const Size(320, 600);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        SulfiApp(library: library, player: player, controller: c),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Библиотека').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  workspaceTest('optional workspace visual artifacts', (tester) async {
    const output = String.fromEnvironment('SULFI_SCREENSHOT_DIR');
    if (output.isEmpty) return;
    const font = String.fromEnvironment('SULFI_TEST_FONT');
    if (font.isNotEmpty) {
      final bytes = await tester.runAsync(() => File(font).readAsBytes());
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes!)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    Future<void> capture(String name) async {
      final context = tester.element(find.byType(Scaffold).last);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/art/sulfi_header.png'),
          context,
        );
        if (context.mounted) {
          await precacheImage(
            const AssetImage('assets/art/pocket_watch.png'),
            context,
          );
        }
        if (context.mounted) {
          await precacheImage(
            const AssetImage('assets/art/leather_board.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await open(tester, StructureScreen(controller: c, player: player));
    await capture('sections-empty');
    final labels = [
      'Подготовка к сессии',
      'Погружение',
      'Углубление',
      'Самостоятельная работа',
      'Интеграция',
      'Выход',
    ];
    for (var i = 0; i < labels.length; i++) {
      final a = sampleAsset(id: 'visual$i', title: labels[i]).edited(
        labels[i],
        AudioCategory.values[i],
        description: 'Описание аудиотрека для предварительного прослушивания.',
      );
      await audio.save(a);
      await c.addAudio(a);
    }
    await c.reload();
    final template = await c.saveAsTemplate(
      'Моя последовательность',
      'Подготовка, погружение, самостоятельная работа и выход.',
    );
    await c.loadTemplate(template);
    await c.setText(
      topic: 'Личные границы',
      notes: 'Время для спокойной работы с собой.',
    );
    await open(
      tester,
      SulfiApp(library: library, player: player, controller: c),
    );
    await capture('home-v2');
    tester.view.physicalSize = const Size(360, 720);
    await tester.pumpAndSettle();
    await capture('home-small');
    tester.view.physicalSize = const Size(432, 960);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Структура сессии'));
    await tester.pumpAndSettle();
    await capture('structure-v2');
    await tester.tap(find.byKey(Key('pause-${c.draft.plan.steps[1].id}')));
    await tester.pumpAndSettle();
    await manual(tester, '6', '30');
    await capture('pause-v2');
    tester.view.physicalSize = const Size(360, 720);
    await tester.pumpAndSettle();
    await capture('pause-small');
    tester.view.physicalSize = const Size(320, 600);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    await capture('pause-large-text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
