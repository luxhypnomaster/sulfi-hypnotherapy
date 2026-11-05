import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/plan_duration.dart';
import 'package:sulfi_hypnotherapy/models/structure_rows.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_engine.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/module_editor.dart';
import 'package:sulfi_hypnotherapy/ui/structure_item_row.dart';
import 'package:sulfi_hypnotherapy/ui/structure_shell.dart';
import 'package:sulfi_hypnotherapy/ui/pause_clock_art.dart';
import 'package:sulfi_hypnotherapy/ui/templates_screen.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';

import 'support/fakes.dart';
import 'support/session_transport_fake.dart';

SessionStep track(String id, String asset, int ms, {int delay = 0}) =>
    SessionStep(
      id: id,
      kind: StepKind.audio,
      title: switch (asset) {
        'a' => 'Внешний фокус',
        'b' => 'Углубление',
        'exit' => 'Возвращение',
        _ => 'Подготовка',
      },
      audioAssetId: asset,
      durationMs: ms,
      delayBeforeSeconds: delay,
    );
SessionStep interval(String id, int? ms) =>
    SessionStep(id: id, kind: StepKind.silence, title: 'Пауза', durationMs: ms);
ModuleDefinition definition() => ModuleDefinition(
  id: 'elman',
  title: 'Индукция Элмана',
  items: [
    track('focus', 'a', 114000),
    interval('pause', 30000),
    track('deep', 'b', 153000),
  ],
);
PhaseChild module(String id, ModuleDefinition d, String phase) {
  final c = PhaseChild(
    id: id,
    title: d.title,
    definitionId: d.id,
    definitionVersion: d.version,
    items: d.items.map((s) => s.copyWith(groupId: phase)).toList(),
  );
  return PhaseChild(
    id: id,
    title: d.title,
    definitionId: d.id,
    definitionVersion: d.version,
    baseFingerprint: c.fingerprint,
    items: c.items,
  );
}

