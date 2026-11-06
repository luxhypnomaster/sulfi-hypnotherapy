import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/fakes.dart';

DiaryEntry entry({
  String id = 'author-entry',
  DiaryStatus status = DiaryStatus.draft,
  int version = 0,
  String body = 'Текст автора',
}) => DiaryEntry(
  id: id,
  message: 'Короткое послание Сульфи',
  body: body,
  createdAt: DateTime.utc(2026, 11, 4, 12),
  updatedAt: DateTime.utc(2026, 11, 4, 12),
  publishedAt: status == DiaryStatus.published
      ? DateTime.utc(2026, 11, 4, 13)
      : null,
  status: status,
  version: version,
);

class FakeDiaryServer {
  DiaryEntry? publicEntry;
  bool offline = false, leakDraft = false, denied = false;
  int revision = 0, writes = 0;
  final removed = <String>[];
  final methods = <String>[];
  Future<DiaryResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    methods.add('$method ${uri.path}');
    if (offline) throw const SocketException('offline');
    if (uri.path == '/v1/public/entries') {
      expect(headers.containsKey('Authorization'), false);
      return DiaryResponse(
        200,
        jsonEncode({
          'entries': [
            if (leakDraft)
              entry().toMap()
            else if (publicEntry != null)
              publicEntry!.toMap(),
          ],
          'removedIds': removed,
          'revision': '$revision',
          'nextPage': null,
        }),
      );
    }
    if (headers['Authorization'] != 'Bearer valid-author' || denied) {
      return const DiaryResponse(403, '{}');
    }
    if (uri.path == '/v1/author/me') {
      return DiaryResponse(
        200,
        jsonEncode({
          'canPublish': true,
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );
    }
    final payload = jsonDecode(body!) as Map<String, dynamic>;
    final old = DiaryEntry.fromMap(payload['entry'] as Map<String, dynamic>);
    if (payload['expectedVersion'] != (publicEntry?.version ?? old.version)) {
      return const DiaryResponse(409, '{}');
    }
    writes++;
    revision++;
    final updated = old.copyWith(
      status: payload['publish'] == true
          ? DiaryStatus.published
          : DiaryStatus.unpublished,
      version: old.version + 1,
      publishedAt: DateTime.now().toUtc(),
    );
    if (payload['publish'] == true) {
      publicEntry = updated;
    } else {
      publicEntry = null;
      removed.add(old.id);
    }
    return DiaryResponse(200, jsonEncode({'entry': updated.toMap()}));
  }
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late Database db;
  late DiaryController author, reader;
  late FakeDiaryServer server;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sulfi_diary');
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    server = FakeDiaryServer();
    final api = DiaryApi(
      Uri.parse('https://diary.example.test/v1'),
      request: server.request,
    );
    author = DiaryController(
      DiaryRepository(db),
      api: api,
      authorRepository: DiaryAuthorRepository(db),
    );
    reader = DiaryController(DiaryRepository(db), api: api);
  });
  tearDown(() async {
    author.dispose();
    reader.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test('D05: author draft survives database close/reopen, never enters public cache', () async {
    await author.saveDraft(entry(body: 'Личный неопубликованный текст'));
    await db.close();
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    expect(
      (await DiaryAuthorRepository(db).entries()).single.body,
      'Личный неопубликованный текст',
    );
    expect(await DiaryRepository(db).published(), isEmpty);
  });
  test('D07 D09: reader cannot save or publish, fake server rejects invalid author', () async {
    await expectLater(
      reader.saveDraft(entry()),
      throwsA(isA<DiaryApiException>()),
    );
    await expectLater(
      reader.publish(entry(), published: true),
      throwsA(isA<DiaryApiException>()),
    );
    await expectLater(
      author.authenticate('wrong'),
      throwsA(isA<DiaryApiException>()),
    );
    expect(server.writes, 0);
    expect(server.methods.where((s) => s.startsWith('PUT')), isEmpty);
  });
  test('D02 D08 D09: authenticated publish, cache, offline, unpublish preserves drafts', () async {
    await author.saveDraft(entry());
    await author.authenticate('valid-author');
    await author.publish(author.drafts.single, published: true);
    await reader.sync();
    expect(reader.published.single.status, DiaryStatus.published);
    server.offline = true;
    await reader.sync();
    expect(reader.error, isNotNull);
    expect(reader.published.single.body, 'Текст автора');
    server.offline = false;
    await author.saveDraft(entry(id: 'another-draft', body: 'Не публиковать'));
    final published = author.drafts.firstWhere((e) => e.id == 'author-entry');
    await author.publish(published, published: false);
    await reader.sync();
    expect(reader.published, isEmpty);
    expect(author.drafts, hasLength(2));
    expect(
      author.drafts.firstWhere((e) => e.id == 'another-draft').body,
      'Не публиковать',
    );
    expect(
      author.drafts.firstWhere((e) => e.id == 'author-entry').status,
      DiaryStatus.unpublished,
    );
  });
  test('D09: invalid draft in public response fails atomically, does not advance cursor', () async {
    await author.authenticate('valid-author');
    await author.publish(entry(), published: true);
    final before = await reader.repository.revision();
    server.leakDraft = true;
    server.revision++;
    await reader.sync();
    expect(reader.error, isNotNull);
    expect(await reader.repository.revision(), before);
    expect(
      (await reader.repository.published()).single.status,
      DiaryStatus.published,
    );
  });
  test(
    'D09: https only and redirect response cannot masquerade as publication',
    () async {
      expect(
        () => DiaryApi(Uri.parse('http://insecure.test')),
        throwsA(isA<DiaryApiException>()),
      );
      final api = DiaryApi(
        Uri.parse('https://diary.example.test/v1'),
        request: (_, _, _, _) async => const DiaryResponse(302, '{}'),
      );
      await expectLater(
        api.authenticate('token'),
        throwsA(isA<DiaryApiException>()),
      );
    },
  );
  test('D03 D04: typography pagination retains Unicode/body, height and font determine page count', () {
    final e = entry(
      body: List.filled(
        180,
        'Продолжение авторского текста 🜍 👩‍👧.\n',
      ).join(),
    );
    const style = TextStyle(fontSize: 16, height: 1.4);
    final small = paginateDiary(e, 300, 360, TextScaler.noScaling, style);
    final large = paginateDiary(e, 300, 700, TextScaler.noScaling, style);
    final scaled = paginateDiary(
      e,
      300,
      360,
      const TextScaler.linear(1.5),
      style,
    );
    expect(small.length, greaterThan(large.length));
    expect(scaled.length, greaterThan(small.length));
    expect(small.join(), e.body);
    expect(scaled.join(), e.body);
    for (var i = 0; i < small.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          style: style,
          children: [
            if (i == 0) diaryHeading(e),
            TextSpan(text: small[i]),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 300);
      expect(painter.height, lessThanOrEqualTo(360));
      painter.dispose();
    }
  });
  testWidgets(
    'D01 D02 D07: normal reader sees publications only, no author controls',
    (t) async {
      await t.runAsync(() => author.saveDraft(entry(body: 'SECRET DRAFT')));
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          home: DiaryScreen(diary: DiaryController(DiaryRepository(db))),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.text('Новая запись'), findsNothing);
      expect(find.textContaining('Каталог ещё не загружен'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'D03 D04 D06: reader and preview use same pagination; metadata only first page',
    (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final e = entry(
        body: List.filled(80, 'Авторский текст для чтения.\n').join(),
      );
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          home: DiaryReader(entry: e),
        ),
      );
      await t.pumpAndSettle();
      final label = t
          .widget<Text>(find.byKey(const Key('diary-pagination')))
          .data;
      expect(label, startsWith('1 из '));
      expect(find.textContaining('Среда', findRichText: true), findsOneWidget);
      await t.tap(find.byTooltip('Следующая страница'));
      await t.pumpAndSettle();
      expect(find.textContaining('Среда', findRichText: true), findsNothing);
      expect(
        t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
        startsWith('2 из '),
      );
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sulfiTheme(),
          home: DiaryReader(key: UniqueKey(), entry: e, preview: true),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
        label,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('D05 D06: author editor autosaves text; real diary renders', (
    t,
  ) async {
    const path = String.fromEnvironment('SULFI_V42_SCREENSHOTS');
    final sdk = File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent;
    final font = await t.runAsync(
      () => File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ).readAsBytes(),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(font!)))).load();
    final icons = await t.runAsync(
      () => File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes(),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons!)))).load();
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Future<void> show(Widget screen) async {
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('diary-render'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: sulfiTheme(),
            home: screen,
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      if (path.isEmpty) return;
      await t.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/art/leather_board.png'),
          t.element(find.byType(Scaffold).last),
        );
      });
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('diary-render')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$path/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await show(
      DiaryEditor(
        diary: author,
        entry: entry(body: ''),
      ),
    );
    await t.enterText(
      find.byKey(const Key('diary-message')),
      'Послание автора',
    );
    await t.enterText(
      find.byType(TextField).last,
      'Длинный текст, сохранённый автором.\n' * 80,
    );
    await t.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    final saved = (await t.runAsync(() => DiaryAuthorRepository(db).entries()))!
        .single;
    expect(saved.message, 'Послание автора');
    expect(saved.body, contains('Длинный текст'));
    await capture('diary-author');
    await show(DiaryReader(key: UniqueKey(), entry: saved, preview: true));
    final textHeight = t
        .getSize(find.byKey(const ValueKey('diary-page-0')))
        .height;
    final viewportHeight = t.getSize(find.byType(SingleChildScrollView)).height;
    expect(textHeight, lessThanOrEqualTo(viewportHeight + .5));
    expect(textHeight, greaterThan(viewportHeight - 80));
    await capture('diary-first');
    await t.tap(find.byTooltip('Следующая страница'));
    await t.pumpAndSettle();
    await capture('diary-next');
    expect(
      find.textContaining('Послание автора', findRichText: true),
      findsNothing,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'D10 H01: home author message opens its publication, four main navigation actions remain',
    (t) async {
      reader.published = [entry(status: DiaryStatus.published, version: 1)];
      final audio = MemoryRepository(),
          library = MemoryLibrary(MemoryRepository());
      final c = SessionController(
        repository: MemorySessionRepository(),
        library: library,
        diary: reader,
      );
      await c.initialize();
      await c.setText(
        topic: 'Длинная тема сессии, которую можно прочитать и открыть для изменения без обрезки в одну строку',
      );
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('home-render'),
          child: SulfiApp(
            library: library,
            player: MemoryPlayer(),
            controller: c,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Библиотека'), findsOneWidget);
      expect(find.text('Шаблоны\nи модули'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
      expect(find.textContaining('мастеру'), findsOneWidget);
      final topic = find.text(c.draft.topicText);
      expect(t.widget<Text>(topic).maxLines, 2);
      const path = String.fromEnvironment('SULFI_V42_SCREENSHOTS');
      if (path.isNotEmpty) {
        await t.runAsync(() async {
          for (final asset in [
            'assets/art/leather_board.png',
            'assets/art/sulfi_header.png',
            'assets/brand/spiral.png',
          ]) {
            await precacheImage(
              AssetImage(asset),
              t.element(find.byType(Scaffold)),
            );
          }
        });
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('home-render')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$path/home.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.tap(find.byKey(const Key('home-diary')));
      await t.pumpAndSettle();
      expect(
        t.widget<DiaryReader>(find.byType(DiaryReader)).entry.id,
        reader.published.single.id,
      );
      expect(audio.items, isEmpty);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
