import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/ui/alchemist_store_screen.dart';
import 'package:sulfi_hypnotherapy/ui/vitrine_settings_screen.dart';

import 'support/task21_server.dart';
import 'support/task15_harness.dart';

void main() {
  testWidgets(
    '21 real runtime cached catalog stays visible while metadata HEAD offline',
    (t) async {
      final server = (await t.runAsync(Server21.open))!;
      final app = (await t.runAsync(() => App21.open(server, client: true)))!;
      await t.runAsync(() async {
        await server.call('control.seed', {'version': 1});
        await app.c.metadata!.refresh(app.c.cloudQueue);
        await app.drain();
        await server.call('control.mode', {'mode': 'offline'});
      });
      try {
        await show15(t, app.f, AlchemistStoreScreen(controller: app.c));
        await io15(t);
        expect(find.text('Синтетический модуль'), findsOneWidget);
        expect(
          find.byKey(const Key('metadata-capability-status')),
          findsOneWidget,
        );
        expect(find.text('Мои публикации'), findsNothing);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await server.close();
        });
      }
    },
  );
  testWidgets(
    '21 settings UI publishes only through verified capability and real sandbox receipt',
    (t) async {
      final server = (await t.runAsync(Server21.open))!;
      final app = (await t.runAsync(() => App21.open(server)))!;
      await t.runAsync(() => app.c.metadata!.gateway.negotiate());
      final store = app.c.metadata!.settings;
      try {
        await show15(
          t,
          app.f,
          Scaffold(body: VitrineSettingsScreen(store: store)),
        );
        await io15(t);
        final pub = find.widgetWithText(
          OutlinedButton,
          'Опубликовать настройки',
        );
        expect(t.widget<OutlinedButton>(pub).onPressed, isNotNull);
        final field = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Публикация, секунд (1–60)',
        );
        await t.enterText(field, '14');
        await t.ensureVisible(pub);
        await t.tap(pub);
        await io15(t);
        expect(find.text('Публикация подтверждена сервером'), findsOneWidget);
        final state = (await t.runAsync(
          () => server.call('control.state', {}),
        ))!;
        expect(state['configHead']['configRevision'], 1);
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await server.close();
        });
      }
    },
  );
}
