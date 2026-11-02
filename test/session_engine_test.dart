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
import 'package:sulfi_hypnotherapy/services/session_transport.dart';

import 'support/fakes.dart';

class TestTransport implements SessionTransport {
  final controller = StreamController<String>.broadcast();
  int plays = 0, stops = 0, pauses = 0;
  final List<String> loaded = [];
  Completer<void>? pendingLoad;
  @override
  Duration position = Duration.zero;
  @override
  bool completed = false;
  @override
  Stream<String> get events => controller.stream;
  @override
  Future<void> load(String path) async {
    loaded.add(path);
    position = Duration.zero;
    completed = false;
    await pendingLoad?.future;
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (pendingLoad != null && !pendingLoad!.isCompleted) {
      pendingLoad!.completeError(StateError('load cancelled'));
    }
  }

  @override
  Future<void> close() => controller.close();
}

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
    expect(engine.run!.status, RunStatus.interrupted);
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
