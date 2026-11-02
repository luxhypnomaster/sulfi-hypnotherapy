import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

abstract interface class SessionTransport {
  Duration get position;
  bool get completed;
  Stream<String> get events;
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> close();
}

class JustAudioSessionTransport implements SessionTransport {
  final _player = AudioPlayer(handleInterruptions: false);
  final _events = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;
  @override
  Duration get position => _player.position;
  @override
  bool get completed => _player.processingState == ProcessingState.completed;
  @override
  Stream<String> get events => _events.stream;
  Future<void> _initialize() async {
    if (_initialized) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) _events.add('interruption');
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen(
        (_) => _events.add('interruption'),
      ),
    );
    _subscriptions.add(_player.errorStream.listen((_) => _events.add('error')));
    _initialized = true;
  }

  @override
  Future<void> load(String path) async {
    await _initialize();
    await _player.setFilePath(path).timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> play() async {
    unawaited(
      _player.play().catchError((Object _) {
        if (!_events.isClosed) _events.add('error');
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}
