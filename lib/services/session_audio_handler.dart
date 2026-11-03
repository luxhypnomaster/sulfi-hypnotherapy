import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'session_engine.dart';
import 'session_controller.dart';
import 'session_transport.dart';

SessionAudioHandler? sessionAudioHandler;

class SessionAudioHandler extends BaseAudioHandler with SeekHandler {
  SessionAudioHandler(this.controller);
  final SessionController controller;
  SessionEngine? engine;
  String _publishedKey = "";
  int _publishedAt = 0;
  bool _lastActive = false;
  StreamSubscription<dynamic>? _noisy, _focus;
  AudioSession? _session;
  Future<SessionEngine> startSession() async {
    if (engine?.active ?? false) return engine!;
    if (engine != null) {
      engine!.removeListener(_publish);
      await engine!.close();
    }
    engine = SessionEngine(
      controller: controller,
      transport: JustAudioSessionTransport(),
    );
    engine!.addListener(_publish);
    final session = await AudioSession.instance;
    _session = session;
    await session.configure(const AudioSessionConfiguration.speech());
    await _noisy?.cancel();
    await _focus?.cancel();
    _noisy = session.becomingNoisyEventStream.listen((_) {
      unawaited(pause());
    });
    _focus = session.interruptionEventStream.listen((e) {
      if (e.begin) unawaited(pause());
    });
    if (!await session.setActive(true)) {
      throw StateError('Не удалось получить аудиофокус');
    }
    await engine!.start();
    _publish();
    return engine!;
  }

  void _publish() {
    final e = engine;
    if (e == null || e.run == null) return;
    final key =
        '${e.run!.id}:${e.run!.stepIndex}:${e.run!.phase}:${e.run!.status.name}';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (key == _publishedKey && now - _publishedAt < 1000) return;
    final changed = key != _publishedKey;
    if (changed && e.active && !e.paused && e.run!.phase != 'audio') {
      unawaited(_holdFocus());
    }
    _publishedKey = key;
    _publishedAt = now;
    if (_lastActive && !e.active) {
      unawaited(
        AudioSession.instance
            .then((s) => s.setActive(false))
            .catchError((Object _) => false),
      );
    }
    _lastActive = e.active;
    final item = e.step;
    mediaItem.add(
      MediaItem(
        id: e.run!.id,
        title: item?.title ?? 'Сессия завершена',
        album: 'Сульфи — Самогипноз',
        artist: e.run!.snapshot.plan.groupName(item?.groupId),
        duration: e.phaseDurationMs == null
            ? null
            : Duration(milliseconds: e.phaseDurationMs!),
      ),
    );
    // Keep READY/playing during silence too: service + partial wake lock stay alive.
    playbackState.add(
      playbackState.value.copyWith(
        controls: e.active
            ? [
                e.paused ? MediaControl.play : MediaControl.pause,
                MediaControl.stop,
              ]
            : [],
        systemActions: {MediaAction.play, MediaAction.pause, MediaAction.stop},
        processingState: e.active
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        playing: e.active && !e.paused,
        updatePosition: Duration(milliseconds: e.phasePositionMs),
        bufferedPosition: Duration(milliseconds: e.phasePositionMs),
      ),
    );
  }

  Future<void> _holdFocus() async {
    try {
      if (_session != null &&
          !await _session!.setActive(true) &&
          engine!.active &&
          !engine!.paused) {
        await pause();
      }
    } catch (_) {
      if (engine?.active ?? false) await pause();
    }
  }

  @override
  Future<void> play() async {
    await engine?.resume();
    _publish();
  }

  @override
  Future<void> pause() async {
    await engine?.pause();
    _publish();
  }

  @override
  Future<void> stop() async {
    await engine?.interrupt();
    _publish();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    /* media service continues; force-stop is recovered from checkpoints */
  }
}
