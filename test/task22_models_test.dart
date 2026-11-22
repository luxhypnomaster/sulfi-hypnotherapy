import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/ratings22.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/course22_store.dart';
import 'package:sulfi_hypnotherapy/services/playback22_evidence.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_engine.dart';

import 'support/task15_fixture.dart';
import 'support/session_transport_fake.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '22 Node/Dart milli golden; null professional/weighted and N1 preliminary',
    () {
      final g = jsonDecode(
        File('test/fixtures/ratings22-golden.json').readAsStringSync(),
      );
      expect(
        digest22({'decimal': 3.125, 'integer': 5.0, 'none': null}),
        g['milliHash'],
      );
      verifyRatings22(g['head'], g['snapshot']);
      final s = g['snapshot']['items'][0];
      expect(directLabel22(s['consumerDirect']), '5,0 · N=1 · предварительно');
      expect(directLabel22(s['professionalDirect']), 'Нет оценок');
      expect(s['weighted']['value'], null);
      s['weighted']['value'] = 4.2;
      g['head']['ratingsSnapshotHash'] = digest22(g['snapshot']);
      expect(
        () => verifyRatings22(g['head'], g['snapshot']),
        throwsFormatException,
      );
    },
  );
  test('22 exact course cursor/binding survives cold store; skip/early exit no advance; deletion/forks protected', () async {
    final f = await Fixture15.open();
    try {
      final store = Course22Store(f.db, owner: () => null),
          definition = {
            'contentId': 'course',
            'revisionId': 'course1',
            'programs': [
              for (final id in ['A', 'B', 'C'])
                {'contentId': id, 'revisionId': 'r1', 'sha256': 'a' * 64},
            ],
          };
      await store.installDefinition(definition);
      var course = (await store.load('course'))!;
      final ready = <String, Map<String, dynamic>>{
        'A': {'entitled': true, 'verified': true, 'revisionId': 'r1'},
        'B': {
          'entitled': true,
          'verified': false,
          'downloading': true,
          'revisionId': 'r1',
        },
        'C': {'entitled': true, 'verified': true, 'revisionId': 'r1'},
      };
      expect(store.current(course, ready)!['contentId'], 'A');
      final run = SessionRun(
        id: 'runA',
        displayNumber: 1,
        name: 'A',
        startedAt: DateTime(2026),
        status: RunStatus.completed,
        snapshot: CurrentSessionDraft(
          baseTemplateId: 'A',
          updatedAt: DateTime(2026),
          plan: SessionPlan(steps: const []),
        ),
      );
      await expectLater(
        store.complete('course', 'A', run),
        throwsFormatException,
      );
      await store.bindExecution('course', 'A', run);
      await store.complete(
        'course',
        'A',
        run.checkpoint(status: RunStatus.completedEarlyWithExit),
      );
      expect((await store.load('course'))!['cursor'], 0);
      await store.complete('course', 'A', run);
      await store.complete('course', 'A', run);
      course = (await Course22Store(f.db, owner: () => null).load('course'))!;
      expect(course['cursor'], 1);
      expect(store.current(course, ready), null);
      expect(store.state(course, ready), Rubedo22.red);
      await store.markDeleted('B');
      expect(await store.mayAutoInstall('B', userCreated: false), false);
      expect(
        store.officialUpdatePlan(
          [
            {
              'contentId': 'A',
              'revisionId': 'r1',
              'origin': 'personal',
              'userCreated': true,
            },
          ],
          [
            {'contentId': 'A', 'revisionId': 'r2'},
          ],
        ),
        isEmpty,
      );
    } finally {
      await f.close();
    }
  });
  test('22 playback intervals merge repetition; seek/discontinuity and pause never invent exposure', () {
    final p = Playback22Evidence();
    p.sample('A', 0, 0, playing: true, durationMs: 1000);
    p.sample('A', 100, 100, playing: true, durationMs: 1000);
    p.discontinuity();
    p.sample('A', 800, 200, playing: true, durationMs: 1000);
    p.sample('A', 900, 300, playing: true, durationMs: 1000);
    p.sample('A', 1000, 400, playing: false, durationMs: 1000);
    expect(p.played('A'), 200);
    p.sample('A', 0, 500, playing: true, durationMs: 1000);
    p.sample('A', 100, 600, playing: true, durationMs: 1000);
    expect(p.played('A'), 200);
  });
  test('22 actual SessionEngine sampled playback checkpoint preserves SQLite/history; no seek listening inflation', () async {
    final f = await Fixture15.open();
    final c = SessionController(
          repository: f.c.repository,
          library: f.c.library,
          modules: f.c.modules,
          capsules: f.c.capsules,
          project22Enabled: true,
        ),
        transport = TestTransport();
    var now = 0;
    final engine = SessionEngine(
      controller: c,
      transport: transport,
      nowMs: () => now,
    );
    try {
      final asset = sampleAsset();
      await f.c.library.repository.save(asset);
      await f.c.library.fileFor(asset).writeAsBytes([0, 1, 2]);
      final plan = SessionPlan(
            steps: [
              SessionStep(
                id: 'audio',
                kind: StepKind.audio,
                title: 'Synthetic',
                audioAssetId: asset.id,
                durationMs: 10000,
              ),
            ],
          ),
          template = SessionTemplate(
            id: 'A',
            name: 'A',
            plan: plan,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );
      await c.reload();
      await c.loadTemplate(template);
      await engine.start();
      await engine.flush();
      transport.position = const Duration(milliseconds: 100);
      now = 100;
      engine.tick();
      await engine.flush();
      await engine.seek(const Duration(milliseconds: 8000));
      now = 200;
      transport.position = const Duration(milliseconds: 8100);
      engine.tick();
      await engine.flush();
      await engine.pause();
      final rows = await f.db.query(
        'app_settings',
        where: 'name=?',
        whereArgs: ['playback22:${engine.run!.id}'],
      );
      expect(rows, isNotEmpty);
      final data = jsonDecode(rows.single['value'] as String);
      expect(data['manifestHash'], digest22(engine.run!.snapshot.plan.toMap()));
      final played = (data['intervals']['audio'] as List? ?? []).fold<int>(
        0,
        (a, r) => a + (r[1] as int) - (r[0] as int),
      );
      expect(played, lessThanOrEqualTo(200));
      expect((await c.repository.history()).length, 1);
    } finally {
      await engine.close();
      c.dispose();
      await f.close();
    }
  });
}
