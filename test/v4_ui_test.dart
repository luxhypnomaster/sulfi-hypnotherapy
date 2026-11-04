import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/recorder_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_screen.dart';

import 'support/fakes.dart';
import 'support/capture_fake.dart';

void main() {
  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'V4 editor shows ten types and explicitly creates repeat phase instances',
    (t) async {
      final a = MemoryRepository(), repo = MemorySessionRepository();
      final c = SessionController(repository: repo, library: MemoryLibrary(a));
      await c.initialize();
      await open(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
      );
      for (final p in phaseTypes) {
        await t.scrollUntilVisible(
          find.text(p.title),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(p.title), findsOneWidget);
      }
      await t.tap(find.text('Добавить фазу'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Проработка'),
        ),
      );
      await t.pumpAndSettle();
      expect(c.draft.plan.phases, hasLength(1));
      await c.createPhase('work');
      await t.pumpAndSettle();
      expect(c.draft.plan.phases, hasLength(2));
      expect(c.draft.plan.phases![0].id, isNot(c.draft.plan.phases![1].id));
      expect(repo.savedRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'recorder exposes central start, disabled empty preview/save and correct bottom order',
    (t) async {
      final a = MemoryRepository();
      final c = SessionController(
        repository: MemorySessionRepository(),
        library: MemoryLibrary(a),
      );
      await c.initialize();
      await open(
        t,
        RecorderScreen(
          controller: c,
          player: MemoryPlayer(),
          backend: FakeCapture(),
        ),
      );
      expect(find.byTooltip('Начать запись'), findsOneWidget);
      expect(find.text('Параметры трека'), findsOneWidget);
      final save = find.text('Сохранить трек');
      expect(
        t.widget<FilledButton>(
          find.ancestor(of: save, matching: find.byType(FilledButton)),
        ),
        isA<FilledButton>().having((b) => b.onPressed, 'save disabled', isNull),
      );
      expect(
        t.getCenter(find.text('Отмена')).dx,
        lessThan(t.getCenter(save).dx),
      );
      expect(a.items, isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      c.dispose();
    },
  );
  testWidgets(
    'thirty tracks scroll inside main while template and CTA stay fixed',
    (t) async {
      final audio = MemoryRepository(), repo = MemorySessionRepository();
      final c = SessionController(
        repository: repo,
        library: MemoryLibrary(audio),
      );
      await c.initialize();
      final asset = sampleAsset();
      await audio.save(asset);
      await c.reload();
      final phase = await c.createPhase('induction');
      final module = ModuleDefinition(
        id: 'long',
        title: 'Длинный модуль',
        items: [
          for (var i = 1; i <= 30; i++)
            SessionStep(
              id: 'recipe$i',
              kind: StepKind.audio,
              title: 'Длинное название трека $i',
              audioAssetId: asset.id,
              durationMs: 1000,
            ),
        ],
      );
      await c.addModule(phase, module);
      await open(
        t,
        SulfiApp(library: c.library, player: MemoryPlayer(), controller: c),
      );
      final cta = find.text('НАЧАТЬ ТРАНСФОРМАЦИЮ'),
          template = find.byKey(const Key('active-template'));
      final before = t.getCenter(cta), card = t.getCenter(template);
      await t.scrollUntilVisible(
        find.text('Длинное название трека 30'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(
        find.text('Длинное название трека 30').hitTestable(),
        findsOneWidget,
      );
      expect(t.getCenter(cta), before);
      expect(t.getCenter(template), card);
      expect(repo.savedRuns, isEmpty);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('optional V4 visual artifacts', (t) async {
    const output = String.fromEnvironment('SULFI_V4_SCREENSHOTS');
    if (output.isEmpty) return;
    const font = String.fromEnvironment('SULFI_TEST_FONT');
    if (font.isNotEmpty) {
      final data = await t.runAsync(() => File(font).readAsBytes());
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(data!)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final audio = MemoryRepository(), repo = MemorySessionRepository();
    final library = MemoryLibrary(audio), player = MemoryPlayer();
    final c = SessionController(repository: repo, library: library);
    await c.initialize();
    final assets = [
      for (var i = 0; i < 3; i++)
        sampleAsset(id: 'ui$i', title: 'Тестовый трек ${i + 1}'),
    ];
    for (final a in assets) {
      await audio.save(a);
    }
    await c.reload();
    final prep = await c.createPhase('preparation');
    await c.addLoose(
      prep,
      SessionStep(
        id: 'loose',
        kind: StepKind.audio,
        title: assets.first.title,
        audioAssetId: assets.first.id,
        durationMs: 65000,
      ),
    );
    final phase = await c.createPhase('induction');
    final m = ModuleDefinition(
      id: 'ui-module',
      title: 'Личный модуль',
      items: [
        for (final a in assets)
          SessionStep(
            id: a.id,
            kind: StepKind.audio,
            title: a.title,
            audioAssetId: a.id,
            durationMs: 65000,
          ),
      ],
    );
    await c.modules.save(m);
    await c.addModule(phase, m);
    await c.addModule(phase, m);
    final template = await c.saveAsTemplate(
      'Мой шаблон',
      'Тестовые данные рендера',
    );
    await c.loadTemplate(template);
    await c.setText(topic: 'Тестовая тема');
    Future<void> capture(String name, Widget page) async {
      await open(t, page);
      final ctx = t.element(find.byType(Scaffold).last);
      await t.runAsync(() async {
        for (final file in [
          'assets/art/sulfi_header.png',
          'assets/art/leather_board.png',
          'assets/brand/spiral.png',
        ]) {
          if (ctx.mounted) await precacheImage(AssetImage(file), ctx);
        }
      });
      await t.pumpAndSettle();
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await t.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        img.dispose();
      });
    }

    await capture(
      'main',
      SulfiApp(library: library, player: player, controller: c),
    );
    await capture(
      'structure',
      ModularStructureScreen(controller: c, player: player),
    );
    await capture(
      'recorder',
      RecorderScreen(controller: c, player: player, backend: FakeCapture()),
    );
    repo.savedRuns['render'] = SessionRun(
      id: 'render',
      displayNumber: 1,
      name: 'Тест',
      snapshot: CurrentSessionDraft.fromMap(c.draft.toMap()),
      startedAt: DateTime.utc(2026, 11, 3, 9),
      startedUtcOffsetMinutes: 180,
      status: RunStatus.interrupted,
      elapsedMs: 75000,
    );
    await c.reload();
    await capture('history', HistoryScreen(controller: c));
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    c.dispose();
  });
}
