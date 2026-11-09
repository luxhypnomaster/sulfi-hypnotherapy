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
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/content_catalog_screen.dart';
import 'package:sulfi_hypnotherapy/ui/diary_content_link.dart';
import 'package:sulfi_hypnotherapy/ui/design.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';
import 'package:sulfi_hypnotherapy/ui/modules_screen.dart';
import 'package:sulfi_hypnotherapy/ui/templates_screen.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/history_attachments.dart';
import 'package:sulfi_hypnotherapy/ui/diary_editor.dart';

import 'dart:convert';

import 'package:sulfi_hypnotherapy/ui/recorder_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_detail_screen.dart';
import 'package:sulfi_hypnotherapy/ui/history_attachment_panel.dart';
import 'package:sulfi_hypnotherapy/ui/modular_structure_screen.dart';
import 'package:sulfi_hypnotherapy/ui/session_scope.dart';
import 'package:sulfi_hypnotherapy/ui/home_screen.dart';
import 'package:sulfi_hypnotherapy/ui/run_screen.dart';

import 'support/session_transport_fake.dart';

import 'support/fakes.dart';
import 'task5_diary_audio_test.dart' show Mp4Capture;

void main() {
  sqfliteFfiInit();
  late Directory root;
  late Database db;
  late SessionController c;
  late DiaryController diary;
  late MemoryPlayer player;
  late SessionRun run;
  final now = DateTime.utc(2026, 11, 7, 12, 30);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('task5-ui');
    db = await openAppDatabase('${root.path}/db', factory: databaseFactoryFfi);
    final library = LibraryService(
      repository: SqliteLibraryRepository(db),
      directory: Directory('${root.path}/audio'),
      pick: () async =>
          (name: 'sample.m4a', path: 'test/fixtures/android_aac_isom.m4a'),
      probe: (_) async => const Duration(seconds: 12),
    );
    await library.initialize();
    await library.save((await library.prepareImport())!);
    diary = DiaryController(
      DiaryRepository(db),
      authorRepository: DiaryAuthorRepository(db),
      mediaStore: DiaryMediaStore(
        Directory('${root.path}/diary'),
        pick: (_) async => null,
        probe: library.probe,
      ),
    );
    c = SessionController(
      repository: SqliteSessionRepository(db),
      library: library,
      diary: diary,
      capsules: CapsuleService(
        database: db,
        library: library,
        diaryDirectory: Directory('${root.path}/diary'),
        workspace: Directory('${root.path}/capsules'),
      ),
      historyAttachments: HistoryAttachments(
        db,
        DiaryMediaStore(
          Directory('${root.path}/history_media'),
          pick: (_) async =>
              (name: 'picture.png', path: '${root.path}/picture.png'),
          probe: library.probe,
          stripImageMetadata: true,
        ),
      ),
    );
    await c.initialize();
    player = MemoryPlayer();
    final module = ModuleDefinition(
      id: 'm',
      title: 'Исторический модуль',
      items: [
        SessionStep(
          id: 'one',
          kind: StepKind.audio,
          title: 'Сохранённый трек',
          audioAssetId: c.assets.single.id,
          durationMs: 12000,
        ),
        const SessionStep(
          id: 'pause',
          kind: StepKind.silence,
          title: 'Пауза',
          durationMs: 30000,
        ),
      ],
    );
    await c.modules.save(module);
    final plan = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'p',
          typeId: 'induction',
          title: 'Историческая индукция',
          children: [module.instantiate('p')],
        ),
        PhaseInstance(
          id: 'exit',
          typeId: 'exit',
          title: 'Выход',
          children: [
            PhaseChild(
              id: 'direct',
              title: 'Прямой',
              items: [
                const SessionStep(
                  id: 'last',
                  kind: StepKind.silence,
                  title: 'Финальная пауза',
                  durationMs: 1000,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final template = await c.saveAsTemplate(
      'Исходный шаблон',
      'Описание при запуске',
      plan: plan,
    );
    await c.loadTemplate(template);
    final started = await c.repository.startRun(await c.snapshotForStart());
    run = started.checkpoint(
      status: RunStatus.interrupted,
      endedAt: now,
      elapsedMs: 15000,
      completedStepIds: [started.snapshot.plan.steps.first.id],
    );
    await c.repository.checkpoint(run, event: 'interrupted');
    await c.reload();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('ru.sulfi/device_files'),
          (_) async => null,
        );
  });
  tearDown(() async {
    c.dispose();
    diary.dispose();
    await db.close();
    await root.delete(recursive: true);
  });
  Future<void> io(WidgetTester t) async {
    for (var i = 0; i < 28; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
  }

  var fonts = false;
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
    if (!fonts) {
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
        final bytes = (await t.runAsync(
          () =>
              File('${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
                  .readAsBytes(),
        ))!;
        await (FontLoader(
          font.$1,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      fonts = true;
    }
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: sulfiTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => SessionScope(
          controller: c,
          player: player,
          child: RepaintBoundary(
            key: const Key('task5-capture'),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
        home: page,
      ),
    );
    await io(t);
  }

  Future<void> screenshot(WidgetTester t, String name) async {
    const dir = String.fromEnvironment('SULFI_TASK5_SCREENSHOTS');
    if (dir.isEmpty) return;
    void repaint(RenderObject node) {
      node.visitChildren(repaint);
      node.markNeedsPaint();
    }

    repaint(
      t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('task5-capture')),
      ),
    );
    await t.pump();
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('task5-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(dir).create(recursive: true);
      await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Task14 three export menus invoke the existing system save dialog',
    (t) async {
      var saves = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('ru.sulfi/device_files'),
            (call) async {
              if (call.method == 'saveZip') {
                saves++;
                return false;
              }
              return null;
            },
          );
      await t.runAsync(() => ModuleCatalog(db).save(c.modules.entries.single));
      await show(
        t,
        LibraryScreen(library: c.library, player: player, controller: c),
      );
      await t.tap(find.byTooltip('Действия с аудио').first);
      await io(t);
      await t.tap(find.text('Экспорт трека'));
      await io(t);
      for (var i = 0; i < 40 && saves < 1; i++) {
        await io(t);
      }
      expect(saves, 1);
      await show(t, ModulesScreen(controller: c, player: player));
      await t.tap(find.byTooltip('Действия модуля').first);
      await io(t);
      await t.tap(find.text('Экспорт модуля'));
      await io(t);
      for (var i = 0; i < 40 && saves < 2; i++) {
        await io(t);
      }
      expect(saves, 2);
      await show(t, TemplatesScreen(controller: c, player: player));
      await t.tap(find.byTooltip('Действия шаблона').first);
      await io(t);
      await t.tap(find.text('Экспорт шаблона'));
      await io(t);
      for (var i = 0; i < 40 && saves < 3; i++) {
        await io(t);
      }
      expect(saves, 3);
      expect(player.playing, false);
      expect((await t.runAsync(c.repository.history))!, hasLength(1));
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'Task14 semantic module and template styles revert after Undo in actual editor and Home',
    (t) async {
      final phase = c.draft.plan.phases!.first;
      final child = phase.children.single;
      final changed = child.copyWith(items: child.items.reversed.toList());
      await t.runAsync(() => c.updateChild(phase.id, changed));
      await show(t, ModularStructureScreen(controller: c, player: player));
      final toggle = find.byKey(ValueKey('expand-${phase.id}'));
      if (find.text('Модуль: ${child.title}').evaluate().isEmpty) {
        await t.tap(toggle);
        await io(t);
      }
      final title = t.widget<Text>(find.text('Модуль: ${child.title}'));
      expect(title.style!.color, neonPink);
      expect(title.style!.fontStyle, FontStyle.italic);
      await screenshot(t, 'task14-module-changed');
      await t.runAsync(() => c.repository.acknowledgeHistory(run.id));
      await show(t, HomeScreen(controller: c, player: player));
      final name = c.draft.baseTemplateName!;
      expect(t.widget<Text>(find.text(name)).style!.color, neonPink);
      expect(
        t.widget<Text>(find.text(name)).style!.fontStyle,
        FontStyle.italic,
      );
      await screenshot(t, 'task14-template-changed');
      await t.runAsync(
        () => c.updateChild(phase.id, changed.copyWith(items: child.items)),
      );
      await io(t);
      expect(c.draft.plan.phases!.first.children.single.modified, true);
      expect(
        t.widget<Text>(find.text(name)).style!.fontStyle,
        FontStyle.normal,
      );
      expect(t.widget<Text>(find.text(name)).style!.color, isNot(neonPink));
      await screenshot(t, 'task14-template-undo');
      await show(t, ModularStructureScreen(controller: c, player: player));
      if (find.text('Модуль: ${child.title}').evaluate().isEmpty) {
        await t.tap(toggle);
        await io(t);
      }
      expect(
        t.widget<Text>(find.text('Модуль: ${child.title}')).style!.fontStyle,
        FontStyle.normal,
      );
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'Task14 catalog cards, exact install and diary installed/unavailable actions are real',
    (t) async {
      await t.runAsync(() => ModuleCatalog(db).save(c.modules.entries.single));
      final zip = (await t.runAsync(
        () => c.capsules!.export(templateId: c.templates.single.id),
      ))!;
      final local = (await t.runAsync(
        () => LocalCatalogSource.open(c.capsules!, zip),
      ))!;
      final revision = local.revisions.singleWhere(
        (r) => r.key.content.type == ContentType.template,
      );
      await show(
        t,
        ContentCatalogScreen(
          controller: c,
          player: player,
          initialSource: local,
        ),
      );
      expect(find.text('ЛОКАЛЬНЫЙ КАТАЛОГ'), findsOneWidget);
      expect(find.textContaining('не онлайн-каталог'), findsOneWidget);
      await screenshot(t, 'task14-catalog-before');
      await t.tap(find.byKey(ValueKey('catalog-${revision.key.token}')));
      await io(t);
      await screenshot(t, 'task14-catalog-details');
      await t.tap(find.widgetWithText(FilledButton, 'Установить'));
      await io(t);
      for (
        var i = 0;
        i < 80 && find.text('Установлено').evaluate().isEmpty;
        i++
      ) {
        await io(t);
      }
      expect(find.text('Установлено'), findsOneWidget);
      expect(player.playing, false);
      await screenshot(t, 'task14-catalog-installed');
      final installedLink = ContentLink(revision.key, ContentLinkAction.open);
      await show(t, Scaffold(body: DiaryContentLink(link: installedLink)));
      expect(find.text('Открыть'), findsOneWidget);
      await screenshot(t, 'task14-diary-installed-link');
      await t.tap(find.text('Открыть'));
      await io(t);
      expect(find.text('ШАБЛОНЫ'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await io(t);
      final track = local.revisions.firstWhere(
        (r) => r.key.content.type == ContentType.track,
      );
      await show(
        t,
        Scaffold(
          body: DiaryContentLink(
            link: ContentLink(track.key, ContentLinkAction.open),
          ),
        ),
      );
      await t.tap(find.text('Открыть'));
      await io(t);
      expect(player.playing, true);
      expect(player.current!.id, track.key.content.id);
      expect(
        await t.runAsync(() => c.library.fileFor(player.current!).exists()),
        true,
      );
      await player.stop();
      await t.pumpWidget(const SizedBox());
      await io(t);
      await t.runAsync(
        () => c.repository.deleteTemplate(revision.key.content.id),
      );
      await t.runAsync(c.reload);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('ru.sulfi/device_files'),
            (call) async => call.method == 'openZip' ? zip.path : null,
          );
      await show(
        t,
        Scaffold(
          body: DiaryContentLink(
            link: ContentLink(revision.key, ContentLinkAction.install),
          ),
        ),
      );
      await t.tap(find.text('Посмотреть / установить'));
      await io(t);
      await t.tap(find.text('Выбрать ZIP материалов'));
      await io(t);
      for (
        var i = 0;
        i < 40 &&
            find
                .byKey(ValueKey('catalog-${revision.key.token}'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await io(t);
      }
      await t.tap(find.byKey(ValueKey('catalog-${revision.key.token}')));
      await io(t);
      await t.tap(find.widgetWithText(FilledButton, 'Установить'));
      await io(t);
      for (
        var i = 0;
        i < 80 && find.text('Установлено').evaluate().isEmpty;
        i++
      ) {
        await io(t);
      }
      expect(find.text('Установлено'), findsOneWidget);
      await screenshot(t, 'task14-diary-install-through-link');
      await t.pumpWidget(const SizedBox());
      await io(t);
      final unknown = RevisionKey(
        const ContentKey(ContentType.track, 'unavailable'),
        'exact',
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      await show(
        t,
        Scaffold(
          body: DiaryContentLink(
            link: ContentLink(unknown, ContentLinkAction.install),
          ),
        ),
      );
      await t.tap(find.text('Посмотреть / установить'));
      await io(t);
      expect(find.textContaining('Точная ревизия недоступна'), findsOneWidget);
      await screenshot(t, 'task14-diary-unavailable-link');
      expect(player.playing, false);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  for (final size in [
    const Size(320, 600),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('Task14 history Home stack ${size.width} $scale', (t) async {
        await t.runAsync(() => c.repository.acknowledgeHistory(run.id));
        final before = (await t.runAsync(c.repository.history))!
            .map((r) => r.toMap())
            .toList();
        await show(
          t,
          HomeScreen(controller: c, player: player),
          size: size,
          scale: scale,
        );
        final nav = Navigator.of(t.element(find.byType(HomeScreen)));
        nav.push<void>(
          MaterialPageRoute(
            builder: (_) => HistoryScreen(
              controller: c,
              player: player,
              selectedRunId: run.id,
            ),
          ),
        );
        await io(t);
        expect(find.byType(HistoryDetailScreen), findsOneWidget);
        for (final key in [
          'history-repeat',
          'history-open-editor',
          'history-home',
        ]) {
          await t.ensureVisible(find.byKey(Key(key)));
          await t.pumpAndSettle();
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          final rect = t.getRect(find.byKey(Key(key)));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
        }
        await screenshot(t, 'task14-history-${size.width.toInt()}-$scale');
        await t.tap(find.byKey(const Key('history-home')));
        await io(t);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(HistoryDetailScreen), findsNothing);
        expect(find.byType(HistoryScreen), findsNothing);
        expect(find.byType(RunScreen), findsNothing);
        expect(nav.canPop(), false);
        expect(player.playing, false);
        expect(
          (await t.runAsync(c.repository.history))!
              .map((r) => r.toMap())
              .toList(),
          before,
        );
        await t.pumpWidget(const SizedBox());
        await io(t);
      });
    }
  }
  testWidgets(
    'Diary actual record route uses attachment form; empty name, save, reopen and capsule retain audio/text without library pollution',
    (t) async {
      final entry = DiaryEntry(
        id: 'entry',
        message: 'Текст до записи',
        createdAt: now,
        updatedAt: now,
        blocks: [
          const DiaryBlock(
            id: 'text',
            type: DiaryBlockType.text,
            text: 'Сохранённый абзац',
          ),
        ],
      );
      final backend = Mp4Capture();
      await show(
        t,
        DiaryEditor(diary: diary, entry: entry, captureBackend: backend),
      );
      await t.tap(find.text('Аудио').first);
      await io(t);
      await t.tap(find.text('Записать аудио'));
      await io(t);
      expect(find.byType(RecorderScreen), findsOneWidget);
      expect(find.text('Аудио для дневника'), findsOneWidget);
      expect(find.text('Теги'), findsNothing);
      expect(find.text('Описание'), findsNothing);
      expect(find.byType(DropdownButtonFormField<AudioCategory>), findsNothing);
      await t.enterText(find.byType(TextFormField), '');
      await t.tap(find.byTooltip('Начать запись'));
      await io(t);
      await t.tap(find.byTooltip('Завершить'));
      await io(t);
      expect(find.text('0:12'), findsOneWidget);
      await screenshot(t, 'diary-recorder-finished');
      await t.tap(find.byTooltip('Удалить'));
      await io(t);
      await t.tap(find.text('Удалить дубль'));
      await io(t);
      await t.tap(find.byTooltip('Начать запись'));
      await io(t);
      await t.tap(find.byTooltip('Завершить'));
      await io(t);
      expect(backend.starts, 2);
      await t.runAsync(
        () => db.execute(
          "CREATE TRIGGER fail_diary_audio BEFORE INSERT ON diary_author WHEN instr(NEW.payload,'audio/mp4') > 0 BEGIN SELECT RAISE(ABORT,'test disk write failure'); END",
        ),
      );
      await t.tap(find.text('Добавить в дневник'));
      await io(t);
      expect(find.byType(RecorderScreen), findsOneWidget);
      expect(
        find.textContaining('Не удалось прикрепить аудио к дневнику'),
        findsOneWidget,
      );
      expect(await t.runAsync(() => File(backend.path!).exists()), isTrue);
      final unchanged = (await t.runAsync(
        () => diary.authorRepository!.entries(),
      ))!.single;
      expect(unchanged.blocks, hasLength(1));
      expect(unchanged.blocks.first.text, 'Сохранённый абзац');
      await t.runAsync(() => db.execute('DROP TRIGGER fail_diary_audio'));
      await t.tap(find.text('Добавить в дневник'));
      await io(t);
      await screenshot(t, 'diary-after-save');
      expect(find.byType(RecorderScreen), findsNothing);
      final saved = (await t.runAsync(() => diary.authorRepository!.entries()))!
          .single;
      expect(saved.message, 'Текст до записи');
      expect(saved.blocks.first.text, 'Сохранённый абзац');
      final audio = saved.blocks.last;
      expect(audio.type, DiaryBlockType.audio);
      expect(audio.label, isNotEmpty);
      expect(
        (await t.runAsync(() => c.library.repository.list()))!,
        hasLength(1),
      );
      expect(
        await t.runAsync(() => diary.mediaStore!.file(audio.media)!.exists()),
        isTrue,
      );
      await screenshot(t, 'diary-attached');
      // Real SQLite re-open and a full portable capsule, rather than a mocked callback.
      await t.pumpWidget(const SizedBox());
      await io(t);
      await show(
        t,
        DiaryEditor(diary: diary, entry: saved, captureBackend: backend),
      );
      expect(find.textContaining(audio.label), findsOneWidget);
      final capsule = CapsuleService(
        database: db,
        library: c.library,
        diaryDirectory: diary.mediaStore!.directory,
        workspace: Directory('${root.path}/capsules'),
      );
      final zip = (await t.runAsync(capsule.export))!;
      final preview = (await t.runAsync(() => capsule.inspect(zip)))!;
      expect(preview.counts['diary_author'], 1);
      await t.runAsync(preview.close);
      await t.runAsync(() async {
        final targetDb = await openAppDatabase(
          '${root.path}/restored-db',
          factory: databaseFactoryFfi,
        );
        try {
          final targetLibrary = LibraryService(
            repository: SqliteLibraryRepository(targetDb),
            directory: Directory('${root.path}/restored/audio'),
            pick: () async => null,
            probe: c.library.probe,
          );
          await targetLibrary.initialize();
          final targetCapsule = CapsuleService(
            database: targetDb,
            library: targetLibrary,
            diaryDirectory: Directory('${root.path}/restored/diary'),
            workspace: Directory('${root.path}/restored/cache'),
          );
          final staged = await targetCapsule.inspect(zip);
          await targetCapsule.restore(staged);
          await staged.close();
          final restored = (await DiaryAuthorRepository(
            targetDb,
          ).entries()).single;
          expect(restored.blocks.last.media!.assetId, audio.media!.assetId);
          expect(
            await File(restored.blocks.last.media!.localPath!).readAsBytes(),
            await diary.mediaStore!.file(audio.media)!.readAsBytes(),
          );
          expect(restored.blocks.first.text, 'Сохранённый абзац');
          expect(await targetLibrary.repository.list(), hasLength(1));
        } finally {
          await targetDb.close();
        }
      });
      await t.tap(find.text('Аудио').last);
      await io(t);
      await t.tap(find.text('Записать аудио'));
      await io(t);
      await t.tap(find.byTooltip('Начать запись'));
      await io(t);
      await t.tap(find.byTooltip('Завершить'));
      await io(t);
      await t.tap(find.text('Отмена'));
      await io(t);
      await t.tap(find.text('Отменить запись'));
      await io(t);
      final afterCancel = (await t.runAsync(
        () => diary.authorRepository!.entries(),
      ))!.single;
      expect(afterCancel.blocks.last.media!.assetId, audio.media!.assetId);
      expect(afterCancel.blocks.length, saved.blocks.length);

      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'selected run opens exact detail with note above fully expanded hierarchy; back shows History and creates no duplicates',
    (t) async {
      final before = (await t.runAsync(() => c.repository.history()))!
          .single
          .snapshot
          .toMap();
      await show(
        t,
        HistoryScreen(controller: c, player: player, selectedRunId: run.id),
      );
      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Исторический модуль'), findsOneWidget);
      expect(find.text('Сохранённый трек'), findsOneWidget);
      expect(find.text('Пауза'), findsOneWidget);
      expect(find.text('Финальная пауза'), findsOneWidget);
      expect(
        t.getTopLeft(find.byKey(const Key('history-note'))).dy,
        lessThan(t.getTopLeft(find.text('План и ход сессии')).dy),
      );
      await screenshot(t, 'history-detail-top');
      await t.enterText(
        find.byKey(const Key('history-note')),
        'Новая заметка без изменения плана',
      );
      await t.tap(find.text('Сохранить заметку'));
      await io(t);
      await t.ensureVisible(find.byKey(const Key('history-open-editor')));
      await t.pumpAndSettle();
      expect(find.text('Открыть в редакторе').hitTestable(), findsOneWidget);
      await screenshot(t, 'history-detail-bottom');
      await t.tap(find.byTooltip('Назад').last);
      await io(t);
      expect(find.byType(HistoryDetailScreen), findsNothing);
      expect(find.text('ИСТОРИЯ'), findsOneWidget);
      await t.tap(find.byKey(ValueKey('history-${run.id}')));
      await io(t);
      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      final history = (await t.runAsync(() => c.repository.history()))!;
      expect(history, hasLength(1));
      expect(history.single.snapshot.toMap(), before);
      expect(history.single.notes, 'Новая заметка без изменения плана');
      expect(await t.runAsync(c.repository.pendingHistory), isNull);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'history editor opens temporary direct steps, cancel leaves current/template/history intact',
    (t) async {
      final before = c.draft.toMap();
      await show(
        t,
        HistoryScreen(controller: c, player: player, selectedRunId: run.id),
      );
      await t.ensureVisible(find.byKey(const Key('history-open-editor')));
      await t.pumpAndSettle();
      await t.tap(find.text('Открыть в редакторе'));
      await io(t);
      expect(find.byType(ModularStructureScreen), findsOneWidget);
      expect(c.draft.toMap(), before);
      expect(c.modules.entries, hasLength(1));
      await screenshot(t, 'history-editor');
      await t.tap(find.byTooltip('Назад').last);
      await io(t);
      await t.tap(find.text('Отбросить'));
      await io(t);
      expect(find.byType(HistoryDetailScreen), findsOneWidget);
      expect(c.draft.toMap(), before);
      expect((await t.runAsync(c.repository.templates))!, hasLength(1));
      expect((await t.runAsync(c.repository.history))!, hasLength(1));
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'restart restores exact pending detail; explicit repeat starts one NEW run and returns to its detail',
    (t) async {
      final transport = TestTransport();
      final historical = run.snapshot.toMap();
      await show(
        t,
        HomeScreen(
          controller: c,
          player: player,
          transportFactory: () => transport,
        ),
      );
      expect(
        t.widget<HistoryDetailScreen>(find.byType(HistoryDetailScreen)).runId,
        run.id,
      );
      expect((await t.runAsync(c.repository.history))!, hasLength(1));
      await t.ensureVisible(find.byKey(const Key('history-repeat')));
      await t.pumpAndSettle();
      await t.tap(find.text('Повторить сессию'));
      await io(t);
      await t.tap(find.text('Начать повтор'));
      await io(t);
      expect(find.byType(RunScreen), findsOneWidget);
      final engine = t.widget<RunScreen>(find.byType(RunScreen)).engine;
      expect(engine.run!.id, isNot(run.id));
      final repeatedId = engine.run!.id;
      expect((await t.runAsync(c.repository.history))!, hasLength(2));
      await t.runAsync(engine.interrupt);
      await io(t);
      expect(
        t.widget<HistoryDetailScreen>(find.byType(HistoryDetailScreen)).runId,
        repeatedId,
      );
      final history = (await t.runAsync(c.repository.history))!;
      expect(history, hasLength(2));
      expect(
        history.firstWhere((r) => r.id == run.id).snapshot.toMap(),
        historical,
      );
      await t.runAsync(engine.close);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'history module completion aggregates frozen children and never current catalogue contents',
    (t) async {
      final child = run.snapshot.plan.phases!.first.children.single;
      final complete = run.checkpoint(
        completedStepIds: child.items.map((s) => s.id).toList(),
      );
      await t.runAsync(() async {
        await db.update(
          'session_runs',
          {'payload': jsonEncode(complete.toMap())},
          where: 'id=?',
          whereArgs: [run.id],
        );
        await c.modules.clear();
        await c.reload();
      });
      await show(
        t,
        HistoryScreen(controller: c, player: player, selectedRunId: run.id),
      );
      final header = find.byKey(ValueKey('history-module-header-${child.id}'));
      expect(header, findsOneWidget);
      final icon = t.widget<Icon>(
        find.descendant(of: header, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.check_circle_outline);
      expect(icon.color, Colors.lightGreenAccent);
      expect(find.text('Исторический модуль'), findsOneWidget);
      expect(c.modules.entries, isEmpty);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'Task6 history picture is attached to exact run, opens and deletes with confirmation without changing snapshot',
    (t) async {
      await t.runAsync(
        () => File('${root.path}/picture.png').writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8/5+BgYGBiYGBgYGBAQAZEQICnc4XwwAAAABJRU5ErkJggg==',
          ),
        ),
      );
      final before = run.snapshot.toMap();
      await show(
        t,
        HistoryScreen(controller: c, player: player, selectedRunId: run.id),
      );
      await t.ensureVisible(find.text('Изображение'));
      await t.pumpAndSettle();
      await t.tap(find.text('Изображение'));
      await io(t);
      await io(t);
      expect(
        (await t.runAsync(() => c.historyAttachments!.list(run.id)))!,
        hasLength(1),
      );
      await t.ensureVisible(find.text('Заметки и вложения'));
      await t.pumpAndSettle();
      await screenshot(t, 'history-attachments');
      expect(
        (await t.runAsync(c.repository.history))!.single.snapshot.toMap(),
        before,
      );
      final thumbnail = find.descendant(
        of: find.byType(HistoryAttachmentPanel),
        matching: find.byType(Image),
      );
      await t.ensureVisible(thumbnail);
      await t.pumpAndSettle();
      await t.tap(thumbnail);
      await io(t);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await t.tapAt(const Offset(5, 5));
      await io(t);
      await t.ensureVisible(find.byTooltip('Удалить вложение'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Удалить вложение'));
      await io(t);
      expect(find.text('Удалить вложение?'), findsOneWidget);
      await t.tap(find.text('Удалить'));
      await io(t);
      expect(
        (await t.runAsync(() => c.historyAttachments!.list(run.id)))!,
        isEmpty,
      );
      expect((await t.runAsync(c.repository.history))!, hasLength(1));
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
  testWidgets(
    'Task6 one preview survives library navigation and closes globally',
    (t) async {
      await t.runAsync(() => c.repository.acknowledgeHistory(run.id));
      await player.toggle(c.assets.first, c.library.fileFor(c.assets.first));
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('task5-capture'),
          child: SulfiApp(library: c.library, player: player, controller: c),
        ),
      );
      await io(t);
      expect(find.byKey(const Key('global-preview-bar')), findsOneWidget);
      await screenshot(t, 'global-preview');
      await t.tap(
        find.descendant(
          of: find.byKey(const Key('global-preview-bar')),
          matching: find.text(c.assets.first.title),
        ),
      );
      await io(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text('Закрыть'));
      await io(t);

      await t.tap(find.text('Библиотека'));
      await io(t);
      expect(player.playing, isTrue);
      await t.tap(find.byTooltip('Назад'));
      await io(t);
      expect(player.playing, isTrue);
      await t.tap(find.byTooltip('Остановить прослушивание'));
      await io(t);
      expect(player.current, isNull);
      await t.pumpWidget(const SizedBox());
      await io(t);
    },
  );
}
