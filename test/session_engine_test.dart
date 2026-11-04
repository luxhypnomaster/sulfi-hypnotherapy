import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/session_engine.dart';

import 'support/session_transport_fake.dart';

import 'package:sulfi_hypnotherapy/models/session_timeline.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_audio_handler.dart';
import 'package:audio_service/audio_service.dart';

import 'support/fakes.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late SqliteLibraryRepository audio;
  late SqliteSessionRepository repository;
  late SessionController c;
  late SessionEngine engine;
  late TestTransport transport;
  var now = 0;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sulfi_engine_');
    audio = await SqliteLibraryRepository.open(
      p.join(root.path, 'db.sqlite'),
      factory: databaseFactoryFfi,
    );
    repository = SqliteSessionRepository(audio.database);
    final library = LibraryService(
      repository: audio,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => null,
      probe: (_) async => null,
    );
    await library.initialize();
    await audio.save(sampleAsset());
    await library.fileFor(sampleAsset()).writeAsBytes([0]);
    c = SessionController(repository: repository, library: library);
    await c.initialize();
    transport = TestTransport();
    now = 0;
    engine = SessionEngine(
      controller: c,
      transport: transport,
      nowMs: () => now,
    );
  });
  tearDown(() async {
    await engine.close();
    c.dispose();
    await audio.database.close();
    await root.delete(recursive: true);
  });
  Future<void> tick() async {
    engine.tick();
    await engine.flush();
  }

  test('v42 P05: legacy indefinite Silence can complete manually without changing snapshot', () async {
    final phase = await c.createPhase('work');
    await c.addLoose(
      phase,
      const SessionStep(
        id: 'legacy',
        kind: StepKind.silence,
        title: 'Старая тишина',
        durationMs: null,
      ),
    );
    await engine.start();
    await tick();
    final fingerprint = engine.run!.snapshot.plan.fingerprint;
    now = 50000;
    await tick();
    expect(engine.canFinishPause, true);
    expect(engine.forecast.totalMs, isNull);
    await engine.finishWork();
    expect(engine.run!.status, RunStatus.completed);
    expect(engine.run!.completedStepIds, hasLength(1));
    expect(engine.run!.skippedStepIds, isEmpty);
    expect(engine.run!.snapshot.plan.fingerprint, fingerprint);
  });
  test('v41 forecast includes pre-delay, silence, work and audio without double counting', () async {
    final phase = await c.createPhase('work');
    await c.addLoose(
      phase,
      const SessionStep(
        id: 's',
        kind: StepKind.silence,
        title: 'Тишина',
        durationMs: 10000,
        delayBeforeSeconds: 30,
      ),
    );
    await c.addLoose(
      phase,
      const SessionStep(
        id: 'w',
        kind: StepKind.freeWork,
        title: 'Работа',
        durationMs: 20000,
      ),
    );
    await c.addLoose(
      phase,
      SessionStep(
        id: 'a',
        kind: StepKind.audio,
        title: 'Аудио',
        audioAssetId: sampleAsset().id,
        durationMs: 65000,
      ),
    );
    await engine.start();
    expect(engine.forecast.remainingMs, 125000);
    expect(engine.forecast.liquidFraction, 1);
    now = 15000;
    expect(engine.forecast.remainingMs, 110000);
    expect(engine.forecast.totalMs, 125000);
    await engine.pause();
    now = 75000;
    expect(engine.forecast.elapsedMs, 15000);
    expect(engine.forecast.remainingMs, 110000);
  });
  test('v41 liquid is inverse progress at 25 and 75 percent', () async {
    await c.addBlock(StepKind.silence, 100000);
    await engine.start();
    await tick();
    now = 25000;
    expect(engine.forecast.progress, .25);
    expect(engine.forecast.liquidFraction, .75);
    now = 75000;
    expect(engine.forecast.progress, .75);
    expect(engine.forecast.liquidFraction, .25);
    now = 100000;
    await tick();
    expect(engine.forecast.liquidFraction, 0);
    expect(engine.run!.status, RunStatus.completed);
  });
  test(
    'v41 audio seek is bounded, journaled and preserves paused media controls',
    () async {
      await c.addAudio(sampleAsset());
      await engine.start();
      await tick();
      now = 10000;
      transport.position = const Duration(seconds: 10);
      await engine.pause();
      final plays = transport.plays;
      await engine.seek(const Duration(hours: 1));
      expect(transport.position.inMilliseconds, 65000);
      expect(engine.paused, isTrue);
      expect(transport.plays, plays);
      await engine.seek(const Duration(seconds: -1));
      expect(engine.forecast.remainingMs, 65000);
      final handler = SessionAudioHandler(c)..engine = engine;
      await handler.seek(const Duration(seconds: 30));
      expect(handler.playbackState.value.updatePosition.inSeconds, 30);
      expect(engine.forecast.remainingMs, 35000);
      expect(engine.elapsedMs, 10000);
      expect(
        (await repository.events(engine.run!.id))
            .where((x) => x['eventType'] == 'seek'),
        hasLength(3),
      );
    },
  );
  test('v41 repeated modules, direct interval, phase boundaries and double navigation preserve paused', () async {
    final phase = await c.createPhase('work');
    final m = ModuleDefinition(
      id: 'source',
      title: 'Модуль',
      items: [
        for (var i = 0; i < 2; i++)
          SessionStep(
            id: 'r$i',
            kind: StepKind.audio,
            title: 'A$i',
            audioAssetId: sampleAsset().id,
            durationMs: 65000,
          ),
      ],
    );
    await c.addModule(phase, m);
    await c.addLoose(
      phase,
      const SessionStep(
        id: 'gap',
        kind: StepKind.silence,
        title: 'Тишина',
        durationMs: 4000,
      ),
    );
    await c.addModule(phase, m);
    final disabled = await c.createPhase('integration');
    await c.addModule(disabled, m);
    await c.changePhases(
      (ps) => ps
          .map((p) => p.id == disabled ? p.copyWith(enabled: false) : p)
          .toList(),
    );
    final exit = await c.createPhase('exit');
    await c.addModule(exit, m);
    await engine.start();
    await tick();
    await engine.pause();
    final frozen = engine.run!.snapshot.plan.fingerprint,
        id = engine.run!.id,
        plays = transport.plays;
    expect(engine.navigationTarget(NavigationUnit.module, true), 3);
    await Future.wait([
      engine.navigate(NavigationUnit.module, true),
      engine.navigate(NavigationUnit.module, true),
    ]);
    expect(engine.run!.stepIndex, 3);
    expect(engine.paused, isTrue);
    expect(transport.plays, plays);
    expect(engine.run!.skippedStepIds, hasLength(3));
    expect(engine.run!.snapshot.plan.fingerprint, frozen);
    expect(engine.run!.id, id);
    expect(await repository.history(), hasLength(1));
    await engine.navigate(NavigationUnit.phase, true);
    expect(engine.run!.stepIndex, 5);
    expect(engine.navigationTarget(NavigationUnit.phase, true), isNull);
    await engine.navigate(NavigationUnit.phase, false);
    expect(engine.run!.stepIndex, 0);
    expect(engine.run!.skippedStepIds, isEmpty);
    expect(
      (await repository.events(id))
          .any((x) => x['eventType'] == 'navigation_next_module'),
      isTrue,
    );
  });
  test('v41 completed occurrences persist, then clear for replay rather than using list index', () async {
    final phase = await c.createPhase('work');
    for (var i = 0; i < 3; i++) {
      await c.addModule(
        phase,
        ModuleDefinition(
          id: 'm$i',
          title: 'M$i',
          items: [
            SessionStep(
              id: 'r$i',
              kind: StepKind.silence,
              title: 'S$i',
              durationMs: 1000,
            ),
          ],
        ),
      );
    }
    await engine.start();
    await tick();
    now = 1000;
    await tick();
    await tick();
    now = 2000;
    await tick();
    expect((await repository.history()).single.completedStepIds, hasLength(2));
    await engine.navigate(NavigationUnit.module, false);
    expect(engine.run!.stepIndex, 1);
    expect(engine.run!.completedStepIds, [
      engine.run!.snapshot.plan.steps[0].id,
    ]);
    expect((await repository.history()).single.completedStepIds, hasLength(1));
    expect(engine.run!.snapshot.plan.steps, hasLength(3));
  });
  test(
    'v41 legacy next preserves paused silence and seek is unavailable',
    () async {
      await c.addBlock(StepKind.silence, 10000);
      await c.addBlock(StepKind.silence, 10000);
      await engine.start();
      await tick();
      now = 100;
      await engine.pause();
      await engine.next();
      now = 10000;
      expect(engine.paused, isTrue);
      expect(engine.elapsedMs, 100);
      expect(engine.canSeek, isFalse);
      await engine.seek(const Duration(seconds: 4));
      expect(engine.run!.stepIndex, 1);
      expect(transport.position, Duration.zero);
    },
  );
  test('v41 unknown work stays unknown and extension updates only effective forecast', () async {
    await c.addBlock(StepKind.freeWork, 30000);
    await engine.start();
    await tick();
    now = 10000;
    final fingerprint = engine.run!.snapshot.plan.fingerprint;
    await engine.extend();
    expect(engine.forecast.remainingMs, 320000);
    expect(engine.forecast.totalMs, 330000);
    expect(engine.run!.snapshot.plan.fingerprint, fingerprint);
    await engine.interrupt();
    await c.clearPlan();
    await c.addBlock(StepKind.freeWork, null);
    await engine.start();
    await tick();
    expect(engine.forecast.remainingMs, isNull);
    expect(engine.forecast.progress, isNull);
    expect(engine.forecast.liquidFraction, isNull);
    await engine.extend();
    expect(
      (await repository.events(engine.run!.id))
          .where((x) => x['eventType'] == 'extended_5min'),
      isEmpty,
    );
  });
  test('v41 backward navigation increases remaining forecast without changing actual elapsed', () async {
    for (var i = 0; i < 3; i++) {
      await c.addAudio(sampleAsset());
    }
    await engine.start();
    await tick();
    now = 10000;
    transport.position = const Duration(seconds: 10);
    await engine.navigate(NavigationUnit.track, true);
    final before = engine.forecast.liquidFraction!;
    await engine.navigate(NavigationUnit.track, false);
    expect(engine.forecast.liquidFraction!, greaterThan(before));
    expect(engine.elapsedMs, 10000);
    expect(engine.run!.stepIndex, 0);
  });
  test('v41 repeated exit commands are idempotent', () async {
    final work = await c.createPhase('work'),
        exit = await c.createPhase('exit');
    final a = SessionStep(
      id: 'a',
      kind: StepKind.audio,
      title: 'A',
      audioAssetId: sampleAsset().id,
      durationMs: 65000,
    );
    await c.addLoose(work, a);
    await c.addLoose(exit, a);
    await engine.start();
    await tick();
    expect(await engine.hasAvailableExit(), isTrue);
    await Future.wait([engine.exit(), engine.exit()]);
    expect(engine.run!.status, RunStatus.exitingEarly);
  });
  test('v41 zero-duration completion has valid full progress and immutable execution IDs', () async {
    await c.addBlock(StepKind.silence, 0);
    await engine.start();
    await tick();
    await tick();
    expect(engine.run!.status, RunStatus.completed);
    expect(engine.forecast.totalMs, 0);
    expect(engine.forecast.progress, 1);
    expect(engine.forecast.liquidFraction, 0);
    expect(
      () => engine.run!.completedStepIds.add('invalid'),
      throwsUnsupportedError,
    );
    final old = engine.run!.toMap()..remove('completedStepIds');
    expect(SessionRun.fromMap(old).completedStepIds, isEmpty);
  });
  test(
    'early exit plays the entire subsequent exit phase and stores skipped IDs',
    () async {
      final work = await c.createPhase('work');
      final exit = await c.createPhase('exit');
      final later = await c.createPhase('integration');
      final recipe = SessionStep(
        id: 'r',
        kind: StepKind.audio,
        title: 'A',
        audioAssetId: sampleAsset().id,
        durationMs: 65000,
      );
      await c.addLoose(work, recipe);
      await c.addLoose(exit, recipe);
      await c.addLoose(exit, recipe);
      await c.addLoose(later, recipe);
      await engine.start();
      await tick();
      await engine.exit();
      expect(engine.run!.status, RunStatus.exitingEarly);
      expect(engine.run!.stepIndex, 1);
      transport.completed = true;
      await tick();
      expect(engine.run!.stepIndex, 2);
      expect(engine.active, isTrue);
      await tick();
      transport.completed = true;
      await tick();
      expect(engine.run!.status, RunStatus.completedEarlyWithExit);
      final stored = (await repository.history()).single;
      expect(stored.skippedStepIds, hasLength(2));
      expect(stored.snapshot.plan.allSteps, hasLength(4));
    },
  );
  test(
    'early exit retains leading silence in the selected Exit phase',
    () async {
      final work = await c.createPhase('work');
      final exit = await c.createPhase('exit');
      final audio = SessionStep(
        id: 'a',
        kind: StepKind.audio,
        title: 'Аудио',
        audioAssetId: sampleAsset().id,
        durationMs: 65000,
      );
      await c.addLoose(work, audio);
      await c.addLoose(
        exit,
        SessionStep(
          id: 'silence',
          kind: StepKind.silence,
          title: 'Подготовка к выходу',
          durationMs: 5000,
        ),
      );
      await c.addLoose(exit, audio);
      await engine.start();
      await tick();
      await engine.exit();
      expect(engine.run!.stepIndex, 1);
      expect(engine.run!.phase, 'work');
      now += 5000;
      await tick();
      expect(engine.run!.stepIndex, 2);
      await tick();
      transport.completed = true;
      await tick();
      expect(engine.run!.status, RunStatus.completedEarlyWithExit);
      expect(engine.run!.skippedStepIds, hasLength(1));
    },
  );
  test(
    'media panel pause and play control silence without starting another run',
    () async {
      await c.addBlock(StepKind.silence, 120000);
      await engine.start();
      await tick();
      now = 10000;
      await tick();
      final handler = SessionAudioHandler(c)..engine = engine;
      await handler.pause();
      expect(engine.paused, isTrue);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.ready,
      );
      expect(handler.playbackState.value.playing, isFalse);
      now = 70000;
      expect(engine.phasePositionMs, 10000);
      await handler.play();
      expect(engine.active, isTrue);
      expect(handler.playbackState.value.playing, isTrue);
      now = 71000;
      expect(engine.phasePositionMs, 11000);
      expect(await repository.history(), hasLength(1));
    },
  );
  test('first pre-delay runs before any audio and session numbering starts only on explicit start', () async {
    await c.addAudio(sampleAsset());
    await c.setDelay(c.draft.plan.steps.single.id, 5);
    expect(await repository.history(), isEmpty);
    await engine.start();
    expect((await repository.history()).single.displayNumber, 1);
    expect(transport.plays, 0);
    now = 4999;
    await tick();
    expect(transport.plays, 0);
    now = 5000;
    await tick();
    expect(transport.plays, 1);
    expect(engine.run!.phase, 'audio');
  });
  test('repeated ticks cannot skip or duplicate a block', () async {
    await c.addAudio(sampleAsset());
    await engine.start();
    engine.tick();
    engine.tick();
    await engine.flush();
    expect(transport.plays, 1);
    expect(engine.active, isTrue);
    expect(engine.run!.stepIndex, 0);
  });
  test('pausing a pre-delay freezes remaining and elapsed time', () async {
    await c.addAudio(sampleAsset());
    await c.setDelay(c.draft.plan.steps.single.id, 10);
    await engine.start();
    now = 4000;
    await engine.pause();
    expect(engine.remainingMs, 6000);
    now = 104000;
    await tick();
    expect(engine.remainingMs, 6000);
    expect(engine.elapsedMs, 4000);
    await engine.resume();
    now = 109999;
    await tick();
    expect(transport.plays, 0);
    now = 110000;
    await tick();
    expect(transport.plays, 1);
    expect(engine.elapsedMs, 10000);
  });
  test(
    'audio pause and resume preserve playhead and do not reload the file',
    () async {
      await c.addAudio(sampleAsset());
      await engine.start();
      await tick();
      transport.position = const Duration(seconds: 12);
      now = 12000;
      await engine.pause();
      expect(engine.run!.playheadMs, 12000);
      expect(transport.pauses, 1);
      now = 25000;
      await engine.resume();
      expect(transport.loaded, hasLength(1));
      expect(transport.plays, 2);
    },
  );
  test(
    'audio completion advances once into timed silence and ends truthfully',
    () async {
      await c.addAudio(sampleAsset());
      await c.addBlock(StepKind.silence, 2000);
      await engine.start();
      await tick();
      transport.position = const Duration(seconds: 65);
      transport.completed = true;
      now = 65000;
      await tick();
      expect(engine.run!.stepIndex, 1);
      expect(engine.run!.phase, 'delay');
      await tick();
      expect(engine.run!.phase, 'work');
      now = 66999;
      await tick();
      expect(engine.active, isTrue);
      now = 67000;
      await tick();
      expect(engine.run!.status, RunStatus.completed);
      final stored = (await repository.history()).single;
      expect(stored.elapsedMs, 67000);
      expect(stored.status, RunStatus.completed);
    },
  );
  test(
    'free work can be extended without changing frozen plan or source draft',
    () async {
      await c.addBlock(StepKind.freeWork, 60000);
      await engine.start();
      await tick();
      now = 10000;
      await engine.extend();
      expect(engine.remainingMs, 350000);
      expect(engine.run!.snapshot.plan.steps.single.durationMs, 60000);
      expect(c.draft.plan.steps.single.durationMs, 60000);
      expect(
        (await repository.events(engine.run!.id)).last['eventType'],
        'extended_5min',
      );
    },
  );
  test(
    'user-controlled work has estimated duration and can end early',
    () async {
      await c.addBlock(StepKind.freeWork, null);
      await engine.start();
      await tick();
      now = 500000;
      await tick();
      expect(engine.remainingMs, isNull);
      expect(engine.active, isTrue);
      await engine.next();
      expect(engine.run!.status, RunStatus.completed);
      expect(
        (await repository.events(engine.run!.id))
            .any((e) => e['eventType'] == 'work_completed_early'),
        isTrue,
      );
    },
  );
  test('explicit exit skips its pre-delay, plays exit once and records early finish', () async {
    await c.addBlock(StepKind.silence, 60000);
    await c.addAudio(sampleAsset());
    final exit = c.draft.plan.steps.last;
    await c.setDelay(exit.id, 390);
    await c.setExit(exit.id);
    await engine.start();
    await engine.exit();
    expect(engine.run!.stepIndex, 1);
    expect(engine.run!.phase, 'audio');
    expect(transport.plays, 1);
    transport.completed = true;
    await tick();
    expect(engine.run!.status, RunStatus.completedEarlyWithExit);
    final events = await repository.events(engine.run!.id);
    expect(events.any((e) => e['eventType'] == 'exit_requested'), isTrue);
    expect(events.last['eventType'], 'exit_completed');
  });
  test(
    'exit without an exit file stops without pretending an audio track played',
    () async {
      await c.addBlock(StepKind.silence, 60000);
      await engine.start();
      await engine.exit();
      expect(engine.run!.status, RunStatus.interrupted);
      expect(transport.plays, 0);
      expect(
        (await repository.events(engine.run!.id)).last['eventType'],
        'exit_without_audio',
      );
    },
  );
  test('interruption stores exact current phase and playhead', () async {
    await c.addAudio(sampleAsset());
    await engine.start();
    await tick();
    now = 15300;
    transport.position = const Duration(milliseconds: 15000);
    await engine.interrupt();
    final run = (await repository.history()).single;
    expect(run.status, RunStatus.interrupted);
    expect(run.phase, 'audio');
    expect(run.playheadMs, 15000);
    expect(run.elapsedMs, 15300);
  });
  test('missing audio aborts start without creating history', () async {
    await c.addAudio(sampleAsset());
    await c.library.fileFor(sampleAsset()).delete();
    await expectLater(engine.start(), throwsA(isA<LibraryException>()));
    expect(await repository.history(), isEmpty);
    expect(transport.plays, 0);
  });

  test('interrupt cancels an in-flight load without playing or reporting a false audio failure', () async {
    await c.addAudio(sampleAsset());
    await engine.start();
    transport.pendingLoad = Completer<void>();
    engine.tick();
    while (transport.loaded.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await engine.interrupt();
    expect(engine.run!.status, RunStatus.interrupted);
    expect(transport.plays, 0);
    expect(engine.error, isNull);
  });
}
