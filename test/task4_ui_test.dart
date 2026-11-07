import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_editor.dart';
import 'package:sulfi_hypnotherapy/ui/home_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_screen.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/module_editor.dart';
import 'package:sulfi_hypnotherapy/ui/preview_bar.dart';
import 'package:sulfi_hypnotherapy/ui/recorder_screen.dart';
import 'package:sulfi_hypnotherapy/ui/recorder_microphone.dart';

import 'support/fakes.dart';
import 'support/capture_fake.dart';

class SeekPreview extends MemoryPlayer {
  Duration cursor = Duration.zero;
  @override
  Duration get position => cursor;
  @override
  Future<void> seek(Duration p) async {
    cursor = p;
    notifyListeners();
  }
}

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SessionController c;
  late SeekPreview player;
  late ModuleDefinition module;
  var fontsReady = false;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task4-ui');
    final audio = MemoryRepository();
    final library = LibraryService(
      repository: audio,
      directory: Directory('${root.path}/audio'),
      pick: () async => null,
      probe: (_) async => const Duration(seconds: 4),
    );
    await library.initialize();
    for (var i = 1; i <= 2; i++) {
      final a = AudioAsset.fromMap({
        ...sampleAsset(id: 'audio$i', title: 'Тестовый трек $i').toMap(),
        'filePath': 'test$i.wav',
      });
      await audio.save(a);
      await library.fileFor(a).writeAsBytes([1, 2, 3, i]);
    }
    c = SessionController(
      repository: MemorySessionRepository(),
      library: library,
    );
    await c.initialize();
    module = ModuleDefinition(
      id: 'm',
      title: 'Тестовый модуль',
      items: [
        for (final a in c.assets)
          SessionStep(
            id: 'step-${a.id}',
            kind: StepKind.audio,
            title: a.title,
            audioAssetId: a.id,
            durationMs: a.durationMs,
          ),
      ],
    );
    await c.modules.save(module);
    final phase = await c.createPhase('induction');
    await c.addModule(phase, module);
    player = SeekPreview();
  });
  tearDown(() async {
    c.dispose();
    await root.delete(recursive: true);
  });
  Future<void> io(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  Future<void> show(
    WidgetTester t,
    Widget page, {
    Size size = const Size(412, 915),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    if (!fontsReady) {
      final sdk = File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent;
      for (final font in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        final data = (await t.runAsync(
          () =>
              File('${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
                  .readAsBytes(),
        ))!;
        await (FontLoader(
          font.$1,
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      }
      fontsReady = true;
    }
    await t.pumpWidget(
      MaterialApp(
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
        home: RepaintBoundary(key: const Key('task4-capture'), child: page),
      ),
    );
    await io(t);
  }

  Future<void> capture(WidgetTester t, String name) async {
    const dir = String.fromEnvironment('SULFI_TASK4_SCREENSHOTS');
    if (dir.isEmpty) return;
    await t.pump();
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('task4-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final screen in ['home', 'structure', 'module', 'library']) {
    testWidgets(
      'one shared preview on $screen: two files, pause, seek, close and row state',
      (t) async {
        final page = switch (screen) {
          'home' => HomeScreen(controller: c, player: player),
          'structure' => ModularStructureScreen(controller: c, player: player),
          'module' => ModuleEditor(
            controller: c,
            player: player,
            module: module,
          ),
          _ => LibraryScreen(library: c.library, controller: c, player: player),
        };
        await show(t, page);
        final first = screen == 'module' || screen == 'structure'
            ? find.byTooltip('Прослушать трек').first
            : find.byTooltip('Прослушать Тестовый трек 1').first;
        await t.ensureVisible(first);
        await t.tap(first);
        await io(t);
        expect(player.current?.id, 'audio1');
        expect(player.playing, isTrue);
        expect(find.byType(PreviewBar), findsOneWidget);
        final bar = find.byType(PreviewBar);
        final barPause = find.descendant(
          of: bar,
          matching: find.byTooltip('Пауза'),
        );
        await t.tap(barPause);
        await io(t);
        expect(player.playing, isFalse);
        final slider = find.descendant(of: bar, matching: find.byType(Slider));
        await t.drag(slider, const Offset(40, 0));
        await io(t);
        expect(player.position.inMilliseconds, greaterThan(0));
        await t.tap(
          find.descendant(of: bar, matching: find.byTooltip('Продолжить')),
        );
        await io(t);
        final second = screen == 'module' || screen == 'structure'
            ? find.byTooltip('Прослушать трек').first
            : find.byTooltip('Прослушать Тестовый трек 2').first;
        await t.ensureVisible(second);
        await t.tap(second);
        await io(t);
        expect(player.current?.id, 'audio2');
        await capture(t, 'preview-$screen');
        await t.tap(
          find.descendant(
            of: bar,
            matching: find.byTooltip('Остановить прослушивание'),
          ),
        );
        await io(t);
        expect(player.current, isNull);
        expect(
          find.descendant(of: bar, matching: find.byType(Slider)),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await io(t);
      },
    );
  }
  testWidgets(
    'existing definition Save as new creates a full independent definition and preserves original',
    (t) async {
      await show(
        t,
        ModuleEditor(controller: c, player: player, module: module),
      );
      await t.enterText(find.byKey(const Key('module-name')), 'Мой вариант');
      t.testTextInput.hide();
      await t.tap(find.text('Сохранить\nкак новый'));
      await io(t);
      expect(c.modules.entries, hasLength(2));
      expect(
        c.modules.entries.firstWhere((m) => m.id == 'm').title,
        module.title,
      );
      final copy = c.modules.entries.firstWhere((m) => m.id != 'm');
      expect(copy.title, 'Мой вариант');
      expect(copy.items, hasLength(2));
      expect(c.draft.plan.phases!.single.children.single.title, module.title);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'approved recorder fields and icon controls stay visible; real capture service reaches finished state',
    (t) async {
      final backend = FakeCapture();
      final awake = <bool>[];
      const channel = MethodChannel('ru.sulfi/device_files');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'keepAwake') awake.add(call.arguments as bool);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await show(
        t,
        RecorderScreen(controller: c, player: player, backend: backend),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Теги'), findsOneWidget);
      expect(find.text('Добавить в модуль'), findsOneWidget);
      expect(find.byType(RecorderMicrophone), findsOneWidget);
      for (final label in ['Удалить', 'Воспроизвести', 'Пауза', 'Завершить']) {
        expect(find.byTooltip(label).hitTestable(), findsOneWidget);
        expect(find.text(label), findsNothing);
      }
      await capture(t, 'recorder-ready');
      t.view.physicalSize = const Size(412, 732);
      await t.pumpAndSettle();
      expect(find.byTooltip('Завершить').hitTestable(), findsOneWidget);
      await capture(t, 'recorder-9x16');
      t.view.physicalSize = const Size(412, 915);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Начать запись'));
      await io(t);
      expect(backend.starts, 1);
      expect(awake.last, isTrue);
      await t.tap(find.byTooltip('Пауза'));
      await io(t);
      expect(backend.pauses, 1);
      expect(awake.last, isFalse);
      await t.tap(find.byTooltip('Продолжить'));
      await io(t);
      expect(backend.resumes, 1);
      await t.tap(find.byTooltip('Завершить'));
      await io(t);
      expect(backend.stops, 1);
      expect(awake.last, isFalse);
      await capture(t, 'recorder-finished');
      expect(find.text('Сохранить трек').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets('recorder remains usable at narrow width and large font', (
    t,
  ) async {
    await show(
      t,
      RecorderScreen(controller: c, player: player, backend: FakeCapture()),
      size: const Size(320, 640),
      scale: 1.6,
    );
    await t.ensureVisible(find.byTooltip('Завершить'));
    await t.pumpAndSettle();
    expect(find.text('Сохранить трек').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await io(t);
  });
  testWidgets(
    'history missing audio offers Close/Rebuild and preserves immutable source plus catalog',
    (t) async {
      final run = (await t.runAsync(() async {
        final run = await c.repository.startRun(await c.snapshotForStart());
        await c.repository.checkpoint(
          run.checkpoint(status: RunStatus.interrupted),
        );
        await c.library.fileFor(c.assets.first).delete();
        await c.reload();
        return run;
      }))!;
      final before = c.draft.plan.fingerprint;
      await show(
        t,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => HistoryScreen(controller: c)),
              ),
              child: const Text('История теста'),
            ),
          ),
        ),
      );
      await t.tap(find.text('История теста'));
      await io(t);
      Future<void> repeat() async {
        await t.tap(find.byType(PopupMenuButton<String>));
        await t.pumpAndSettle();
        await t.tap(find.text('Повторить сессию'));
        await io(t);
      }

      await repeat();
      expect(find.text('Точный повтор недоступен'), findsOneWidget);
      await t.tap(find.text('Закрыть'));
      await io(t);
      expect(c.draft.plan.fingerprint, before);
      await repeat();
      await t.tap(find.text('Пересобрать сессию'));
      await io(t);
      await t.tap(find.text('Повторить'));
      await io(t);
      expect(c.draft.archiveName, isNotNull);
      expect(c.draft.unavailableStepIds, hasLength(1));
      expect(
        c.draft.plan.phases!.single.children.every((m) => !m.isModule),
        isTrue,
      );
      expect(c.modules.entries, hasLength(1));
      expect(c.templates, isEmpty);
      expect(c.runs, hasLength(1));
      expect(
        c.runs.single.snapshot.plan.fingerprint,
        run.snapshot.plan.fingerprint,
      );
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'diary audio offers record/pick; cancel adds no block; successful recording persists in original draft',
    (t) async {
      final db = (await t.runAsync(
        () => openAppDatabase(
          '${root.path}/diary.db',
          factory: databaseFactoryFfi,
        ),
      ))!;
      final store = DiaryMediaStore(
        Directory('${root.path}/diary'),
        pick: (_) async => null,
        probe: (_) async => const Duration(seconds: 4),
      );
      final diary = DiaryController(
        DiaryRepository(db),
        authorRepository: DiaryAuthorRepository(db),
        mediaStore: store,
      );
      final now = DateTime.utc(2026, 11, 7);
      final entry = DiaryEntry(
        id: 'original-draft',
        message: 'Черновик',
        createdAt: now,
        updatedAt: now,
        blocks: const [],
      );
      var records = 0;
      final mediaFile = (await t.runAsync(
        () =>
            File('${root.path}/recorded-test.m4a')
                .writeAsBytes(List.filled(16, 1)),
      ))!;
      await show(
        t,
        DiaryEditor(
          diary: diary,
          entry: entry,
          recordAudio: () async {
            records++;
            if (records == 1) return null;
            return DiaryBlock(
              id: 'recorded-block',
              type: DiaryBlockType.audio,
              durationMs: 4000,
              media: DiaryMedia(
                assetId: 'diary-asset',
                mime: 'audio/mp4',
                bytes: 16,
                localPath: mediaFile.path,
              ),
            );
          },
        ),
      );
      final add = find.byKey(const ValueKey('diary-add-audio'));
      await t.ensureVisible(add);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.text('Записать аудио'), findsOneWidget);
      expect(find.text('Выбрать с телефона'), findsOneWidget);
      await t.tap(find.text('Выбрать с телефона'));
      await io(t);
      expect(find.text('Аудиоблок 1'), findsNothing);
      expect(records, 0);
      await t.tap(add);
      await t.pumpAndSettle();
      await t.tap(find.text('Записать аудио'));
      await io(t);
      expect(
        (await t.runAsync(() => DiaryAuthorRepository(db).entries()))!
            .single
            .blocks,
        isEmpty,
      );
      await t.tap(add);
      await t.pumpAndSettle();
      await t.tap(find.text('Записать аудио'));
      await io(t);
      final saved = (await t.runAsync(
        () => DiaryAuthorRepository(db).entries(),
      ))!.single;
      expect(saved.id, entry.id);
      expect(saved.blocks.single.media!.assetId, 'diary-asset');
      expect(records, 2);
      expect(
        await t.runAsync(
          () => File(saved.blocks.single.media!.localPath!).readAsBytes(),
        ),
        List.filled(16, 1),
      );
      await t.pumpWidget(const SizedBox());
      await io(t);
      await t.runAsync(db.close);
    },
  );
}
