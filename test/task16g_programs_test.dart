import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/templates_modules_screen.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy template ID/wire/capsule graph roundtrips unchanged as program',
    () async {
      final a = await Fixture15.open(), b = await Fixture15.open(client: true);
      try {
        final module = await seed15(a);
        final phase = await a.c.createPhase('induction');
        await a.c.addModule(phase, module);
        final template = await a.c.saveAsTemplate(
          'Архивный шаблон',
          'Имя пользователя не переименовывается',
        );
        final before = (await a.db.query('session_templates')).single;
        final root = (await LocalCatalogSource.currentIndex(a.c.capsules!))
            .singleWhere((r) => r.key.content.id == template.id);
        expect(root.key.content.type, ContentType.template);
        expect(root.key.toMap()['type'], 'template');
        final capsule = await a.c.capsules!.export(templateId: template.id);
        final preview = await b.c.capsules!.inspect(capsule);
        expect(preview.records.containsKey('session_templates'), true);
        expect(preview.records.containsKey('programs'), false);
        await b.c.capsules!.restore(preview);
        await preview.close();
        await b.c.reload();
        final restored = b.c.templates.single;
        expect(restored.id, template.id);
        expect(restored.name, 'Архивный шаблон');
        expect(restored.plan.toMap(), template.plan.toMap());
        expect(b.c.assets, hasLength(3));
        expect(
          jsonDecode(
            (await a.db.query('session_templates')).single['payload'] as String,
          ),
          jsonDecode(before['payload'] as String),
        );
        final imported = (await LocalCatalogSource.currentIndex(b.c.capsules!))
            .singleWhere((r) => r.key.content.id == template.id);
        expect(imported.key.token, root.key.token);
      } finally {
        await a.close();
        await b.close();
      }
    },
  );

  for (final client in [false, true]) {
    testWidgets(
      'program tab label in ${client ? 'CLIENT' : 'MASTER'} leaves legacy rows untouched',
      (t) async {
        final f = (await t.runAsync(() => Fixture15.open(client: client)))!;
        try {
          await t.runAsync(() => f.c.saveAsTemplate('Архивный шаблон', ''));
          final before = await t.runAsync(
            () => f.db.query('session_templates'),
          );
          await t.pumpWidget(
            MaterialApp(
              home: TemplatesModulesScreen(controller: f.c, player: f.player),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Программы'), findsOneWidget);
          expect(find.text('Шаблоны'), findsNothing);
          expect(find.text('Архивный шаблон'), findsOneWidget);
          expect(
            await t.runAsync(() => f.db.query('session_templates')),
            before,
          );
          await t.pumpWidget(const SizedBox.shrink());
        } finally {
          await t.runAsync(f.close);
        }
      },
    );
  }
}
