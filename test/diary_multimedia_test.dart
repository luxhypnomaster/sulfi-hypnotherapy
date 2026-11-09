import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/app.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_audio.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_layout.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';
import 'package:sulfi_hypnotherapy/ui/diary_home.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/fakes.dart';
import 'support/async_ui.dart';

DiaryEntry sample({
  String id = 'entry',
  int order = 0,
  int? number = 2,
  List<DiaryBlock>? blocks,
  DiaryStatus status = DiaryStatus.draft,
  int version = 1,
}) => DiaryEntry(
  id: id,
  title: 'Новые возможности Сульфи',
  message: 'Собирайте собственные практики. Ваш внутренний навигатор рядом.',
  body: 'Текст автора',
  blocks: blocks,
  order: order,
  number: number,
  createdAt: DateTime.utc(2026, 11, 3, 18, 41),
  updatedAt: DateTime.utc(2026, 11, 4),
  status: status,
  publishedAt: status == DiaryStatus.published
      ? DateTime.utc(2026, 11, 4)
      : null,
  version: version,
);
DiaryBlock text(String id, String text) =>
    DiaryBlock(id: id, type: DiaryBlockType.text, text: text);
DiaryBlock imageBlock(String path) => DiaryBlock(
  id: 'image',
  type: DiaryBlockType.image,
  width: 320,
  height: 240,
  altText: 'Тестовое изображение',
  caption: 'Иллюстрация',
  media: DiaryMedia(
    assetId: 'image-asset',
    mime: 'image/png',
    bytes: 42,
    localPath: path,
  ),
);
DiaryBlock audioBlock(String path, {String id = 'audio'}) => DiaryBlock(
  id: id,
  type: DiaryBlockType.audio,
  label: 'Голосовое послание',
  durationMs: 340000,
  media: DiaryMedia(assetId: id, mime: 'audio/wav', bytes: 44, localPath: path),
);

class FakeAudio implements DiaryAudioTransport {
  final stream = StreamController<void>.broadcast(sync: true);
  int plays = 0, loads = 0, pauses = 0;
  bool disposed = false;
  Completer<void>? gate;
  @override
  bool playing = false;
  @override
  bool completed = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 340);
  @override
  Stream<void> get changes => stream.stream;
  @override
  Future<void> load(String path) async {
    loads++;
    await gate?.future;
    playing = false;
    completed = false;
    position = Duration.zero;
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
    stream.add(null);
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    stream.add(null);
  }

  @override
  Future<void> seek(Duration p) async {
    position = p;
    completed = false;
    stream.add(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stream.close();
  }
}

