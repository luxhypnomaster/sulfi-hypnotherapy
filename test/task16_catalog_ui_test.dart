import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_catalog_screen.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_store_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  testWidgets(
    'offline publication card saves edited annotation at 200% font with keyboard; client never sees author editor',
    (t) async {
      final f = (await t.runAsync(() => Fixture15.open()))!;
      try {
        final draft = (await t.runAsync(() async {
          await seed15(f);
          final index = await LocalCatalogSource.currentIndex(f.c.capsules!);
          return f.c.catalog.prepare(
            index.firstWhere((r) => r.key.content.type == ContentType.track),
          );
        }))!;
        await show15(
          t,
          f,
          CatalogCardEditor(service: f.c.catalog, draft: draft),
          size: const Size(360, 640),
          scale: 2,
        );
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('catalog-shortAnnotation')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(
          find.byKey(const ValueKey('catalog-shortAnnotation')),
          'Аннотация офлайн',
        );
        await capture15(t, 'task16-author-annotation-200pct');
        await t.showKeyboard(
          find.byKey(const ValueKey('catalog-shortAnnotation')),
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(t.view.resetViewInsets);
        await t.pump();
        expect(t.takeException(), isNull);
        t.view.viewInsets = const FakeViewPadding();
        t.testTextInput.hide();
        await t.pump();
        await t.scrollUntilVisible(
          find.text('Сохранить черновик'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.text('Сохранить черновик'));
        await io15(t);
        final saved = (await t.runAsync(() => f.c.catalog.drafts()))!;
        expect(saved.single['card']['shortAnnotation'], 'Аннотация офлайн');
        expect(saved.single['status'], 'draft');
        expect(t.takeException(), isNull);
        final moduleDraft = (await t.runAsync(() async {
          final index = await LocalCatalogSource.currentIndex(f.c.capsules!);
          return f.c.catalog.prepare(
            index.firstWhere((r) => r.key.content.type == ContentType.module),
          );
        }))!;
        await show15(
          t,
          f,
          CatalogCardEditor(service: f.c.catalog, draft: moduleDraft),
        );
        expect(find.text('Сохранить черновик'), findsOneWidget);
        await capture15(t, 'task16-author-module-composition');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      } finally {
        await t.runAsync(f.close);
      }
      final client = (await t.runAsync(() => Fixture15.open(client: true)))!;
      try {
        await show15(
          t,
          client,
          AlchemistCatalogScreen(service: client.c.catalog),
          size: const Size(360, 640),
          scale: 2,
        );
        await io15(t);
        expect(find.text('Создать сборку'), findsNothing);
        expect(find.text('Авторские возможности недоступны'), findsOneWidget);
        await show15(
          t,
          client,
          AlchemistStoreScreen(controller: client.c),
          size: const Size(360, 640),
          scale: 2,
        );
        await io15(t);
        await t.showKeyboard(find.byType(TextField).first);
        t.view.viewInsets = const FakeViewPadding(bottom: 240);
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      } finally {
        await t.runAsync(client.close);
      }
    },
  );
}
