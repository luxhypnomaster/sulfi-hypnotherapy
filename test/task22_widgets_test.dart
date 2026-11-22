import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/content_link.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/feedback22_store.dart';
import 'package:sulfi_hypnotherapy/ui/admin22_screen.dart';
import 'package:sulfi_hypnotherapy/ui/course22_editor.dart';
import 'package:sulfi_hypnotherapy/ui/catalog22_batch_screen.dart';
import 'package:sulfi_hypnotherapy/ui/feedback22_screen.dart';
import 'package:sulfi_hypnotherapy/ui/diary_content_link.dart';
import 'package:sulfi_hypnotherapy/ui/session_scope.dart';

import 'support/task21_server.dart';
import 'support/task15_harness.dart';
import 'support/task15_fixture.dart';
import 'task22_runtime_test.dart' show script22, run22;

void main() {
  testWidgets(
    '22 seven real admin rows at9:16; quotas unknown, semantic errors, statistics single panel, CLIENT denied',
    (t) async {
      final s = (await t.runAsync(() => Server21.open(script: script22)))!,
          app = (await t.runAsync(() => App21.open(s, projectEnabled: true)))!;
      try {
        await t.runAsync(() async {
          await s.call('control.seed', {'version': 1});
          await app.c.project22!.refresh(app.c.cloudQueue);
          await app.drain();
        });
        await show15(
          t,
          app.f,
          Admin22Screen(controller: app.c),
          size: const Size(360, 640),
        );
        await io15(t);
        for (final section in admin22Sections) {
          expect(find.byKey(Key('admin22-${section.$1}')), findsOneWidget);
        }
        expect(find.textContaining('Опубликовано: 1'), findsWidgets);
        expect(find.textContaining('Storage: нет данных'), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(
          adminState22({
            'metrics': {
              'x': {'state': 'problem'},
              'y': {'state': 'unknown'},
            },
          }, stale: true),
          'problem',
        );
        expect(t.takeException(), null);
        await capture15(t, 'task22-admin-seven-sections');
        await t.ensureVisible(find.byKey(const Key('admin22-statistics')));
        await t.tap(find.byKey(const Key('admin22-statistics')));
        await t.pumpAndSettle();
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('Модель рейтинга'), findsOneWidget);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await s.close();
        });
      }
      final f = (await t.runAsync(() => Fixture15.open(client: true)))!;
      try {
        await show15(t, f, Admin22Screen(controller: f.c));
        expect(find.text('Доступ недоступен'), findsOneWidget);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    '22 optional feedback saves locally with no default consent, skip preserves completed history',
    (t) async {
      final f = (await t.runAsync(() => Fixture15.open(client: true)))!;
      var run = run22('local-complete');
      await t.runAsync(() async {
        run = (await f.c.repository.startRun(run.snapshot))
            .checkpoint(status: RunStatus.completed, endedAt: DateTime.now());
        await f.c.repository.checkpoint(run, event: 'completed');
      });
      final store = Feedback22Store(f.db, owner: () => null);
      try {
        await show15(t, f, Feedback22Screen(store: store, run: run));
        expect(
          t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        await t.tap(find.byKey(const Key('rating22-5')));
        await t.pump();
        await t.tap(find.text('Оставить у себя'));
        await io15(t);
        expect(find.text('Сохранено только на этом телефоне'), findsOneWidget);
        final saved = (await t.runAsync(() => store.load(run.id)))!;
        expect(saved['localOnly'], true);
        expect(saved['feedback']['consent']['share'], false);
        expect(saved['feedback'].containsKey('notes'), false);
        expect(
          (await t.runAsync(f.c.repository.history))!.single.status,
          RunStatus.completed,
        );
        expect(find.byKey(const Key('feedback22-skip')), findsOneWidget);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(f.close);
      }
    },
  );
  testWidgets(
    '22 actual course editor local draft and one exact server receipt on repeated publish',
    (t) async {
      final s = (await t.runAsync(() => Server21.open(script: script22)))!,
          app = (await t.runAsync(() => App21.open(s, projectEnabled: true)))!;
      try {
        await t.runAsync(
          () => s.call('control.seed', {'version': 1, 'type': 'template'}),
        );
        await show15(t, app.f, Course22Editor(controller: app.c));
        await io15(t);
        await t.enterText(
          find.byKey(const Key('course22-title')),
          'Синтетический курс',
        );
        await t.tap(find.byType(DropdownButton<String>));
        await t.pumpAndSettle();
        await t.tap(find.text('Синтетический материал').last);
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Опубликовать курс'));
        await t.tap(find.text('Опубликовать курс'));
        await io15(t);
        expect(
          find.textContaining('Опубликовано: подтверждены'),
          findsOneWidget,
        );
        await t.tap(find.text('Опубликовать курс'));
        await io15(t);
        expect(
          find.text('Эта редакция уже подтверждена сервером'),
          findsOneWidget,
        );
        final state = (await t.runAsync(() => s.call('control.state', {})))!;
        expect(state['counts']['project.catalogBatch'], 1);
        final list = (await t.runAsync(
          () => s.call('project.catalogList', {}),
        ))!;
        expect(
          (list['records'] as List)
              .where((r) => r['type'] == 'course')
              .single['title'],
          'Синтетический курс',
        );
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await s.close();
        });
      }
    },
  );
  testWidgets(
    '22 missing exact ContentLink source exposes no dead install CTA',
    (t) async {
      final s = (await t.runAsync(() => Server21.open(script: script22)))!,
          app = (await t.runAsync(
            () => App21.open(s, client: true, projectEnabled: true),
          ))!;
      try {
        await show15(
          t,
          app.f,
          SessionScope(
            controller: app.c,
            player: app.f.player,
            child: Scaffold(
              body: DiaryContentLink(
                link: ContentLink(
                  RevisionKey(
                    const ContentKey(ContentType.module, 'missing'),
                    'a' * 64,
                    'a' * 64,
                  ),
                  ContentLinkAction.install,
                ),
              ),
            ),
          ),
        );
        await io15(t);
        expect(find.text('Посмотреть / установить'), findsNothing);
        expect(
          find.textContaining('право установки пока не подтверждены'),
          findsOneWidget,
        );
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await s.close();
        });
      }
    },
  );
  testWidgets(
    '22 actual metadata batch UI persists intent and confirms one server receipt without changing audio revision',
    (t) async {
      final s = (await t.runAsync(() => Server21.open(script: script22)))!,
          app = (await t.runAsync(() => App21.open(s, projectEnabled: true)))!;
      try {
        await t.runAsync(() => s.call('control.seed', {'version': 1}));
        await show15(t, app.f, Catalog22BatchScreen(controller: app.c));
        await io15(t);
        await t.tap(find.byKey(const ValueKey('batch22-module-one')));
        await t.pump();
        await t.ensureVisible(find.text('Предпросмотр и применение'));
        await t.tap(find.text('Предпросмотр и применение'));
        await t.pumpAndSettle();
        await t.tap(find.text('Подтвердить правку'));
        await io15(t);
        expect(
          find.text('Пакетная правка подтверждена серверной квитанцией'),
          findsOneWidget,
        );
        final state = (await t.runAsync(() => s.call('control.state', {})))!;
        expect(state['counts']['project.catalogBatch'], 1);
        final list = (await t.runAsync(
          () => s.call('project.catalogList', {}),
        ))!;
        expect((list['records'] as List).single['revisionId'], 'version-1');
        expect(t.takeException(), null);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await app.close();
          await s.close();
        });
      }
    },
  );
}
