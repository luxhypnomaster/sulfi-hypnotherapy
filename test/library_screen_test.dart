import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'support/fakes.dart';

void main() {
  late MemoryRepository repository;
  late MemoryLibrary library;
  late MemoryPlayer player;

  setUp(() {
    repository = MemoryRepository();
    library = MemoryLibrary(repository);
    player = MemoryPlayer();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: sulfiTheme(),
        home: LibraryScreen(library: library, player: player),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Russian empty library and three library sections', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Начните с одной записи'), findsOneWidget);
    expect(find.text('+ Добавить аудио'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-section-suggestions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мои'));
    await tester.pumpAndSettle();
    expect(find.text('Начните с одной записи'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel picker preserves empty library without error', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('+ Добавить аудио'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repository.items, isEmpty);
  });

  testWidgets('import allows editing title and persists on save', (
    tester,
  ) async {
    library.importResult = sampleAsset();
    await open(tester);
    await tester.tap(find.text('+ Добавить аудио'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Моё введение');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.items.values.single.title, 'Моё введение');
    expect(find.text('Моё введение'), findsOneWidget);
    expect(find.text('1 аудио · 1:05'), findsOneWidget);
    expect(library.discarded, isFalse);
  });

  testWidgets('empty title stays in editor; cancel discards imported bytes', (
    tester,
  ) async {
    library.importResult = sampleAsset();
    await open(tester);
    await tester.tap(find.text('+ Добавить аудио'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название'), findsOneWidget);
    expect(repository.items, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(library.discarded, isTrue);
    expect(repository.items, isEmpty);
  });

  testWidgets('failed save discards draft and reports storage error', (
    tester,
  ) async {
    library.importResult = sampleAsset();
    repository.failSave = true;
    await open(tester);
    await tester.tap(find.text('+ Добавить аудио'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.items, isEmpty);
    expect(library.discarded, isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('invalid import shows readable error', (tester) async {
    library.importFails = true;
    await open(tester);
    await tester.tap(find.text('+ Добавить аудио'));
    await tester.pumpAndSettle();
    expect(find.text('Повреждённый файл'), findsOneWidget);
    expect(repository.items, isEmpty);
  });

  testWidgets('rename and search operate on saved library', (tester) async {
    await repository.save(sampleAsset());
    await open(tester);
    await tester.tap(find.byTooltip('Действия с аудио'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить название и категорию'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Завершение');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(repository.items.values.single.title, 'Завершение');
    await tester.enterText(find.byType(TextField), 'нет совпадений');
    await tester.pumpAndSettle();
    expect(find.text('Записи не найдены. Измените поиск.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'заверш');
    await tester.pumpAndSettle();
    expect(find.text('Завершение'), findsOneWidget);
  });

  testWidgets('delete requires confirmation and stops active preview', (
    tester,
  ) async {
    final asset = sampleAsset();
    await repository.save(asset);
    await open(tester);
    await tester.tap(find.byTooltip('Прослушать Тестовая запись'));
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    await tester.tap(find.byTooltip('Действия с аудио'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(repository.items, hasLength(1));
    await tester.tap(find.byTooltip('Действия с аудио'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(repository.items, isEmpty);
    expect(player.current, isNull);
  });

  testWidgets('preview can pause, resume, stop and stops in background', (
    tester,
  ) async {
    await repository.save(sampleAsset());
    await open(tester);
    await tester.tap(find.byTooltip('Прослушать Тестовая запись'));
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    await tester.tap(find.byTooltip('Пауза').last);
    await tester.pumpAndSettle();
    expect(player.playing, isFalse);
    await tester.tap(find.byTooltip('Продолжить'));
    await tester.pumpAndSettle();
    expect(player.playing, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(player.current, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Прослушать Тестовая запись'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Остановить прослушивание'));
    await tester.pumpAndSettle();
    expect(player.current, isNull);
  });

  testWidgets('local reset confirms before clearing data', (tester) async {
    await repository.save(sampleAsset());
    await open(tester);
    await tester.tap(find.byTooltip('О приложении и данных'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить все данные приложения'));
    await tester.pumpAndSettle();
    expect(repository.items, hasLength(1));
    await tester.tap(find.text('Удалить всё'));
    await tester.pumpAndSettle();
    expect(repository.items, isEmpty);
  });

  testWidgets(
    'search combines descriptions and tags with the selected section',
    (tester) async {
      await repository.save(
        sampleAsset().edited(
          'Личный модуль',
          AudioCategory.preparation,
          description: 'Спокойствие и внимание',
          section: LibrarySection.personal,
          tags: ['границы'],
        ),
      );
      await open(tester);
      await tester.enterText(find.byType(TextField), 'границы');
      await tester.pumpAndSettle();
      expect(find.text('Личный модуль'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('library-section-suggestions')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Личный модуль'), findsNothing);
      await tester.tap(find.text('Мои'));
      await tester.pumpAndSettle();
      expect(find.text('Личный модуль'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Спокойствие');
      await tester.pumpAndSettle();
      expect(find.text('Личный модуль'), findsOneWidget);
    },
  );

  testWidgets('layout supports narrow screens and enlarged text', (
    tester,
  ) async {
    await open(tester);
    tester.view.physicalSize = const Size(320, 480);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.drag(vertical, const Offset(0, -500));
    expect(find.text('+ Добавить аудио'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Optional visual artifact, never an Android/device or playback verification.
  // No screenshots or fonts are written to the source tree by default.
  testWidgets('optional UI preview artifact', (tester) async {
    const output = String.fromEnvironment('SULFI_SCREENSHOT_DIR');
    if (output.isEmpty) return;
    const fontPath = String.fromEnvironment('SULFI_TEST_FONT');
    if (fontPath.isNotEmpty) {
      final bytes = await tester.runAsync(() => File(fontPath).readAsBytes());
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes!)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await open(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/library-empty.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
