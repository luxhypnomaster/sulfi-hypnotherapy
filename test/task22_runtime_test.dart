import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/project22_runtime.dart';
import 'package:sulfi_hypnotherapy/models/ratings22.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';

import 'support/task21_server.dart';
import 'task15_export_test.dart' show seed15;

const script22 = 'server/alchemist/test/support/project22-fixture.cjs';
const target22 = {
  'type': 'MODULE',
  'contentId': 'module-one',
  'revisionId': 'version-1',
  'ratingEpochId': 'epoch1',
};
SessionRun run22(String id) => SessionRun(
  id: id,
  displayNumber: 1,
  name: id,
  startedAt: DateTime(2026),
  status: RunStatus.completed,
  snapshot: CurrentSessionDraft(
    updatedAt: DateTime(2026),
    plan: SessionPlan(steps: const []),
  ),
);

Future<void> recompute22(Server21 s, String request) async {
  final j = await s.call('ratings.recompute', {'requestId': request});
  expect(
    (await s.call('project.runOperation', {
      'operationId': j['operationId'],
    }))['state'],
    'SUCCEEDED',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('22 six real runtime intents one overview; equal revision zero extra snapshot; owner isolation/cold cache', () async {
    final s = await Server21.open(script: script22);
    addTearDown(s.close);
    final m = await App21.open(s, projectEnabled: true),
        c = await App21.open(s, client: true, projectEnabled: true);
    try {
      await s.call('control.seed', {'version': 1});
      await recompute22(s, 'empty');
      await Future.wait(
        List.generate(6, (_) => m.c.project22!.refresh(m.c.cloudQueue)),
      );
      await m.drain();
      var counts = (await s.call('control.state', {}))['counts'];
      expect(counts['project.overview'], 1);
      expect(counts['ratings.snapshot'], 1);
      expect(m.c.project22!.overview!['sections'].length, 7);
      await m.c.project22!.refresh(m.c.cloudQueue);
      await m.drain();
      expect(
        (await s.call('control.state', {}))['counts']['ratings.snapshot'],
        1,
      );
      await c.c.project22!.refresh(c.c.cloudQueue);
      await c.drain();
      expect(c.c.project22!.admin, false);
      expect(c.c.project22!.overview, null);
      String? owner = m.c.transferOwner;
      final p = Project22Runtime(
        db: m.f.db,
        rpc: m.c.project22!.rpc,
        owner: () => owner,
        epoch: () => 0,
        scope: 'master:public',
      );
      await p.restore();
      expect(p.overview, isNotNull);
      owner = c.c.transferOwner;
      expect(p.overview, null);
      await p.restore();
      expect(p.overview, null);
      p.dispose();
    } finally {
      await m.close();
      await c.close();
    }
  });
  test('22 local-only review opt-in queue/receipt/lost response/revoke preserves real media and tables', () async {
    final s = await Server21.open(script: script22);
    addTearDown(s.close);
    final app = await App21.open(s, client: true, projectEnabled: true);
    try {
      await seed15(app.f);
      final tables = (await app.f.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT IN ('app_settings','sqlite_sequence')",
      )).map((v) => v['name'] as String).toList();
      Future<String> state() async =>
          jsonEncode({for (final t in tables) t: await app.f.db.query(t)});
      final before = await state();
      final hashes = {
        for (final f in app.f.c.library.directory.listSync().whereType<File>())
          f.path: digest22(await f.readAsBytes()),
      };
      await s.call('control.seed', {'version': 1});
      final store = app.c.feedback22!, run = run22('review');
      await store.save(run, 5, exactTarget: target22);
      expect((await store.load(run.id))!['localOnly'], true);
      expect(
        (await s.call('control.state', {}))['counts']['feedback.ingest'],
        null,
      );
      await store.consent(run.id, true);
      await app.drain();
      expect((await store.load(run.id))!['receipt']['shared'], true);
      await recompute22(s, 'one');
      await app.c.project22!.refresh(app.c.cloudQueue);
      await app.drain();
      expect(
        app.c.project22!.summaryFor(
          'module',
          'module-one',
        )!['consumerDirect']['mean'],
        5,
      );
      await store.save(run, 3);
      await s.call('control.mode', {'mode': 'lostFeedbackOnce'});
      final name = await store.consent(run.id, true);
      await app.c.cloudQueue.refresh();
      final row = app.c.cloudQueue.rows.singleWhere((r) => r['_name'] == name);
      await expectLater(
        store.execute(row, () => false),
        throwsA(isA<Exception>()),
      );
      await store.execute(row, () => false);
      expect((await store.load(run.id))!['serverSequence'], 2);
      await s.call('control.mode', {'mode': 'ready'});
      await store.consent(run.id, false);
      await app.drain(allowFailure: true);
      await recompute22(s, 'withdraw');
      await app.c.project22!.refresh(app.c.cloudQueue);
      await app.drain(allowFailure: true);
      expect(
        app.c.project22!.summaryFor(
          'module',
          'module-one',
        )!['consumerDirect']['n'],
        0,
      );
      await store.execute(row, () => false);
      expect((await store.load(run.id))!['serverSequence'], 3);
      expect((await store.load(run.id))!['localOnly'], true);
      expect(await state(), before);
      for (final h in hashes.entries) {
        expect(digest22(await File(h.key).readAsBytes()), h.value);
      }
    } finally {
      await app.close();
    }
  });
  test('22 corrupt/offline overlay keeps lastGood; explicit403 hides privileged cache without deletion', () async {
    final s = await Server21.open(script: script22);
    addTearDown(s.close);
    final app = await App21.open(s, projectEnabled: true);
    try {
      await s.call('control.seed', {'version': 1});
      await recompute22(s, 'empty');
      final r = app.c.project22!;
      await r.refresh(app.c.cloudQueue);
      await app.drain();
      final cache = await app.f.db.query('app_settings');
      expect(r.overview, isNotNull);
      await s.call('control.mode', {'mode': 'denied'});
      await expectLater(
        r.call('project.overview', {}),
        throwsA(isA<Exception>()),
      );
      expect(r.accessDenied, true);
      expect(r.overview, null);
      expect(await app.f.db.query('app_settings'), cache);
      await s.call('control.mode', {'mode': 'ready'});
      await r.call('project.overview', {});
      expect(r.overview, isNotNull);
      final good = jsonEncode(r.ratings);
      await s.call('control.mode', {'mode': 'offline'});
      await expectLater(
        r.execute({
          'ownerBinding': app.c.transferOwner,
          'download': {'scope': 'master:public'},
        }, () => false),
        throwsA(isA<Exception>()),
      );
      expect(jsonEncode(r.ratings), good);
      expect(r.stale, true);
    } finally {
      await app.close();
    }
  });
}
