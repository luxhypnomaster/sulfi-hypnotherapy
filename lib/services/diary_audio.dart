import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/diary_entry.dart';
import 'diary_media_store.dart';

abstract class DiaryAudioTransport {
  Stream<void> get changes;
  bool get playing;
  bool get completed;
  Duration get position;
  Duration? get duration;
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class NativeDiaryAudio implements DiaryAudioTransport {
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final _changes = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  NativeDiaryAudio() {
    _subs.add(_player.playerStateStream.listen((_) => _changes.add(null)));
    _subs.add(_player.positionStream.listen((_) => _changes.add(null)));
    _subs.add(_player.durationStream.listen((_) => _changes.add(null)));
    _subs.add(_player.errorStream.listen((e) => _changes.addError(e)));
  }
  @override
  bool get playing => _player.playing && !completed;
  @override
  bool get completed => _player.processingState == ProcessingState.completed;
  @override
  Duration get position => _player.position;
  @override
  Duration? get duration => _player.duration;
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<void> load(String path) async {
    await _player.setFilePath(path).timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration p) => _player.seek(p);
  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _changes.close();
  }
}

class DiaryAudio extends ChangeNotifier {
  DiaryAudio({
    required this.transport,
    required this.store,
    this.sessionActive,
    this.beforePlay,
  }) {
    _subscription = transport.changes.listen(
      (_) {
        if (!_closed) notifyListeners();
      },
      onError: (Object _) {
        error = 'Ошибка аудио. Нажмите для повтора.';
        unawaited(pause());
      },
    );
  }
  final DiaryAudioTransport transport;
  final DiaryMediaStore store;
  final bool Function()? sessionActive;
  final Future<void> Function()? beforePlay;
  late final StreamSubscription<void> _subscription;
  final Map<String, Duration> _positions = {};
  final Map<String, Duration> _durations = {};
  Duration positionFor(String id) =>
      current == id ? position : _positions[id] ?? Duration.zero;
  Duration? durationFor(String id) => current == id ? duration : _durations[id];
  String? current, error;
  bool loading = false, _closed = false;
  int _generation = 0;
  bool get playing => transport.playing;
  Duration get position => transport.position;
  Duration? get duration => transport.duration;
  Future<void> toggle(DiaryBlock block) async {
    if (_closed || loading) return;
    final generation = ++_generation;
    final retry = error != null;
    error = null;
    try {
      if (sessionActive?.call() ?? false) {
        await pause();
        throw const FormatException('Сначала завершите активную сессию');
      }
      if (current == block.id && playing) {
        await pause();
        return;
      }
      if (current != block.id || retry) {
        await pause(invalidate: false);
        final file = store.file(block.media);
        if (file == null || !await file.exists()) {
          throw const FormatException(
            'Аудио недоступно офлайн. Нажмите для повтора.',
          );
        }
        loading = true;
        notifyListeners();
        current = block.id;
        await transport.load(file.path);
        if (transport.duration != null) {
          _durations[block.id] = transport.duration!;
        }
        await transport.seek(_positions[block.id] ?? Duration.zero);
      }
      if (_closed || generation != _generation) return;
      await beforePlay?.call();
      if (_closed || generation != _generation) return;
      if (transport.completed) await transport.seek(Duration.zero);
      unawaited(
        transport.play().catchError((Object _) {
          if (!_closed) {
            error = 'Не удалось воспроизвести. Нажмите для повтора.';
            unawaited(pause());
          }
        }),
      );
    } catch (e) {
      error = e is FormatException
          ? e.message
          : 'Ошибка аудио. Нажмите для повтора.';
      current = null;
    } finally {
      if (!_closed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> pause({bool invalidate = true}) async {
    if (_closed) return;
    if (invalidate) _generation++;
    if (current != null) _positions[current!] = position;
    await transport.pause();
    if (!_closed) notifyListeners();
  }

  Future<void> seek(Duration p) async {
    if (_closed || duration == null) return;
    await transport.seek(
      Duration(
        milliseconds: p.inMilliseconds.clamp(0, duration!.inMilliseconds),
      ),
    );
  }

  Future<void> initializeFocus() async {
    final session = await AudioSession.instance;
    if (_closed) return;
    await session.configure(const AudioSessionConfiguration.speech());
    if (_closed) return;
    _focus.add(
      session.interruptionEventStream.listen((e) {
        if (e.begin) unawaited(pause());
      }),
    );
    _focus.add(
      session.becomingNoisyEventStream.listen((_) => unawaited(pause())),
    );
  }

  final List<StreamSubscription<dynamic>> _focus = [];
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    await _subscription.cancel();
    for (final s in _focus) {
      await s.cancel();
    }
    await transport.dispose();
    super.dispose();
  }
}