SessionPlan fixture() => SessionPlan(
  steps: const [],
  phases: [
    PhaseInstance(
      id: 'prep',
      typeId: 'preparation',
      title: 'Подготовка',
      children: [
        module(
          'prep-module',
          ModuleDefinition(
            id: 'prep-def',
            title: 'Подготовка',
            items: [track('preparation-track', 'prep', 132000)],
          ),
          'prep',
        ),
      ],
    ),
    PhaseInstance(
      id: 'induction',
      typeId: 'induction',
      title: 'Индукция',
      children: [module('induction-module', definition(), 'induction')],
    ),
    PhaseInstance(
      id: 'exit',
      typeId: 'exit',
      title: 'Выход',
      children: [
        module(
          'exit-module',
          ModuleDefinition(
            id: 'ending',
            title: 'Завершение',
            items: [track('exit-track', 'exit', 66000)],
          ),
          'exit',
        ),
      ],
    ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late Database db;
  late SessionController c;
  late LibraryService library;
  late SqliteSessionRepository sessions;
  late SqliteLibraryRepository audio;
  setUpAll(() async {
    final sdk = File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent;
    for (final spec in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/${spec.$2}',
      ).readAsBytes();
      await (FontLoader(
        spec.$1,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await ApprovedPauseClock.load();
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sulfi_structure_mvp');
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    audio = SqliteLibraryRepository(db);
    sessions = SqliteSessionRepository(db);
    library = LibraryService(
      repository: audio,
      directory: Directory('${dir.path}/audio'),
      pick: () async => null,
      probe: (_) async => null,
    );
    await library.initialize();
    for (final spec in [
      ('prep', 132000),
      ('a', 114000),
      ('b', 153000),
      ('exit', 66000),
    ]) {
      await File('${library.directory.path}/${spec.$1}.wav')
          .writeAsBytes([82, 73, 70, 70]);
      await audio.save(
        AudioAsset(
          id: spec.$1,
          title: spec.$1,
          filePath: '${spec.$1}.wav',
          durationMs: spec.$2,
          format: 'wav',
          createdAt: DateTime.utc(2026, 11, 5),
          category: AudioCategory.induction,
          fileSizeBytes: 4,
        ),
      );
    }
    await sessions.saveDraft(
      CurrentSessionDraft(
        plan: fixture(),
        updatedAt: DateTime.utc(2026, 11, 5),
        topicText: 'Тестовая тема',
        notes: 'Личная заметка',
      ),
    );
    c = SessionController(
      repository: sessions,
      library: library,
      modules: ModuleCatalog(db),
    );
    await c.initialize();
    await c.modules.save(definition());
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  test('reference sums are 2:12, 4:57, 1:06 and 8:15; disabled and empty phases use execution rules', () {
    final plan = fixture();
    expect(plan.phases!.map((p) => PlanDuration.phase(p).label), [
      '2:12',
      '4:57',
      '1:06',
    ]);
    expect(PlanDuration.plan(plan).label, '8:15');
    expect(
      structureSummary(plan),
      '3 фазы • 3 модуля • 4 трека • 1 пауза • 8:15',
    );
    expect(
      PlanDuration.phase(
        PhaseInstance(id: 'empty', typeId: 'work', title: 'Пустая'),
      ).label,
      '0:00',
    );
    expect(
      PlanDuration.phase(plan.phases![1].copyWith(enabled: false)).knownMs,
      0,
    );
    expect(
      PlanDuration.plan(
        plan.copyWith(
          phases: [
            plan.phases![0],
            plan.phases![1].copyWith(enabled: false),
            plan.phases![2],
          ],
        ),
      ).knownMs,
      198000,
    );
  });
  test('milliseconds accumulate before formatting, delays counted once, legacy unknown keeps minimum', () {
    final items = [
      track('a', 'a', 500, delay: 1),
      interval('zero', 0),
      track('b', 'b', 500),
      interval('old', null),
    ];
    final summary = PlanDuration.steps(items);
    expect(summary.knownMs, 2000);
    expect(summary.label, '≥0:02');
    expect(summary.semantics, contains('неизвестна'));
  });
  test('isolated edit changes sums before Apply; source/cache/templates unchanged until one explicit commit', () async {
    final baseline = jsonEncode((await sessions.loadDraft())!.toMap());
    final template = await c.saveAsTemplate('Исходный', '');
    final editor = await c.beginEditing();
    await editor.updateStep(
      editor.draft.plan.allSteps
          .firstWhere((s) => s.id == 'pause')
          .copyWith(durationMs: 45000),
    );
    expect(editor.hasEditorChanges, true);
    expect(PlanDuration.phase(editor.draft.plan.phases![1]).label, '5:12');
    expect(PlanDuration.plan(editor.draft.plan).label, '8:30');
    expect(jsonEncode((await sessions.loadDraft())!.toMap()), baseline);
    expect(PlanDuration.plan(c.draft.plan).label, '8:15');
    await editor.applyEditor();
    expect(PlanDuration.plan(c.draft.plan).label, '8:30');
    expect(
      (await sessions.templates()).single.plan.fingerprint,
      template.plan.fingerprint,
    );
    expect(editor.hasEditorChanges, false);
    expect(await sessions.history(), isEmpty);
    editor.dispose();
  });
  test('discard and cancel child reload do not save current plan; stage reload refreshes metadata only', () async {
    final before = (await sessions.loadDraft())!.plan.fingerprint;
    final editor = await c.beginEditing();
    await editor.createPhase('work');
    await editor.reload();
    expect(editor.draft.plan.phases, hasLength(4));
    expect(c.draft.plan.phases, hasLength(3));
    editor.dispose();
    expect((await sessions.loadDraft())!.plan.fingerprint, before);
  });
  test('active frozen run is not interrupted by opening or reinitializing an editor', () async {
    final run = await sessions.startRun(c.draft);
    final snapshot = run.snapshot.plan.fingerprint;
    final editor = await c.beginEditing();
    await editor.initialize();
    await editor.createPhase('work');
    final saved = (await sessions.history()).single;
    expect(saved.status, RunStatus.running);
    expect(saved.snapshot.plan.fingerprint, snapshot);
    editor.dispose();
  });
  test('parent change causes a visible conflict; newer topic and pending edit survive', () async {
    final editor = await c.beginEditing();
    await editor.createPhase('work');
    await c.setText(topic: 'Более новая тема');
    await expectLater(editor.applyEditor(), throwsA(isA<LibraryException>()));
    expect(c.draft.topicText, 'Более новая тема');
    expect(c.draft.plan.phases, hasLength(3));
    expect(editor.draft.plan.phases, hasLength(4));
    editor.dispose();
  });
  test('real SQLite write refusal retains previous plan and pending edit; retry succeeds', () async {
    final editor = await c.beginEditing();
    await editor.createPhase('work');
    await db.execute('PRAGMA query_only=ON');
    await expectLater(editor.applyEditor(), throwsA(anything));
    expect(c.draft.plan.phases, hasLength(3));
    expect((await sessions.loadDraft())!.plan.phases, hasLength(3));
    expect(editor.hasEditorChanges, true);
    await db.execute('PRAGMA query_only=OFF');
    await editor.applyEditor();
    expect(c.draft.plan.phases, hasLength(4));
    editor.dispose();
  });
  test('two copies of a module stay independent; updating definition affects future inserts only', () async {
    final editor = await c.beginEditing();
    await editor.addModule('induction', definition());
    var phase = editor.draft.plan.phases![1];
    final old = phase.children.first, copy = phase.children.last;
    expect(old.id, isNot(copy.id));
    expect(
      old.items
          .map((s) => s.id)
          .toSet()
          .intersection(copy.items.map((s) => s.id).toSet()),
      isEmpty,
    );
    await editor.updateChild(
      phase.id,
      copy.copyWith(
        description: 'Описание только этого экземпляра',
        items: [...copy.items, interval('extra', 1000)],
      ),
    );
    expect(editor.draft.plan.phases![1].children.first.items, hasLength(3));
    expect(editor.draft.plan.phases![1].children.last.items, hasLength(4));
    expect(editor.draft.plan.phases![1].children.first.description, isEmpty);
    await c.modules.save(
      ModuleDefinition(
        id: 'elman',
        title: 'Новая версия',
        description: 'Описание будущих экземпляров',
        version: 2,
        items: [interval('future', 7000)],
      ),
    );
    await editor.addModule('induction', c.modules.entries.single);
    expect(editor.draft.plan.phases![1].children.first.items, hasLength(3));
    expect(
      editor.draft.plan.phases![1].children.last.items.single.durationMs,
      7000,
    );
    expect(
      editor.draft.plan.phases![1].children.last.description,
      'Описание будущих экземпляров',
    );
    await editor.applyEditor();
    editor.dispose();
    await db.close();
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    sessions = SqliteSessionRepository(db);
    final restored = (await sessions.loadDraft())!;
    expect(restored.plan.phases![1].children.map((m) => m.items.length), [
      3,
      4,
      1,
    ]);
    expect(
      restored.plan.phases![1].children[1].description,
      'Описание только этого экземпляра',
    );
  });
  test('metadata refresh updates stage duration without rewriting template or frozen history', () async {
    final template = await c.saveAsTemplate('Снимок', '');
    final run = await sessions.startRun(c.draft);
    final editor = await c.beginEditing();
    final asset = c.asset('a')!;
    await audio.save(
      AudioAsset.fromMap(asset.toMap()..['durationMs'] = 120000),
    );
    await editor.reload();
    expect(PlanDuration.plan(editor.draft.plan).label, '8:21');
    expect(PlanDuration.plan(c.draft.plan).label, '8:15');
    expect(
      (await sessions.templates()).single.plan.fingerprint,
      template.plan.fingerprint,
    );
    expect(
      (await sessions.history()).single.snapshot.plan.fingerprint,
      run.snapshot.plan.fingerprint,
    );
    editor.dispose();
  });
  test('reorder every level to start/middle/end preserves IDs, sum and pre-delays, never reparents', () {
    final p = fixture();
    var phases = p.phases!, rows = structureRows(phases, {});
    final before = p.totalMs, ids = p.allSteps.map((s) => s.id).toSet();
    var from = rows.indexWhere((r) => r.id == 'focus'),
        to = rows.indexWhere((r) => r.id == 'deep');
    phases = reorderStructure(phases, rows, from, to);
    expect(phases[1].children.single.items.map((s) => s.id), [
      'pause',
      'deep',
      'focus',
    ]);
    rows = structureRows(phases, {});
    from = rows.indexWhere((r) => r.id == 'focus');
    to = rows.indexWhere((r) => r.id == 'pause');
    phases = reorderStructure(phases, rows, from, to);
    expect(phases[1].children.single.items.first.id, 'focus');
    rows = structureRows(phases, {});
    final ignored = reorderStructure(
      phases,
      rows,
      rows.indexWhere((r) => r.id == 'focus'),
      rows.indexWhere((r) => r.id == 'exit-track'),
    );
    expect(identical(ignored, phases), true);
    rows = structureRows(phases, {'prep', 'induction', 'exit'});
    phases = reorderStructure(phases, rows, 0, 2);
    expect(phases.map((p) => p.id), ['induction', 'exit', 'prep']);
    rows = structureRows(phases, {'prep', 'induction', 'exit'});
    phases = reorderStructure(phases, rows, 2, 0);
    expect(phases.map((p) => p.id), ['prep', 'induction', 'exit']);
    final result = p.copyWith(phases: phases);
    expect(result.totalMs, before);
    expect(result.allSteps.map((s) => s.id).toSet(), ids);
  });
  test('direct legacy tracks keep their depth, child IDs and exact order when reordered', () {
    final a = track('legacy-a', 'a', 1000, delay: 7),
        b = interval('legacy-pause', 0);
    final phase = PhaseInstance(
      id: 'legacy',
      typeId: 'work',
      title: 'Прежняя фаза',
      children: [
        PhaseChild(id: 'direct-a', title: a.title, items: [a]),
        PhaseChild(id: 'direct-b', title: b.title, items: [b]),
      ],
    );
    final rows = structureRows([phase], {});
    expect(rows.where((r) => r.level == StructureLevel.module), isEmpty);
    final result = reorderStructure([phase], rows, 1, 2).single;
    expect(result.children.map((c) => c.id), ['direct-b', 'direct-a']);
    expect(result.children.last.items.single.delayBeforeSeconds, 7);
  });
  test('applied/reopened snapshot executes in the exact edited order without automatic Start', () async {
    final editor = await c.beginEditing();
    var p = editor.draft.plan.phases![1];
    await editor.updateChild(
      p.id,
      p.children.single.copyWith(
        items: p.children.single.items.reversed.toList(),
      ),
    );
    await editor.applyEditor();
    expect(await sessions.history(), isEmpty);
    final reopened = SessionController(
      repository: sessions,
      library: library,
      modules: ModuleCatalog(db),
    );
    await reopened.initialize();
    expect(reopened.draft.plan.steps.map((s) => s.id), [
      'preparation-track',
      'deep',
      'pause',
      'focus',
      'exit-track',
    ]);
    final transport = TestTransport(),
        engine = SessionEngine(controller: reopened, transport: transport);
    await engine.start();
    expect(
      engine.run!.snapshot.plan.steps.map((s) => s.id),
      reopened.draft.plan.steps.map((s) => s.id),
    );
    await engine.close();
    reopened.dispose();
    editor.dispose();
  });
  Future<void> settleIo(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
      await t.pump();
    }
  }

  Future<void> show(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(360, 640),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      RepaintBoundary(
        key: const Key('mvp-render'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await settleIo(t);
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    const output = String.fromEnvironment('SULFI_MVP_ARTIFACTS');
    if (output.isEmpty) return;
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('mvp-render')),
          )
          .toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$output/$name.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> footerApply(WidgetTester t) async {
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('structure-footer')),
        matching: find.text('Применить'),
      ),
    );
    await settleIo(t);
    await t.pumpAndSettle();
  }

  testWidgets(
    'four footer controls, exact sums on expanded/collapsed phases, 45 seconds updates pending only',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
        size: const Size(412, 915),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('structure-footer')),
          matching: find.byType(StructureFooterButton),
        ),
        findsNWidgets(4),
      );
      await t.tap(find.byKey(const ValueKey('expand-prep')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('duration-prep'))).data,
        '2:12',
      );
      await t.ensureVisible(find.byKey(const ValueKey('expand-exit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('expand-exit')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('duration-induction'))).data,
        '4:57',
      );
      await t.tap(find.byKey(const ValueKey('menu-pause')));
      await t.pumpAndSettle();
      await t.tap(find.text('Изменить длительность'));
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const Key('wheel-Секунды')),
        const Offset(0, -210),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Применить'));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('duration-induction'))).data,
        '5:12',
      );
      expect(find.textContaining('8:30'), findsOneWidget);
      expect(
        c.draft.plan.allSteps.firstWhere((s) => s.id == 'pause').durationMs,
        30000,
      );
      await capture(t, 'structure-updated');
      await footerApply(t);
      expect(
        c.draft.plan.allSteps.firstWhere((s) => s.id == 'pause').durationMs,
        45000,
      );
      expect(await t.runAsync(sessions.history), isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'system Back offers Apply, discard or stay; discard keeps source and media',
    (t) async {
      await show(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ModularStructureScreen(
                    controller: c,
                    player: MemoryPlayer(),
                  ),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Открыть'));
      await settleIo(t);
      await t.pumpAndSettle();
      await t.tap(find.text('Добавить\nфазу'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Подготовка'),
        ),
      );
      await t.pumpAndSettle();
      expect(c.draft.plan.phases, hasLength(3));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Остаться'), findsOneWidget);
      await t.tap(find.text('Остаться'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('structure-footer')), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.tap(find.text('Отбросить'));
      await t.pumpAndSettle();
      expect(find.text('Открыть'), findsOneWidget);
      expect(c.draft.plan.phases, hasLength(3));
      expect(
        await t.runAsync(() => library.fileFor(c.asset('a')!).exists()),
        true,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'module definition cancel preserves catalogue; Apply changes only future instances',
    (t) async {
      await show(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ModuleEditor(
                    controller: c,
                    player: MemoryPlayer(),
                    module: definition(),
                  ),
                ),
              ),
              child: const Text('Модуль'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Модуль'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Действия элемента').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Повторить элемент'));
      await t.pumpAndSettle();
      expect(c.modules.entries.single.items, hasLength(3));
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      await t.tap(find.text('Отбросить'));
      await t.pumpAndSettle();
      expect(c.modules.entries.single.items, hasLength(3));
      await t.tap(find.text('Модуль'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Действия элемента').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Повторить элемент'));
      await t.pumpAndSettle();
      await capture(t, 'module-editor');
      await t.tap(find.text('Применить'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(c.modules.entries.single.items, hasLength(4));
      expect(c.modules.entries.single.version, 2);
      expect(c.draft.plan.phases![1].children.single.items, hasLength(3));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('real item drag changes order only after Apply', (t) async {
    await show(
      t,
      ModularStructureScreen(controller: c, player: MemoryPlayer()),
      size: const Size(412, 915),
    );
    await t.tap(find.byKey(const ValueKey('expand-prep')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('expand-exit')));
    await t.pumpAndSettle();
    final start = t.getCenter(find.byKey(const ValueKey('drag-focus'))),
        end =
            t.getCenter(find.byKey(const ValueKey('drag-deep'))) +
            const Offset(0, 20);
    final gesture = await t.startGesture(start);
    await gesture.moveBy(const Offset(0, 24));
    await t.pump(const Duration(milliseconds: 60));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(
        Offset.lerp(start + const Offset(0, 24), end, i / 10)!,
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await t.pumpAndSettle();
    expect(c.draft.plan.phases![1].children.single.items.first.id, 'focus');
    await footerApply(t);
    expect(c.draft.plan.phases![1].children.single.items.map((s) => s.id), [
      'pause',
      'deep',
      'focus',
    ]);
    expect(PlanDuration.plan(c.draft.plan).label, '8:15');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'module instance Apply changes only selected copy, definition and root remain separate',
    (t) async {
      final editor = (await t.runAsync(c.beginEditing))!;
      await t.runAsync(() => editor.addModule('induction', definition()));
      final phase = editor.draft.plan.phases![1],
          instance = phase.children.first;
      await show(
        t,
        ModuleEditor(
          controller: editor,
          player: MemoryPlayer(),
          instance: instance,
          phaseId: phase.id,
        ),
      );
      await t.tap(find.byTooltip('Действия элемента').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Повторить элемент'));
      await t.pumpAndSettle();
      expect(editor.draft.plan.phases![1].children.first.items, hasLength(3));
      await t.tap(find.text('Применить'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(editor.draft.plan.phases![1].children.map((m) => m.items.length), [
        4,
        3,
      ]);
      expect(c.draft.plan.phases![1].children, hasLength(1));
      expect(c.modules.entries.single.items, hasLength(3));
      await t.runAsync(editor.applyEditor);
      expect(c.draft.plan.phases![1].children.map((m) => m.items.length), [
        4,
        3,
      ]);
      await t.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );
  testWidgets(
    'catalogue version conflict preserves external definition and local pending module',
    (t) async {
      await show(
        t,
        ModuleEditor(
          controller: c,
          player: MemoryPlayer(),
          module: definition(),
        ),
      );
      await t.tap(find.byTooltip('Действия элемента').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Повторить элемент'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => c.modules.save(
          ModuleDefinition(
            id: 'elman',
            title: 'Изменено извне',
            version: 2,
            items: [interval('external', 7000)],
          ),
        ),
      );
      await t.tap(find.text('Применить'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(find.textContaining('Определение изменилось'), findsOneWidget);
      expect(c.modules.entries.single.items.single.id, 'external');
      expect(
        t.widgetList<StructureItemRow>(find.byType(StructureItemRow)),
        hasLength(4),
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'audio picker keeps exact module parent and repeated selection across return/Apply',
    (t) async {
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
        size: const Size(412, 915),
      );
      await t.tap(find.byKey(const ValueKey('expand-prep')));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('add-induction-module')),
          matching: find.text('Добавить'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Трек из библиотеки'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pick-a')));
      await settleIo(t);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pick-a')));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(c.draft.plan.phases![1].children.single.items, hasLength(3));
      await t.binding.handlePopRoute();
      await settleIo(t);
      await t.pumpAndSettle();
      await footerApply(t);
      final inserted = c.draft.plan.phases![1].children.single.items;
      expect(inserted, hasLength(5));
      expect(inserted.map((s) => s.id).toSet(), hasLength(5));
      expect(inserted.skip(3).map((s) => s.audioAssetId), ['a', 'a']);
      expect(inserted.skip(3).map((s) => s.delayBeforeSeconds), [0, 0]);
      expect(c.draft.plan.phases!.first.children.single.items, hasLength(1));
      expect(c.modules.entries.single.items, hasLength(3));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'template replacement warns and cancels; chosen plan remains staged until Apply',
    (t) async {
      final replacement = fixture().copyWith(phases: [fixture().phases!.last]);
      final template = await t.runAsync(
        () => c.saveAsTemplate('Другой шаблон', '', plan: replacement),
      );
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
      );
      await t.tap(find.text('Добавить\nфазу'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Подготовка'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Выбрать\nшаблон'));
      await settleIo(t);
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('template-${template!.id}')));
      await t.pumpAndSettle();
      expect(find.text('Текущая конфигурация изменена'), findsOneWidget);
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(find.byType(TemplatesScreen), findsOneWidget);
      await t.tap(find.byKey(ValueKey('template-${template.id}')));
      await t.pumpAndSettle();
      await t.tap(find.text('Переключить без сохранения'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(c.draft.plan.phases, hasLength(3));
      await footerApply(t);
      expect(c.draft.plan.phases, hasLength(1));
      expect(c.draft.baseTemplateId, template.id);
      expect(c.draft.topicText, 'Тестовая тема');
      expect(
        (await t.runAsync(sessions.templates))!.single.plan.fingerprint,
        replacement.fingerprint,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real drag moves whole phases and module copies, preserving descendants',
    (t) async {
      await t.runAsync(() => c.addModule('induction', definition()));
      final copy = c.draft.plan.phases![1].children.last.id;
      final originalIds = c.draft.plan.allSteps.map((s) => s.id).toSet(),
          duration = c.draft.plan.totalMs;
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
        size: const Size(412, 915),
      );
      Future<void> collapse(String id) async {
        await t.ensureVisible(find.byKey(ValueKey('expand-$id')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey('expand-$id')));
        await t.pumpAndSettle();
      }

      await collapse('prep');
      await collapse('induction-module');
      await collapse(copy);
      await collapse('exit');
      Future<void> drag(String source, String target) async {
        final a = t.getCenter(find.byKey(ValueKey('drag-$source'))),
            b =
                t.getCenter(find.byKey(ValueKey('drag-$target'))) +
                // Cross the target midpoint after the initial touch slop.
                const Offset(0, 44);
        final g = await t.startGesture(a);
        await g.moveBy(const Offset(0, 24));
        await t.pump(const Duration(milliseconds: 50));
        for (var i = 1; i <= 10; i++) {
          await g.moveTo(Offset.lerp(a + const Offset(0, 24), b, i / 10)!);
          await t.pump(const Duration(milliseconds: 45));
        }
        await t.pump(const Duration(milliseconds: 100));
        await g.up();
        await t.pumpAndSettle();
      }

      await drag('induction-module', copy);
      await footerApply(t);
      expect(c.draft.plan.phases![1].children.map((m) => m.id), [
        copy,
        'induction-module',
      ]);
      await collapse('induction');
      await drag('prep', 'exit');
      await footerApply(t);
      expect(c.draft.plan.phases!.map((p) => p.id), [
        'induction',
        'exit',
        'prep',
      ]);
      expect(c.draft.plan.allSteps.map((s) => s.id).toSet(), originalIds);
      expect(c.draft.plan.totalMs, duration);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'held drag autoscrolls a long module without escaping its parent',
    (t) async {
      final long = PhaseInstance(
        id: 'long-phase',
        typeId: 'work',
        title: 'Длинная фаза',
        children: [
          PhaseChild(
            id: 'long-module',
            title: 'Большой модуль',
            definitionId: 'long-def',
            items: [for (var i = 0; i < 25; i++) interval('long-$i', 1000)],
          ),
        ],
      );
      await t.runAsync(() => c.changePhases((_) => [long]));
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
      );
      final list = find
          .descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(Scrollable),
          )
          .first;
      final rect = t.getRect(find.byKey(const Key('structure-list')));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('drag-long-0'))),
      );
      await g.moveBy(const Offset(0, 24));
      await t.pump(const Duration(milliseconds: 100));
      await g.moveTo(Offset(rect.center.dx, rect.bottom - 8));
      for (var i = 0; i < 25; i++) {
        await t.pump(const Duration(milliseconds: 80));
      }
      expect(t.state<ScrollableState>(list).position.pixels, greaterThan(0));
      await g.up();
      await t.pumpAndSettle();
      await footerApply(t);
      final items = c.draft.plan.phases!.single.children.single.items;
      expect(items.map((s) => s.id).toSet(), hasLength(25));
      expect(items.indexWhere((s) => s.id == 'long-0'), greaterThan(0));
      expect(c.draft.plan.totalMs, 25000);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'safe 360dp and 200 percent fonts keep all four actions and final add reachable',
    (t) async {
      for (final size in [
        const Size(360, 640),
        const Size(360, 780),
        const Size(320, 600),
      ]) {
        await show(
          t,
          ModularStructureScreen(
            key: UniqueKey(),
            controller: c,
            player: MemoryPlayer(),
          ),
          size: size,
          scale: 2,
        );
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('structure-footer')), findsOneWidget);
        for (final label in [
          'Добавить\nфазу',
          'Выбрать\nшаблон',
          'Сохранить\nшаблон',
          'Применить',
        ]) {
          expect(find.text(label).hitTestable(), findsOneWidget);
        }
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('add-exit')),
          300,
          scrollable: find
              .descendant(
                of: find.byType(ReorderableListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(const ValueKey('add-exit')).hitTestable(),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'working structure screenshots use the reference data, not a baked mockup',
    (t) async {
      await show(
        t,
        ModularStructureScreen(controller: c, player: MemoryPlayer()),
      );
      await t.tap(find.byKey(const ValueKey('expand-prep')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('expand-exit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('expand-exit')));
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const Key('structure-list')),
        const Offset(0, 900),
      );
      await t.pumpAndSettle();
      await capture(t, 'structure');
      await t.tap(find.byKey(const ValueKey('expand-induction')));
      await t.pumpAndSettle();
      await capture(t, 'structure-collapsed');
      await t.pumpWidget(const SizedBox());
      await show(
        t,
        ModuleEditor(
          controller: c,
          player: MemoryPlayer(),
          module: definition(),
        ),
      );
      await capture(t, 'module');
      await t.pumpWidget(const SizedBox());
      final player = MemoryPlayer();
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('mvp-render'),
          child: SulfiApp(library: library, player: player, controller: c),
        ),
      );
      await t.pumpAndSettle();
      await settleIo(t);
      await capture(t, 'home');
      await t.pumpWidget(const SizedBox());
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
}
