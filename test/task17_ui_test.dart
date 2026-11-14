import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_editor.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart' show DiaryScreen;
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/catalog_categories.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_catalog_screen.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_export_test.dart' show seed15;

class EnqueueFailure17 extends DiaryApi {
  EnqueueFailure17() : super(Uri.parse('https://example.test'));
  int enqueues = 0;
  @override
  bool get supportsServerIdentity => true;
  @override
  bool get supportsAdvancedPublication => true;
  @override
  bool get readerAuthenticated => true;
  @override
  String get verifiedRole => 'MASTER';
  @override
  String get readerScope => 'account:controlled';
  @override
  Future<void> enqueueDurablePublication(
    DiaryEntry entry, {
    bool? published,
  }) async {
    enqueues++;
    throw const DiaryApiException('CONTROLLED_ENQUEUE_FAILURE');
  }
}

void main() {
  test('17 new category resolves existing case/whitespace while legacy IDs stay unchanged', () {
    final ids = ['Индукция', 'индукция', 'Старая  категория'];
    expect(newCatalogCategory('  ИНДУКЦИЯ ', ids), 'Индукция');
    expect(newCatalogCategory('старая категория', ids), 'Старая  категория');
    expect(newCatalogCategory(' Новая   категория ', ids), 'Новая категория');
    expect(newCatalogCategory('a,b', ids), isNull);
    expect(ids, ['Индукция', 'индукция', 'Старая  категория']);
  });
  test('17 verification is not 0/0 upload; pause causes and permission waits remain distinct', () {
    expect(
      alchemistFileProgress({
        'phase': 'running',
        'stage': 'server_verifying',
        'bytes': 0,
        'totalBytes': 0,
      }),
      isNull,
    );
    expect(
      alchemistFileProgress({
        'phase': 'running',
        'stage': 'transferring',
        'bytes': 12,
        'totalBytes': 24,
      }),
      .5,
    );
    expect(
      alchemistWorkLabel({'phase': 'paused', 'code': 'LIFECYCLE_PAUSED'}),
      contains('сворачивания'),
    );
    expect(
      alchemistWorkLabel({'phase': 'paused', 'code': 'USER_PAUSED'}),
      contains('пользователем'),
    );
    expect(
      alchemistWorkLabel({'phase': 'waiting_permission'}),
      contains('права'),
    );
  });
  testWidgets(
    '17 catalog autosave keeps active field, selection and composing input; editable author default persists',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      try {
        final draft = (await t.runAsync(() async {
          final module = await seed15(f);
          final root = (await LocalCatalogSource.currentIndex(f.c.capsules!))
              .singleWhere((r) => r.key.content.id == module.id);
          return f.c.catalog.prepare(root);
        }))!;
        await show15(
          t,
          f,
          CatalogCardEditor(service: f.c.catalog, draft: draft),
        );
        final field = find.byKey(const ValueKey('catalog-shortAnnotation'));
        await t.scrollUntilVisible(
          field,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(field, 'Аннотация без потери курсора');
        final editableFinder = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final editable = t.widget<EditableText>(editableFinder);
        editable.controller.value = editable.controller.value.copyWith(
          selection: const TextSelection.collapsed(offset: 8),
          composing: const TextRange(start: 0, end: 8),
        );
        expect(editable.focusNode.hasFocus, true);
        await t.pump(const Duration(milliseconds: 650));
        await io15(t);
        expect(t.widget<EditableText>(editableFinder).focusNode.hasFocus, true);
        expect(editable.controller.selection.baseOffset, 8);
        expect(
          editable.controller.value.composing,
          const TextRange(start: 0, end: 8),
        );
        expect(editable.controller.text, 'Аннотация без потери курсора');
        expect(t.widget<TextField>(field).enabled, true);
        await capture15(t, 'task17-catalog-autosave-focus');
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          draft['card']['authorDisplayName'] = 'Редактируемый правообладатель';
          await f.c.catalog.save(draft);
          final restored = AlchemistCatalog(f.c);
          expect(
            await restored.authorDefault(),
            'Редактируемый правообладатель',
          );
          expect(
            (await restored.prepare(
              (await LocalCatalogSource.currentIndex(f.c.capsules!)).first,
              reuse: false,
            ))['card']['authorDisplayName'],
            'Редактируемый правообладатель',
          );
        });
        expect(t.takeException(), isNull);
      } finally {
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    '17 mandatory preview requires every page, not jumping to last; no reader status writes',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final entry = DiaryEntry(
        id: 'review17',
        title: 'Предпросмотр',
        message: 'Короткое послание',
        body: List.filled(
          24,
          'Это длинный проверяемый текст для предпросмотра всех страниц. ',
        ).join(),
        createdAt: DateTime.utc(2026, 11, 13),
        updatedAt: DateTime.utc(2026, 11, 13),
      );
      try {
        final before = (await t.runAsync(() => f.db.query('app_settings')))!;
        await show15(
          t,
          f,
          DiaryReader(entry: entry, preview: true, publicationReview: true),
          size: const Size(360, 640),
        );
        FilledButton confirm() => t.widget<FilledButton>(
          find.byKey(const Key('diary-confirm-publication')),
        );
        expect(confirm().onPressed, isNull);
        final nav = t.widget<DiaryNavigation>(find.byType(DiaryNavigation));
        expect(nav.count, greaterThan(1));
        nav.onPage(nav.count - 1);
        await io15(t);
        if (nav.count > 2) expect(confirm().onPressed, isNull);
        for (var page = 0; page < nav.count; page++) {
          t.widget<DiaryNavigation>(find.byType(DiaryNavigation)).onPage(page);
          await io15(t);
        }
        expect(confirm().onPressed, isNotNull);
        expect(t.takeException(), isNull);
        await capture15(t, 'task17-mandatory-preview');
        final after = (await t.runAsync(() => f.db.query('app_settings')))!;
        expect(
          after,
          before,
          reason: 'Review is not reader completion or publication',
        );
        await t.pumpWidget(const SizedBox());
      } finally {
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    '17 five editor taps open one review; enqueue failure preserves editor and exact local draft',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final api = EnqueueFailure17();
      final d = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
        api: api,
        policy: f.c.policy,
      );
      final entry = DiaryEntry(
        id: 'enqueue17',
        title: 'Заголовок',
        message: 'Обычный текст без кнопки',
        blocks: const [],
        createdAt: DateTime.utc(2026, 11, 13),
        updatedAt: DateTime.utc(2026, 11, 13),
      );
      try {
        await show15(t, f, DiaryEditor(diary: d, entry: entry));
        final button = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'К публикации'),
        );
        for (var i = 0; i < 5; i++) {
          button.onPressed!();
        }
        await io15(t);
        expect(
          find
              .byType(DiaryReader)
              .evaluate()
              .where((e) => !(e.widget as DiaryReader).calculateOnly),
          hasLength(1),
        );
        await t.tap(find.byKey(const Key('diary-confirm-publication')));
        await io15(t);
        expect(api.enqueues, 1);
        expect(find.byType(DiaryEditor), findsOneWidget);
        expect(find.text('CONTROLLED_ENQUEUE_FAILURE'), findsOneWidget);
        final saved = (await t.runAsync(() => d.authorRepository!.entries()))!
            .single;
        expect(saved.id, entry.id);
        expect(saved.title, entry.title);
        expect(saved.message, entry.message);
        expect(saved.blocks, isEmpty);
        expect(t.takeException(), isNull);
        await capture15(t, 'task17-enqueue-failure-editor');
        await t.pumpWidget(const SizedBox());
      } finally {
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    '17 authoritative published author row is not Draft while reader feed cache has not refreshed',
    (t) async {
      final f = (await t.runAsync(Fixture15.open))!;
      final d = DiaryController(
        DiaryRepository(f.db),
        authorRepository: DiaryAuthorRepository(f.db),
        policy: f.c.policy,
      );
      final entry = DiaryEntry(
        id: 'committed17',
        title: 'Подтверждённая запись',
        message: 'Сервер уже подтвердил публикацию',
        status: DiaryStatus.published,
        blocks: const [],
        createdAt: DateTime.utc(2026, 11, 13),
        updatedAt: DateTime.utc(2026, 11, 13),
      );
      try {
        await t.runAsync(() async {
          await d.authorRepository!.save(entry);
          await d.load();
        });
        expect(
          d.published,
          isEmpty,
          reason: 'Reader feed is deliberately stale, authoritative author receipt remains local',
        );
        await show15(t, f, DiaryScreen(diary: d), size: const Size(360, 640));
        expect(find.text('Черновик'), findsNothing);
        expect(find.text('Опубликовано'), findsOneWidget);
        expect(find.text('Опубликовано · есть черновик'), findsNothing);
        expect(t.takeException(), isNull);
        await capture15(t, 'task17-published-author-before-feed-refresh');
        await t.pumpWidget(const SizedBox());
      } finally {
        d.dispose();
        await t.runAsync(f.close);
      }
    },
  );
}
