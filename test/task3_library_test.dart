import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/ui/design.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';

import 'support/fakes.dart';

void main() {
  late MemoryRepository repository;
  late MemoryLibrary library;
  late MemoryPlayer player;
  late SessionController controller;
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
  });
  setUp(() async {
    repository = MemoryRepository();
    library = MemoryLibrary(repository);
    player = MemoryPlayer();
    controller = SessionController(
      repository: MemorySessionRepository(),
      library: library,
    );
    await controller.initialize();
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> seed() async {
    for (final spec in [
      (
        'prep',
        'Фокус подготовка',
        AudioCategory.preparation,
        LibrarySection.general,
      ),
      (
        'deep',
        'Фокус погружение',
        AudioCategory.induction,
        LibrarySection.general,
      ),
      (
        'legacy',
        'Фокус старый',
        AudioCategory.preparation,
        LibrarySection.suggestions,
      ),
      (
        'mine',
        'Фокус личный',
        AudioCategory.suggestions,
        LibrarySection.personal,
      ),
      (
        'other',
        'Без совпадения',
        AudioCategory.preparation,
        LibrarySection.personal,
      ),
      ('work', 'Фокус работа', AudioCategory.work, LibrarySection.personal),
    ]) {
      await repository.save(
        sampleAsset(
          id: spec.$1,
          title: spec.$2,
        ).edited(spec.$2, spec.$3, section: spec.$4),
      );
    }
  }

  Future<void> open(
    WidgetTester t, {
    bool selecting = false,
    Future<void> Function(AudioAsset)? onSelected,
    Size size = const Size(360, 640),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      RepaintBoundary(
        key: const Key('task3-render'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LibraryScreen(
                      library: library,
                      controller: controller,
                      player: player,
                      allowSelection: selecting,
                      onSelected: onSelected,
                    ),
                  ),
                ),
                child: const Text('Открыть библиотеку'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Открыть библиотеку'));
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    const output = String.fromEnvironment('SULFI_TASK3_ARTIFACTS');
    if (output.isEmpty) return;
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('task3-render')),
          )
          .toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$output/$name.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Set<String> rows() => find
      .byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('library-'),
      )
      .evaluate()
      .map(
        (e) => (e.widget.key! as ValueKey<String>).value.substring(
          'library-'.length,
        ),
      )
      .toSet();
  Future<void> menu(WidgetTester t) async {
    await t.tap(find.byKey(const Key('library-categories')));
    await t.pumpAndSettle();
  }

  Future<void> category(WidgetTester t, String id) async {
    final target = find.byKey(ValueKey('category-$id'));
    await t.scrollUntilVisible(
      target,
      id == 'all' ? -180 : 180,
      scrollable: find.descendant(
        of: find.byKey(const Key('library-category-menu')),
        matching: find.byType(Scrollable),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  testWidgets(
    'task3 library uses full width and one toolbar, retains source rows and details',
    (t) async {
      await seed();
      await open(t);
      expect(find.text('Ваши записи. Ваш темп.'), findsNothing);
      expect(find.byType(LeatherBoard), findsNothing);
      expect(find.text('6 аудио · 6:30'), findsOneWidget);
      final search = t.getRect(find.byKey(const Key('library-search')));
      expect(search.left, 8);
      expect(search.right, 352);
      final toolbar = t.getRect(find.byKey(const Key('library-toolbar')));
      for (final key in [
        'library-categories',
        'library-section-general',
        'library-section-suggestions',
        'library-section-personal',
      ]) {
        expect(
          t.getCenter(find.byKey(Key(key))).dy,
          closeTo(toolbar.center.dy, 2),
        );
      }
      expect(rows(), {'prep', 'deep', 'legacy'});
      await capture(t, 'library');
      await t.tap(find.byKey(const ValueKey('library-prep')));
      await t.pumpAndSettle();
      expect(find.textContaining('WAV'), findsOneWidget);
      await t.tap(find.text('Закрыть'));
      await t.pumpAndSettle();
      expect(repository.items, hasLength(6));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'task3 category OR stays open, intersects search and section, reset preserves both and no duplicates',
    (t) async {
      await seed();
      await open(t);
      await t.enterText(find.byKey(const Key('library-search')), 'Фокус');
      await t.pumpAndSettle();
      await menu(t);
      await category(t, 'preparation');
      expect(find.byKey(const Key('library-category-menu')), findsOneWidget);
      await category(t, 'suggestions');
      expect(find.text('Категории · 2'), findsOneWidget);
      expect(rows(), {'prep', 'legacy'});
      await capture(t, 'library-categories');
      await t.tapAt(const Offset(1, 1));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('library-category-menu')), findsNothing);
      await t.tap(find.byKey(const ValueKey('library-section-suggestions')));
      await t.pumpAndSettle();
      expect(rows(), {'legacy', 'mine'});
      expect(find.byKey(const ValueKey('library-legacy')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('library-section-personal')));
      await t.pumpAndSettle();
      expect(rows(), {'mine'});
      await menu(t);
      await category(t, 'all');
      expect(rows(), {'mine', 'work'});
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byKey(const Key('library-category-menu')), findsNothing);
      expect(
        t.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Фокус',
      );
      expect(repository.items, hasLength(6));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'task3 filtered picker inserts repeatedly, preview and context menu never insert',
    (t) async {
      await seed();
      final picked = <String>[];
      await open(
        t,
        selecting: true,
        onSelected: (a) async {
          picked.add(a.id);
        },
      );
      await menu(t);
      await category(t, 'preparation');
      await t.tapAt(const Offset(1, 1));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Прослушать: Фокус подготовка'));
      await t.pumpAndSettle();
      expect(player.current?.id, 'prep');
      expect(picked, isEmpty);
      final row = find.byKey(const ValueKey('pick-prep'));
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
      expect(picked, ['prep', 'prep']);
      expect(find.byType(LibraryScreen), findsOneWidget);
      await t.tap(find.byTooltip('Действия с аудио').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Сведения о треке'));
      await t.pumpAndSettle();
      expect(picked, hasLength(2));
      expect(find.textContaining('WAV'), findsOneWidget);
      await t.tap(find.text('Закрыть'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'task3 small screen and large font keep category menu scrollable and dismissible',
    (t) async {
      await seed();
      await open(t, size: const Size(320, 480), scale: 2);
      await menu(t);
      await category(t, 'freeform');
      expect(find.text('Категории · 1'), findsOneWidget);
      final popup = t.getRect(find.byKey(const Key('library-category-menu')));
      expect(popup.bottom, lessThanOrEqualTo(472));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(320, 240);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('library-categories')));
      await t.pumpAndSettle();
      await menu(t);
      final shortPopup = t.getRect(
        find.byKey(const Key('library-category-menu')),
      );
      expect(shortPopup.bottom, lessThanOrEqualTo(232));
      expect(shortPopup.top, greaterThanOrEqualTo(0));
      await category(t, 'preparation');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
