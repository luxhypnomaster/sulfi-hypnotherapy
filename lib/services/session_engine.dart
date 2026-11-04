import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_plan.dart';
import '../models/session_timeline.dart';
import 'library_service.dart';
import 'session_controller.dart';
import 'session_transport.dart';

// Execution state is independent of widgets; Android media service owns this engine.
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
  int _extendedMs = 0, _exitEndIndex = -1;
  bool _navigationPending = false;
  SessionTimeline get timeline => SessionTimeline(run!.snapshot.plan);
  TimelineEntry? get currentEntry =>
      run == null ? null : timeline.entries.elementAtOrNull(run!.stepIndex);
  int? navigationTarget(NavigationUnit unit, bool forward) =>
      !active ? null : timeline.target(run!.stepIndex, unit, forward);
  bool get canSeek =>
      active && run?.phase == 'audio' && (step?.durationMs ?? 0) > 0;
  Future<bool> hasAvailableExit() async {
    if (!active) return false;
    final plan = run!.snapshot.plan;
    final entries = timeline.entries;
    for (var i = run!.stepIndex + 1; i < entries.length; i++) {
      final e = entries[i];
      if (e.step.kind == StepKind.audio &&
          (e.phase.typeId == 'exit' || e.step.id == plan.exitStepId)) {
        final asset = controller.asset(e.step.audioAssetId);
        if (asset != null && await controller.library.fileFor(asset).exists()) {
          return true;
        }
      }
    }
    return false;
  }

  SessionForecast get forecast {
    final r = run;
    if (r == null) return const SessionForecast(0, null);
    final elapsed = active ? elapsedMs : r.elapsedMs;
    if (r.status == RunStatus.completed ||
        r.status == RunStatus.completedEarlyWithExit) {
      return SessionForecast(elapsed, 0, finished: true);
    }
    final steps = r.snapshot.plan.steps;
    final last = _exiting && _exitEndIndex >= 0
        ? _exitEndIndex
        : steps.length - 1;
    var left = 0;
    for (var i = r.stepIndex; i <= last && i < steps.length; i++) {
      final s = steps[i];
      final duration = s.durationMs;
      if (duration == null) return SessionForecast(elapsed, null);
      if (i == r.stepIndex) {
        if (r.phase == 'delay') {
          left +=
              (s.delayBeforeSeconds * 1000 - phasePositionMs).clamp(
                0,
                0x7fffffff,
              ) +
              duration;
        } else {
          left += (duration + _extendedMs - phasePositionMs).clamp(
            0,
            0x7fffffff,
          );
        }
      } else {
        left += duration + s.delayBeforeSeconds * 1000;
      }
    }
    return SessionForecast(elapsed, left);
  }

  bool get _running =>
      run?.status == RunStatus.running || run?.status == RunStatus.exitingEarly;
  SessionStep? get step {
    final r = run;
    if (r == null || r.stepIndex >= r.snapshot.plan.steps.length) return null;
    return r.snapshot.plan.steps[r.stepIndex];
  }

  bool get exiting => _exiting;
  bool get active => run?.active ?? false;
  bool get paused => run?.status == RunStatus.paused;
  bool get busy => _busy || _navigationPending;
  int get elapsedMs => _runBase + ((_running) ? _now() - _runStart : 0);
  int get phasePositionMs => run != null && !active
      ? run!.playheadMs
      : run?.phase == 'audio'
      ? transport.position.inMilliseconds
      : _phaseBase + ((_running) ? _now() - _phaseStart : 0);
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
        _exiting ? RunStatus.completedEarlyWithExit : RunStatus.completed,
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

  Future<void> _beginContent({bool autoplay = true}) async {
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
        if (!autoplay) await transport.pause();
        await transport.load(controller.library.fileFor(a).path);
      } catch (_) {
        if (generation != _generation) return;
        rethrow;
      }
      if (generation != _generation) return;
      if (autoplay) await transport.play();
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

  void _markComplete() {
    if (step == null) return;
    run = run!.checkpoint(
      completedStepIds: {...run!.completedStepIds, step!.id}.toList(),
      skippedStepIds: run!.skippedStepIds
          .where((id) => id != step!.id)
          .toList(),
    );
  }

  @visibleForTesting
  void tick() {
    if (!active || paused || _busy || _disposed || _tickPending) return;
    final ended = run!.phase == 'audio'
        ? transport.completed ||
              (phaseDurationMs != null && phasePositionMs >= phaseDurationMs!)
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
            _markComplete();
            await _persist('block_completed');
            await _beginStep(
              _exiting && run!.stepIndex >= _exitEndIndex
                  ? run!.snapshot.plan.steps.length
                  : run!.stepIndex + 1,
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
    run = run!.checkpoint(
      status: _exiting ? RunStatus.exitingEarly : RunStatus.running,
    );
    if (run!.phase == 'audio' && !transport.completed) await transport.play();
    await _persist('resumed');
  });
  Future<void> next() => _enqueue(() async {
    if (!active) return;
    if (run!.phase == 'work' && step?.kind == StepKind.freeWork) {
      _markComplete();
    } else if (step != null) {
      run = run!.checkpoint(
        skippedStepIds: {...run!.skippedStepIds, step!.id}.toList(),
      );
    }
    await _persist(
      run!.phase == 'work' && step?.kind == StepKind.freeWork
          ? 'work_completed_early'
          : 'block_skipped',
    );
    await _beginStep(
      _exiting && run!.stepIndex >= _exitEndIndex
          ? run!.snapshot.plan.steps.length
          : run!.stepIndex + 1,
    );
  });

  /// Audio targets skip intervening intervals explicitly in the journal.
  /// Module/phase targets are first enabled occurrences, including their pre-delay.
  Future<void> navigate(NavigationUnit unit, bool forward) {
    if (!active || busy || _navigationPending) return Future.value();
    final target = navigationTarget(unit, forward);
    if (target == null) return Future.value();
    _navigationPending = true;
    _generation++;
    unawaited(transport.stop().catchError((Object _) {}));
    return _enqueue(() async {
      if (!active) return;
      final source = run!.stepIndex, wasPaused = paused;
      final event = 'navigation_${forward ? 'next' : 'previous'}_${unit.name}';
      await _persist('${event}_from');
      final steps = run!.snapshot.plan.steps;
      var done = {...run!.completedStepIds};
      var skipped = {...run!.skippedStepIds};
      if (target < source) {
        final replay = steps.skip(target).map((s) => s.id).toSet();
        done.removeAll(replay);
        skipped.removeAll(replay);
      } else {
        skipped.addAll(steps.sublist(source, target).map((s) => s.id));
      }
      if (_exiting) await _persist('exit_cancelled_by_navigation');
      _exiting = false;
      _exitEndIndex = -1;
      run = run!.checkpoint(
        completedStepIds: done.toList(),
        skippedStepIds: skipped.toList(),
        status: wasPaused ? RunStatus.paused : RunStatus.running,
      );
      await _beginStep(target);
      if (step!.delayBeforeSeconds == 0) {
        await _beginContent(autoplay: !wasPaused);
      }
      await _persist(event);
    }).whenComplete(() {
      _navigationPending = false;
      _notify();
    });
  }

  Future<void> seek(Duration value) {
    if (!canSeek || busy || _navigationPending) return Future.value();
    _generation++;
    return _enqueue(() async {
      if (!canSeek) return;
      await _persist('seek_from');
      final target = value.inMilliseconds.clamp(0, step!.durationMs!);
      await transport.seek(Duration(milliseconds: target));
      await _persist('seek');
    });
  }

  Future<void> extend() => _enqueue(() async {
    if (!active ||
        run!.phase != 'work' ||
        step?.kind != StepKind.freeWork ||
        step?.durationMs == null) {
      return;
    }
    _extendedMs += 300000;
    await _persist('extended_5min');
  });
  Future<void> finishWork() {
    if (!active ||
        busy ||
        run!.phase != 'work' ||
        step?.kind != StepKind.freeWork) {
      return Future.value();
    }
    return next();
  }

  Future<void> exit() {
    if (!active || _exiting) return Future.value();
    _exiting = true;
    _generation++;
    unawaited(transport.stop().catchError((Object _) {}));
    return _enqueue(() async {
      if (!active) return;
      await _persist('exit_requested');
      final plan = run!.snapshot.plan;
      var index = -1;
      if (plan.phases != null) {
        final exitPhases = plan.phases!
            .where((p) => p.enabled && p.typeId == 'exit')
            .map((p) => p.id)
            .toSet();
        for (var i = run!.stepIndex + 1; i < plan.steps.length; i++) {
          if (exitPhases.contains(plan.steps[i].groupId) &&
              plan.steps[i].kind == StepKind.audio) {
            index = i;
            // Keep leading intervals in the selected Exit phase too.
            while (index > run!.stepIndex + 1 &&
                plan.steps[index - 1].groupId == plan.steps[i].groupId) {
              index--;
            }
            break;
          }
        }
      } else {
        index = plan.steps.indexWhere(
          (s) => s.id == plan.exitStepId && s.kind == StepKind.audio,
        );
        if (index <= run!.stepIndex) index = -1;
      }
      final phaseExitFound = index >= 0;
      if (index < 0 && plan.exitStepId != null) {
        index = plan.steps.indexWhere(
          (s) => s.id == plan.exitStepId && s.kind == StepKind.audio,
        );
        if (index <= run!.stepIndex) index = -1;
      }
      _exitEndIndex = index;
      if (index >= 0 && phaseExitFound && plan.phases != null) {
        while (_exitEndIndex + 1 < plan.steps.length &&
            plan.steps[_exitEndIndex + 1].groupId ==
                plan.steps[index].groupId) {
          _exitEndIndex++;
        }
      }
      if (index >= 0) {
        final skipped = [
          ...run!.skippedStepIds,
          for (var i = run!.stepIndex; i < plan.steps.length; i++)
            if (i < index || i > _exitEndIndex) plan.steps[i].id,
        ];
        run = run!.checkpoint(skippedStepIds: skipped);
        await _persist('items_skipped_for_exit');
      }
      if (index < 0) {
        await _finish(RunStatus.interrupted, 'exit_without_audio');
        return;
      }
      final a = controller.asset(plan.steps[index].audioAssetId);
      if (plan.steps[index].kind == StepKind.audio &&
          (a == null || !await controller.library.fileFor(a).exists())) {
        error = 'Аудиовыход недоступен. Почувствуйте опору, осмотритесь и спокойно откройте глаза.';
        await _finish(RunStatus.interrupted, 'exit_file_missing');
        return;
      }
      if (paused) {
        _runStart = _now();
        run = run!.checkpoint(
          status: _exiting ? RunStatus.exitingEarly : RunStatus.running,
        );
      }
      run = run!.checkpoint(status: RunStatus.exitingEarly);
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
