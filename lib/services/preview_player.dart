import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_asset.dart';
import 'library_service.dart';

abstract class PreviewPlayer extends ChangeNotifier {
  AudioAsset? get current;
  File? get currentFile => null;
  bool Function()? sessionActive;
  bool get playing;
  Duration get position;
  String? get error;
  Future<void> toggle(AudioAsset asset, File file);
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> close();
}

class LocalPreviewPlayer extends PreviewPlayer {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AudioAsset? _current;
  File? _file;
  @override
  File? get currentFile => _file;
  String? _error;
  bool _closed = false;
  int _generation = 0;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (!_closed) notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((_) {
        if (!_closed) notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.errorStream.listen((_) {
        _error = 'Воспроизведение прервано. Попробуйте открыть файл заново.';
        unawaited(stop());
      }),
    );
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) unawaited(_pauseForInterruption());
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        unawaited(_pauseForInterruption());
      }),
    );
  }

  @override
  AudioAsset? get current => _current;
  @override
  bool get playing =>
      _player.playing && _player.processingState != ProcessingState.completed;
  @override
  Duration get position => _player.position;
  @override
  String? get error => _error;

  @override
  Future<void> toggle(AudioAsset asset, File file) async {
    if (_closed) return;
    if (sessionActive?.call() ?? false) {
      throw const LibraryException('Сначала завершите активную сессию');
    }
    final generation = ++_generation;
    try {
      _error = null;
      if (!await file.exists()) {
        throw const LibraryException(
          'Аудиофайл отсутствует. Удалите запись из библиотеки и импортируйте заново.',
        );
      }
      if (generation != _generation) return;
      if (_current?.id == asset.id && playing) {
        await _player.pause();
      } else {
        if (_current?.id != asset.id) {
          await _player.stop();
          _current = asset;
          _file = file;
          await _player
              .setFilePath(file.path)
              .timeout(const Duration(seconds: 15));
        } else if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        if (generation != _generation) return;
        // play() completes only at the end of the track. Don't block the UI.
        unawaited(
          _player.play().catchError((Object _) {
            if (_closed || generation != _generation) return;
            _error = 'Не удалось воспроизвести аудио. Проверьте файл.';
            unawaited(stop());
          }),
        );
      }
      if (!_closed && generation == _generation) notifyListeners();
    } catch (error) {
      if (generation != _generation) return;
      await stop();
      if (error is LibraryException) rethrow;
      throw const LibraryException(
        'Не удалось воспроизвести аудио. Проверьте файл.',
      );
    }
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    _generation++;
    await _player.stop();
    _current = null;
    _file = null;
    if (!_closed) notifyListeners();
  }

  Future<void> _pauseForInterruption() async {
    if (_closed) return;
    _generation++;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_closed || _current == null) return;
    await _player.seek(position);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    super.dispose();
  }
}
