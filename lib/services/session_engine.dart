import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_plan.dart';
import 'library_service.dart';
import 'session_controller.dart';
import 'session_transport.dart';

// Foreground execution only in this slice. Background/recording need a separate
// Android service implementation and device acceptance; never imply recovery.
class SessionEngine extends ChangeNotifier {
  SessionEngine({
    required this.controller,
    required this.transport,
    int Function()? nowMs,
  }) : _now = nowMs ?? _monotonic() {
    _events = transport.events.listen((event) {
      if (run?.active != true) return;
      if (event == 'interruption') unawaited(pause().catchError((Object _) {}));
      if (event == 'error') {
        unawaited(
          _enqueue(() => _finish(RunStatus.error, 'audio_error'))
              .catchError((Object _) {}),
        );
      }
    });
  }
  static int Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMilliseconds;
  }

  final SessionController controller;
  final SessionTransport transport;
  final int Function() _now;
  late final StreamSubscription<String> _events;
  SessionRun? run;
  String? error;
  Timer? _timer;
  Future<void> _tail = Future.value();
  bool _busy = false, _disposed = false, _exiting = false, _tickPending = false;
  int _generation = 0,
      _phaseStart = 0,
      _phaseBase = 0,
      _runStart = 0,
      _runBase = 0,
      _lastSave = 0;
  int _extendedMs = 0;
  SessionStep? get step {
    final r = run;
    if (r == null || r.stepIndex >= r.snapshot.plan.steps.length) return null;
    return r.snapshot.plan.steps[r.stepIndex];
  }

  bool get active => run?.active ?? false;
  bool get paused => run?.status == RunStatus.paused;
  bool get busy => _busy;
  int get elapsedMs =>
      _runBase + ((run?.status == RunStatus.running) ? _now() - _runStart : 0);
  int get phasePositionMs => run?.phase == 'audio'
      ? transport.position.inMilliseconds
      : _phaseBase +
            ((run?.status == RunStatus.running) ? _now() - _phaseStart : 0);
  int? get phaseDurationMs {
    final s = step;
    if (s == null) return null;
    if (run?.phase == 'delay') return s.delayBeforeSeconds * 1000;
    return s.durationMs == null ? null : s.durationMs! + _extendedMs;
  }

  int? get remainingMs => phaseDurationMs == null
      ? null
      : (phaseDurationMs! - phasePositionMs).clamp(0, 0x7fffffff);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> flush() => _tail;
  Future<void> _enqueue(Future<void> Function() action) {
    final result = _tail.then((_) async {
      if (_disposed) return;
      _busy = true;
      _notify();
      try {
        await action();
      } catch (_) {
        error = 'Сессия остановлена из-за ошибки аудио или сохранения. Вернитесь к спокойному дыханию и осмотритесь.';
        await transport.stop();
        if (active) {
          await _finish(RunStatus.error, 'execution_error');
        }
        rethrow;
      } finally {
        _busy = false;
        _notify();
      }
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> start() => _enqueue(() async {
    if (active) throw const LibraryException('Сессия уже запущена.');
    final snapshot = await controller.snapshotForStart();
    run = await controller.repository.startRun(snapshot);
    _generation++;
    _exiting = false;
    _runBase = 0;
    _runStart = _now();
    _lastSave = _now();
    await _beginStep(0);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => tick());
  });
  Future<void> _beginStep(int index) async {
    await transport.stop();
    final r = run!;
    if (index >= r.snapshot.plan.steps.length) {
      await _finish(
        _exiting ? RunStatus.interrupted : RunStatus.completed,
        _exiting ? 'exit_completed' : 'completed',
      );
      return;
    }
    _phaseBase = 0;
    _phaseStart = _now();
    _extendedMs = 0;
    run = r.checkpoint(
      stepIndex: index,
      phase: 'delay',
      playheadMs: 0,
      elapsedMs: elapsedMs,
    );
    await _persist('delay_started');
  }

  Future<void> _beginContent() async {
    final s = step!, generation = _generation;
    _phaseBase = 0;
    _phaseStart = _now();
    run = run!.checkpoint(
      phase: s.kind == StepKind.audio ? 'audio' : 'work',
      playheadMs: 0,
      elapsedMs: elapsedMs,
    );
    if (s.kind == StepKind.audio) {
      final a = controller.asset(s.audioAssetId);
      if (a == null || !await controller.library.fileFor(a).exists()) {
        throw const LibraryException('Аудиофайл недоступен.');
      }
      try {
        await transport.load(controller.library.fileFor(a).path);
      } catch (_) {
        if (generation != _generation) return;
        rethrow;
      }
      if (generation != _generation) return;
      await transport.play();
    } else if (s.kind == StepKind.voiceRecording) {
      throw const LibraryException('Запись микрофона ещё не поддерживается.');
    }
    await _persist('block_started');
  }

  Future<void> _persist([String? event]) async {
    if (run == null) return;
    run = run!.checkpoint(playheadMs: phasePositionMs, elapsedMs: elapsedMs);
    await controller.repository.checkpoint(run!, event: event);
    _lastSave = _now();
  }

  @visibleForTesting
  void tick() {
    if (!active || paused || _busy || _disposed || _tickPending) return;
    final ended = run!.phase == 'audio'
        ? transport.completed
        : phaseDurationMs != null && phasePositionMs >= phaseDurationMs!;
    if (ended) {
      final generation = _generation;
      _tickPending = true;
      unawaited(
        _enqueueTick(() async {
          if (!active || paused || generation != _generation) return;
          if (run!.phase == 'delay') {
            await _beginContent();
          } else {
            await _persist('block_completed');
            await _beginStep(
              _exiting ? run!.snapshot.plan.steps.length : run!.stepIndex + 1,
            );
          }
        }).catchError((Object _) {}),
      );
    } else if (_now() - _lastSave >= 5000) {
      _tickPending = true;
      unawaited(_enqueueTick(() => _persist()).catchError((Object _) {}));
    }
    _notify();
  }

  Future<void> _enqueueTick(Future<void> Function() f) => _enqueue(() async {
    try {
      await f();
    } finally {
      _tickPending = false;
    }
  });

  Future<void> pause() {
    _generation++;
    return _enqueue(() async {
      if (!active || paused) return;
      _phaseBase = phasePositionMs;
      _phaseStart = _now();
      _runBase = elapsedMs;
      _runStart = _now();
      if (run!.phase == 'audio') await transport.pause();
      run = run!.checkpoint(
        status: RunStatus.paused,
        playheadMs: _phaseBase,
        elapsedMs: _runBase,
      );
      await _persist('paused');
    });
  }

  Future<void> resume() => _enqueue(() async {
    if (!paused) return;
    _phaseStart = _now();
    _runStart = _now();
    run = run!.checkpoint(status: RunStatus.running);
    if (run!.phase == 'audio' && !transport.completed) await transport.play();
    await _persist('resumed');
  });
  Future<void> next() => _enqueue(() async {
    if (!active) return;
    await _persist('block_skipped');
    if (paused) {
      _phaseStart = _now();
      _runStart = _now();
      run = run!.checkpoint(status: RunStatus.running);
    }
    await _beginStep(
      _exiting ? run!.snapshot.plan.steps.length : run!.stepIndex + 1,
    );
  });
  Future<void> extend() => _enqueue(() async {
    if (!active || run!.phase != 'work' || step?.kind != StepKind.freeWork) {
      return;
    }
    if (step!.durationMs != null) _extendedMs += 300000;
    await _persist('extended_5min');
  });
  Future<void> exit() {
    if (_exiting) return interrupt();
    _exiting = true;
    _generation++;
    unawaited(transport.stop().catchError((Object _) {}));
    return _enqueue(() async {
      if (!active) return;
      await _persist('exit_requested');
      final plan = run!.snapshot.plan;
      final index = plan.steps.indexWhere(
        (s) => s.id == plan.exitStepId && s.kind == StepKind.audio,
      );
      if (index < 0) {
        await _finish(RunStatus.interrupted, 'exit_without_audio');
        return;
      }
      final a = controller.asset(plan.steps[index].audioAssetId);
      if (a == null || !await controller.library.fileFor(a).exists()) {
        error = 'Аудиовыход недоступен. Почувствуйте опору, осмотритесь и спокойно откройте глаза.';
        await _finish(RunStatus.interrupted, 'exit_file_missing');
        return;
      }
      if (paused) {
        _runStart = _now();
        run = run!.checkpoint(status: RunStatus.running);
      }
      await _beginStep(index);
      // An explicit safe exit starts immediately, without the planned pre-delay.
      await _beginContent();
    });
  }

  Future<void> interrupt() {
    _generation++;
    unawaited(transport.stop().catchError((Object _) {}));
    return _enqueue(() async {
      if (active) await _finish(RunStatus.interrupted, 'interrupted');
    });
  }

  Future<void> _finish(RunStatus status, String event) async {
    if (run == null || !run!.active) return;
    final elapsed = elapsedMs, position = phasePositionMs;
    _timer?.cancel();
    _timer = null;
    _runBase = elapsed;
    run = run!.checkpoint(
      status: status,
      elapsedMs: elapsed,
      playheadMs: position,
      endedAt: DateTime.now().toUtc(),
    );
    await transport.stop();
    await controller.repository.checkpoint(run!, event: event);
  }

  Future<void> close() async {
    if (_disposed) return;
    if (active) await interrupt();
    await flush();
    _disposed = true;
    _timer?.cancel();
    await _events.cancel();
    await transport.close();
    super.dispose();
  }
}