class FailingAuthor extends DiaryAuthorRepository {
  FailingAuthor(super.database);
  bool fail = true;
  @override
  Future<void> save(DiaryEntry e) async {
    if (fail) throw const FileSystemException('disk full');
    await super.save(e);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
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
    final provider = const AssetImage('assets/brand/spiral.png');
    final key = await provider.obtainKey(const ImageConfiguration());
    final codec = await ui.instantiateImageCodec(
      await File('assets/brand/spiral.png').readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image)),
      ),
    );
  });
  late Directory dir;
  late Database db;
  late DiaryMediaStore store;
  late DiaryController author;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sulfi_multimedia');
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    store = DiaryMediaStore(
      Directory('${dir.path}/media'),
      pick: (_) async => null,
      probe: (_) async => const Duration(seconds: 340),
    );
    author = DiaryController(
      DiaryRepository(db),
      authorRepository: DiaryAuthorRepository(db),
      mediaStore: store,
    );
  });
  tearDown(() async {
    author.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test('legacy JSON becomes one stable text block without changing characters/dates/number', () async {
    final legacy = sample().toMap()
      ..remove('blocks')
      ..remove('title')
      ..remove('schemaVersion')
      ..remove('order');
    legacy['body'] = '  👩‍👧\r\nТекст\n\nконец  ';
    final e = DiaryEntry.fromMap(legacy);
    expect(e.blocks.single.id, 'entry-text');
    expect(e.body, legacy['body']);
    await author.saveDraft(e);
    await author.load();
    expect(author.drafts.single.body, e.body);
    expect(author.drafts.single.number, 2);
    expect(author.published, isEmpty);
  });
  test('public DTO removes every private path and empty text, retains media metadata', () {
    final e = sample(
      blocks: [
        text('empty', '  '),
        imageBlock('/private/image.png'),
        audioBlock('/private/voice.wav'),
      ],
    );
    final public = jsonEncode(e.toMap(public: true));
    expect(public, isNot(contains('/private')));
    expect(public, isNot(contains('localPath')));
    expect((e.toMap(public: true)['blocks'] as List).length, 2);
    expect(e.toMap()['blocks'], hasLength(3));
  });
  test('local snapshot/draft separation, order and media survive restart; session payload untouched', () async {
    final e = sample(
      status: DiaryStatus.published,
      blocks: [
        text('t', 'Старая публикация'),
        audioBlock('${dir.path}/voice.wav'),
      ],
    );
    await author.repository.cache([e], {}, 'catalog-r1');
    await author.saveDraft(
      e.copyWith(
        title: 'Новый черновик',
        blocks: [text('t', 'Не публиковать')],
      ),
    );
    final before = await db.query('session_templates');
    await db.close();
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    expect(
      (await DiaryRepository(db).published()).single.body,
      'Старая публикация',
    );
    expect(
      (await DiaryAuthorRepository(db).entries()).single.title,
      'Новый черновик',
    );
    expect(await db.query('session_templates'), before);
  });
  test('v4 to v6 additive migration retains author/public payload and actual media', () async {
    final file = await File('${dir.path}/keep.wav')
        .writeAsString('private recording');
    await author.saveDraft(sample());
    final payload = (await db.query('diary_author')).single['payload'];
    await db.execute('DROP TABLE diary_removed');
    await db.execute('PRAGMA user_version=4');
    await db.close();
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    expect((await db.query('diary_author')).single['payload'], payload);
    expect(await file.readAsString(), 'private recording');
    expect(await db.getVersion(), 9);
    expect(await db.query('diary_removed'), isEmpty);
  });
  test(
    'malformed stored diary stays intact and does not hide valid entries',
    () async {
      await author.saveDraft(sample());
      await db.insert('diary_author', {
        'id': 'broken',
        'updatedAt': DateTime.utc(2026).toIso8601String(),
        'payload': '{broken',
      });
      await author.load();
      expect(author.drafts, hasLength(1));
      expect(author.error, contains('Исходные данные'));
      expect(
        (await db.query(
          'diary_author',
          where: 'id=?',
          whereArgs: ['broken'],
        )).single['payload'],
        '{broken',
      );
    },
  );
  test(
    'long short message saves without a hidden 1000 character limit',
    () async {
      await author.saveDraft(sample().copyWith(message: 'Строка\n' * 300));
      expect(author.drafts.single.message, 'Строка\n' * 300);
    },
  );
  test('local reorder atomic, numbers stable; deleting a draft preserves public snapshot and other rows', () async {
    final a = sample(id: 'a', number: 42),
        b = sample(id: 'b', order: 1, number: 7);
    await author.saveDraft(a);
    await author.saveDraft(b);
    await author.reorderEntries([b, a]);
    expect(author.drafts.map((e) => e.id), ['b', 'a']);
    expect(author.drafts.map((e) => e.number), [7, 42]);
    await authorRepositoryDeleteDraftOnly(a, author);
    expect(author.drafts.single.id, 'b');
  });
  test('tombstone resists replay of older cached page, allows higher version after unpublish', () async {
    final e = sample(status: DiaryStatus.published, version: 3);
    await author.repository.cache([e], {}, 'one');
    await author.repository.cache([], {'entry'}, 'two');
    await author.repository.cache([e], {}, 'old-page');
    expect(await author.repository.published(), isEmpty);
    await author.repository.cache([e.copyWith(version: 4)], {}, 'new');
    expect((await author.repository.published()).single.version, 4);
  });
  test('HTML, auth denial, missing entry and bad public DTO keep last good catalog', () async {
    final good = sample(status: DiaryStatus.published);
    await author.repository.cache([good], {}, 'last-good');
    for (final response in [
      const DiaryResponse(200, '<html>Sign in</html>'),
      const DiaryResponse(403, '{}'),
      const DiaryResponse(404, '{}'),
      DiaryResponse(
        200,
        jsonEncode({
          'entries': [sample().toMap()],
          'removedIds': [],
          'revision': 'bad',
          'nextPage': null,
        }),
      ),
    ]) {
      final c = DiaryController(
        DiaryRepository(db),
        api: DiaryApi(
          Uri.parse('https://test.invalid'),
          request: (_, _, _, _) async => response,
        ),
      );
      await c.load();
      await c.sync();
      expect(c.error, isNotNull);
      expect(c.published.single.id, good.id);
      expect(await c.repository.revision(), 'last-good');
      c.dispose();
    }
  });
  test(
    'inconsistent catalog pages retry one snapshot before atomic cache update',
    () async {
      var calls = 0;
      final api = DiaryApi(
        Uri.parse('https://test.invalid'),
        request: (_, uri, _, _) async {
          calls++;
          return DiaryResponse(
            200,
            jsonEncode({
              'entries': [],
              'removedIds': [],
              'revision': calls == 1 ? 'a' : 'b',
              'nextPage': calls == 1 ? 'page2' : null,
            }),
          );
        },
      );
      final c = DiaryController(DiaryRepository(db), api: api);
      await c.sync();
      expect(calls, 3);
      expect(c.error, isNull);
      expect(c.hasCache, true);
      expect(c.published, isEmpty);
      c.dispose();
    },
  );
  test(
    'unverified multimedia server cannot silently strip title or media',
    () async {
      var puts = 0;
      final api = DiaryApi(
        Uri.parse('https://test.invalid'),
        request: (m, _, _, _) async {
          if (m == 'PUT') puts++;
          return DiaryResponse(
            200,
            jsonEncode({
              'canPublish': true,
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            }),
          );
        },
      );
      final session = await api.authenticate('test-token');
      await expectLater(
        api.publish(
          sample(blocks: [audioBlock('/private.wav')]),
          session,
          published: true,
        ),
        throwsA(isA<DiaryApiException>()),
      );
      expect(puts, 0);
    },
  );
  test('cancelled replacement preserves original ID/order/file', () async {
    final old = imageBlock('${dir.path}/original.png');
    expect(await store.import(DiaryBlockType.image, blockId: old.id), isNull);
    expect(old.id, 'image');
    expect(old.media!.localPath, endsWith('original.png'));
  });
  test('renamed video rejected for image and audio, no temporary artifact retained', () async {
    final source = await File('${dir.path}/video.mp3').writeAsBytes([
      0,
      0,
      0,
      24,
      ...'ftypisom'.codeUnits,
      ...List.filled(24, 0),
    ]);
    for (final type in [DiaryBlockType.image, DiaryBlockType.audio]) {
      await expectLater(
        store.importFile(type, (name: 'fake.png', path: source.path)),
        throwsFormatException,
      );
    }
    expect(await store.directory.list().toList(), isEmpty);
    expect(await source.exists(), true);
  });
  test('valid PNG is decoded and copied; replacement keeps block id and original source', () async {
    final source = File('assets/brand/spiral.png');
    final imported = await store.importFile(DiaryBlockType.image, (
      name: 'logo.png',
      path: source.path,
    ), blockId: 'stable-block');
    expect(imported.id, 'stable-block');
    expect(imported.width, greaterThan(0));
    expect(imported.height, greaterThan(0));
    expect(imported.media!.hash, hasLength(64));
    expect(
      await store.file(imported.media)!.readAsBytes(),
      await source.readAsBytes(),
    );
    expect(await source.exists(), true);
    await author.saveDraft(sample(blocks: [imported]));
    expect(
      (await DiaryAuthorRepository(
        db,
      ).entries()).single.blocks.single.media!.assetId,
      imported.media!.assetId,
    );
  });
  test('valid audio header copies to private stable store, duration comes from injected decoder', () async {
    final f = await File('${dir.path}/source.wav').writeAsBytes([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
      0,
      0,
    ]);
    final block = await store.importFile(DiaryBlockType.audio, (
      name: 'Voice.wav',
      path: f.path,
    ));
    expect(block.durationMs, 340000);
    expect(block.media!.mime, 'audio/wav');
    expect(await store.file(block.media)!.exists(), true);
  });
  test(
    'failed audio decoder rolls back copied file, never deletes original',
    () async {
      final source = await File('${dir.path}/broken.mp3')
          .writeAsBytes([73, 68, 51, 1, 2, 3]);
      final bad = DiaryMediaStore(
        store.directory,
        pick: (_) async => null,
        probe: (_) async => throw const FormatException('bad decoder'),
      );
      await expectLater(
        bad.importFile(DiaryBlockType.audio, (
          name: 'broken.mp3',
          path: source.path,
        )),
        throwsFormatException,
      );
      expect(await store.directory.list().toList(), isEmpty);
      expect(await source.exists(), true);
    },
  );
  test(
    'gc respects all snapshots; paths outside diary storage cannot be opened',
    () async {
      await store.directory.create();
      final kept = await File('${store.directory.path}/keep.wav')
          .writeAsBytes([1]);
      final orphan = await File('${store.directory.path}/orphan.part')
          .writeAsBytes([2]);
      await store.collect({kept.path});
      expect(await kept.exists(), true);
      expect(await orphan.exists(), false);
      expect(
        store.file(
          DiaryMedia(
            assetId: 'bad',
            mime: 'audio/wav',
            bytes: 1,
            localPath: '${dir.path}/secret',
          ),
        ),
        isNull,
      );
    },
  );
  test('pagination retains exact Unicode including CRLF, whitespace and long words across 50+ pages', () async {
    final original = ('\r\n  Абзац 👩‍👧‍👦 е́   слова\n\n${'я' * 180}') * 220;
    final e = sample(blocks: [text('unicode', original)]);
    final layout = await layoutDiary(e, 240, 260, TextScaler.noScaling);
    expect(layout.pages.length, greaterThan(50));
    final fragments = layout.pages.expand((p) => p.fragments).toList();
    expect(fragments.map((f) => f.text ?? '').join(), original);
    for (final f in fragments) {
      expect(original.substring(f.offset, f.end), f.text);
      expect(f.text, isNot(startsWith('\u200d')));
    }
    final anchor = DiaryAnchor('unicode', fragments[60].offset);
    final resized = await layoutDiary(e, 310, 440, const TextScaler.linear(2));
    final p = resized.pageFor(anchor);
    expect(
      resized.pages[p].fragments.any(
        (f) => anchor.offset >= f.offset && anchor.offset < f.end,
      ),
      true,
    );
  });
  test(
    'image and audio remain atomic at page edge, reserve same heights offline',
    () async {
      final e = sample(
        blocks: [
          text('t', 'Текст\n' * 25),
          imageBlock('/missing'),
          audioBlock('/missing'),
        ],
      );
      final layout = await layoutDiary(e, 300, 400, TextScaler.noScaling);
      for (final id in ['image', 'audio']) {
        expect(
          layout.pages
              .expand((p) => p.fragments)
              .where((f) => f.block.id == id),
          hasLength(1),
        );
      }
      expect(
        layout.pages
            .expand((p) => p.fragments)
            .where((f) => f.block.id == 'image')
            .single
            .height,
        greaterThan(48),
      );
    },
  );
  test(
    'extreme font/small window still advances and keeps all content',
    () async {
      final e = sample(
        blocks: [
          text('t', '🧘🏽‍♀️  слово\n' * 8),
          imageBlock('/missing'),
          audioBlock('/missing'),
        ],
      );
      final layout = await layoutDiary(e, 80, 20, const TextScaler.linear(3));
      expect(layout.pages.length, lessThan(200));
      expect(
        layout.pages
            .expand((p) => p.fragments)
            .where((f) => f.text != null)
            .map((f) => f.text)
            .join(),
        e.body,
      );
    },
  );
  test(
    'one audio at a time, pause/seek/end/replay and position per block',
    () async {
      await store.directory.create();
      final file = await File('${store.directory.path}/voice.wav')
          .writeAsBytes([1]);
      final t = FakeAudio(),
          a = audioBlock(file.path),
          b = audioBlock(file.path, id: 'b');
      final player = DiaryAudio(transport: t, store: store);
      await player.toggle(a);
      expect(t.plays, 1);
      await player.seek(const Duration(seconds: 42));
      await player.pause();
      expect(t.playing, false);
      await player.toggle(b);
      expect(player.current, 'b');
      expect(t.position, Duration.zero);
      await player.toggle(a);
      expect(t.position, const Duration(seconds: 42));
      t.completed = true;
      t.playing = false;
      await player.toggle(a);
      expect(t.position, Duration.zero);
      await player.close();
      expect(t.disposed, true);
    },
  );
  test(
    'background or page change during slow decoder prevents delayed autoplay',
    () async {
      await store.directory.create();
      final file = await File('${store.directory.path}/voice.wav')
          .writeAsBytes([1]);
      final t = FakeAudio()..gate = Completer<void>();
      final player = DiaryAudio(transport: t, store: store);
      final pending = player.toggle(audioBlock(file.path));
      for (var i = 0; i < 20 && t.loads == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await player.pause();
      t.gate!.complete();
      await pending;
      expect(t.plays, 0);
      await player.close();
    },
  );
  test('active session blocks diary audio; missing media shows retry without affecting text', () async {
    final t = FakeAudio();
    final player = DiaryAudio(
      transport: t,
      store: store,
      sessionActive: () => true,
    );
    await player.toggle(audioBlock('/missing'));
    expect(player.error, contains('сессию'));
    expect(t.plays, 0);
    await player.close();
    final missing = DiaryAudio(transport: FakeAudio(), store: store);
    await missing.toggle(audioBlock('/missing'));
    expect(missing.error, contains('офлайн'));
    await missing.close();
  });

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
        key: const Key('capture'),
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
    await t.pumpAndSettle();
  }

  Future<void> settleIo(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
  }

  Future<void> capture(WidgetTester t, String name) async {
    const output = String.fromEnvironment('SULFI_DIARY_ARTIFACTS');
    if (output.isEmpty) return;
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').parent.create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'save error retains editor values, retry persists; short message grows and has no newline limit',
    (t) async {
      final failing = FailingAuthor(db),
          c = DiaryController(
            DiaryRepository(db),
            authorRepository: FailingAuthor(db),
          );
      // Use the same injectable repository for the retry.
      final editable = DiaryController(
        DiaryRepository(db),
        authorRepository: failing,
        mediaStore: store,
      );
      await show(t, DiaryEditor(diary: editable, entry: sample()));
      final message = find.byKey(const Key('diary-message'));
      await t.enterText(message, 'Строка\n' * 20);
      await t.pump(const Duration(milliseconds: 400));
      await settleIo(t);
      expect(
        find.textContaining('Не удалось сохранить черновик'),
        findsOneWidget,
      );
      expect(t.widget<TextField>(message).controller!.text, 'Строка\n' * 20);
      expect(t.widget<TextField>(message).maxLength, isNull);
      failing.fail = false;
      await t.ensureVisible(find.text('Сохранить черновик'));
      await t.pumpAndSettle();
      await t.tap(find.text('Сохранить черновик'));
      await pumpUntilIo(
        t,
        () =>
            find.textContaining('Сохранено на телефоне').evaluate().isNotEmpty,
        reason: 'Повтор должен завершить запись дневника после отказа SQLite',
      );
      expect(
        (await t.runAsync(() => DiaryAuthorRepository(db).entries()))!
            .single
            .message,
        'Строка\n' * 20,
      );
      expect(find.textContaining('Сохранено на телефоне'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      editable.dispose();
    },
  );
  testWidgets(
    'reader has green active buttons, grey disabled, both active on middle page; preview matches',
    (t) async {
      final e = sample(blocks: [text('t', 'Абзац текста 👩‍👧.\n' * 100)]);
      await show(t, DiaryReader(entry: e));
      final label = t
          .widget<Text>(find.byKey(const Key('diary-pagination')))
          .data;
      final prev = find.ancestor(
        of: find.byTooltip('Предыдущая страница'),
        matching: find.byType(Row),
      );
      expect(prev, findsWidgets);
      expect(
        t.widget<OutlinedButton>(find.byType(OutlinedButton).first).onPressed,
        isNull,
      );
      await t.tap(find.byTooltip('Следующая страница'));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
        startsWith('2 из '),
      );
      expect(find.text(e.title), findsNothing);
      for (final b in t.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(b.onPressed, isNotNull);
        expect(b.style!.foregroundColor!.resolve({}), const Color(0xFFC1DFA7));
      }
      await show(t, DiaryReader(key: UniqueKey(), entry: e, preview: true));
      expect(
        t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
        label,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'seek owns horizontal gesture, page leave and lifecycle pause active audio',
    (t) async {
      await t.runAsync(() => store.directory.create(recursive: true));
      final path = '${store.directory.path}/voice.wav';
      await t.runAsync(() => File(path).writeAsBytes([1]));
      final transport = FakeAudio();
      DiaryAudio? player;
      final c = DiaryController(
        DiaryRepository(db),
        mediaStore: store,
        audioFactory: () =>
            player = DiaryAudio(transport: transport, store: store),
      );
      await show(
        t,
        DiaryReader(
          entry: sample(
            blocks: [audioBlock(path), text('long', 'Длинный текст.\n' * 120)],
          ),
          diary: c,
        ),
      );
      await t.tap(find.byTooltip('Воспроизвести аудио'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(transport.playing, true);
      await capture(t, 'audio/0000');
      await t.drag(find.byType(Slider), const Offset(150, 0));
      await t.pumpAndSettle();
      expect(transport.position.inSeconds, greaterThan(0));
      await capture(t, 'audio/0001');
      expect(
        t.widget<Text>(find.byKey(const Key('diary-pagination'))).data,
        startsWith('1 из '),
      );
      await t.tap(find.byTooltip('Следующая страница'));
      await t.pumpAndSettle();
      await capture(t, 'audio/0002');
      expect(transport.playing, false);
      await t.tap(find.byTooltip('Предыдущая страница'));
      await t.pumpAndSettle();
      expect(transport.playing, false);
      await t.tap(find.byTooltip('Воспроизвести аудио'));
      await settleIo(t);
      expect(transport.playing, true);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(transport.playing, false);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(transport.playing, false);
      expect(player!.current, 'audio');
      await t.pumpWidget(const SizedBox());
      await settleIo(t);
      expect(transport.disposed, true);
      c.dispose();
    },
  );
  testWidgets(
    'author journal search/date disables drag; reader controls absent; delete needs confirmation',
    (t) async {
      await t.runAsync(() async {
        await author.saveDraft(sample());
        await author.saveDraft(sample(id: 'second', order: 1));
      });
      await show(t, DiaryScreen(diary: author));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      await t.enterText(find.byType(TextField), 'Новые');
      await t.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      await t.tap(find.byTooltip('Удалить запись').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Новые возможности Сульфи'), findsWidgets);
      await t.tap(find.text('Отмена'));
      await t.pumpAndSettle();
      expect(author.drafts, hasLength(2));
      await t.tap(find.text('Читатель'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Удалить запись'), findsNothing);
      expect(find.text('Новая запись'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '200 percent font: reader/editor/journal keep reachable controls at 360dp',
    (t) async {
      for (final screen in [
        DiaryReader(
          entry: sample(
            blocks: [text('t', 'Текст ' * 50), audioBlock('/missing')],
          ),
        ),
        DiaryEditor(diary: author, entry: sample()),
        DiaryScreen(diary: author),
      ]) {
        await show(t, screen, size: const Size(360, 780), scale: 2);
        expect(
          t.takeException(),
          isNull,
          reason: screen.runtimeType.toString(),
        );
        await t.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'real block drag, preview and page navigation preserve draft and scroll',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final e = sample(
        blocks: [text('one', 'Первый блок'), text('two', 'Второй блок')],
      );
      await show(
        t,
        DiaryEditor(diary: author, entry: e),
        size: const Size(360, 900),
      );
      await capture(t, 'drag/0000');
      final handles = find.byType(ReorderableDragStartListener);
      final first = t.getCenter(handles.at(0)),
          second = t.getCenter(handles.at(1));
      final pointer = await t.startGesture(second);
      await pointer.moveBy(const Offset(0, -30));
      await t.pump(const Duration(milliseconds: 80));
      for (var step = 1; step <= 8; step++) {
        await pointer.moveTo(
          Offset.lerp(
            second - const Offset(0, 30),
            first - const Offset(0, 40),
            step / 8,
          )!,
        );
        await t.pump(const Duration(milliseconds: 80));
        await capture(t, 'drag/${step.toString().padLeft(4, '0')}');
      }
      await pointer.moveTo(first - const Offset(0, 40));
      await t.pump(const Duration(milliseconds: 400));
      await pointer.up();
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 400));
      await settleIo(t);
      expect(
        (await t.runAsync(() => DiaryAuthorRepository(db).entries()))!
            .single
            .blocks
            .map((b) => b.id),
        ['two', 'one'],
      );
      await capture(t, 'drag/0009');
      await t.tap(find.text('Предпросмотр'));
      await settleIo(t);
      await t.pumpAndSettle();
      expect(find.byType(DiaryReader), findsOneWidget);
      await capture(t, 'drag/0010');
      await t.tap(find.text('Вернуться в редактор'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('diary-title')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'render real Flutter editor/reader/journals/sticker for review, synthetic content only',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      // Test-only art, not shipped with the app or uploaded to the owner's Drive.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 320, 240),
        Paint()..color = const Color(0xFF281027),
      );
      canvas.drawCircle(
        const Offset(160, 120),
        70,
        Paint()..color = const Color(0xFFB50968),
      );
      final picture = recorder.endRecording(),
          im = await t.runAsync(() => picture.toImage(320, 240));
      final png = await t.runAsync(
        () => im!.toByteData(format: ui.ImageByteFormat.png),
      );
      await t.runAsync(() => store.directory.create(recursive: true));
      final path = '${store.directory.path}/demo.png';
      await t.runAsync(
        () => File(path).writeAsBytes(png!.buffer.asUint8List()),
      );
      final cacheKey = FileImage(File(path));
      PaintingBinding.instance.imageCache.putIfAbsent(
        cacheKey,
        () => OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: im!.clone())),
        ),
      );
      im!.dispose();
      picture.dispose();
      final e = sample(
        blocks: [
          text(
            'intro',
            'Теперь можно создавать собственные модули и собирать свои библиотеки.\n\n' *
                5,
          ),
          imageBlock(path),
          audioBlock('${store.directory.path}/demo.wav'),
          text('end', 'Ваш внутренний навигатор.\n' * 12),
        ],
      );
      final visualAuthor = DiaryController(
        DiaryRepository(db),
        authorRepository: DiaryAuthorRepository(db),
        mediaStore: store,
        audioFactory: () => DiaryAudio(transport: FakeAudio(), store: store),
      );
      await t.runAsync(
        () => File('${store.directory.path}/demo.wav').writeAsBytes([1]),
      );
      await show(t, DiaryEditor(diary: visualAuthor, entry: e));
      await settleIo(t);
      await t.pumpAndSettle();
      await settleIo(t);
      await t.pumpAndSettle();
      await capture(t, 'editor');
      await show(
        t,
        DiaryReader(key: UniqueKey(), entry: e, diary: visualAuthor),
      );
      await capture(t, 'reader-01');
      await t.tap(find.byTooltip('Следующая страница'));
      await t.pumpAndSettle();
      await capture(t, 'reader-02');
      await t.tap(find.byTooltip('Следующая страница'));
      await t.pumpAndSettle();
      await capture(t, 'reader-03');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() => author.saveDraft(e));
      await show(t, DiaryScreen(diary: author));
      await capture(t, 'journal-author');
      final reader = DiaryController(DiaryRepository(db));
      await t.runAsync(() async {
        await reader.repository.cache(
          [
            e.copyWith(
              status: DiaryStatus.published,
              publishedAt: DateTime.utc(2026, 11, 4),
            ),
          ],
          {},
          'test-r1',
        );
        await reader.load();
      });
      await show(t, DiaryScreen(diary: reader));
      await capture(t, 'journal-reader');
      await show(
        t,
        Scaffold(
          body: SafeArea(
            child: DiaryHomeBoard(
              diary: reader,
              child: Column(
                children: [
                  DiaryHomeMessage(diary: reader),
                  const Expanded(
                    child: Center(child: Text('Сессия · тестовый стенд')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await capture(t, 'sticker');
      final library = MemoryLibrary(MemoryRepository());
      final sessions = SessionController(
        repository: MemorySessionRepository(),
        library: library,
        diary: reader,
      );
      await sessions.initialize();
      await t.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: SulfiApp(
            library: library,
            player: MemoryPlayer(),
            controller: sessions,
          ),
        ),
      );
      await t.pumpAndSettle();
      await settleIo(t);
      await t.pumpAndSettle();
      await capture(t, 'home');
      await t.pumpWidget(const SizedBox());
      sessions.dispose();
      await t.pumpWidget(const SizedBox());
      reader.dispose();
      visualAuthor.dispose();
    },
  );
}

Future<void> authorRepositoryDeleteDraftOnly(
  DiaryEntry e,
  DiaryController author,
) => author.deleteEntry(e);
