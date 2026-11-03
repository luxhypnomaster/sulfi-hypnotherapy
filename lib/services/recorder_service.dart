import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart' as native;

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import 'library_service.dart';

abstract interface class CaptureBackend {
  Future<bool> permission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Stream<double> get amplitude;
  Future<void> dispose();
}

class NativeCaptureBackend implements CaptureBackend {
  final _recorder = native.AudioRecorder();
  @override
  Future<bool> permission() => _recorder.hasPermission();
  @override
  Future<void> start(String path) => _recorder.start(
    const native.RecordConfig(encoder: native.AudioEncoder.aacLc),
    path: path,
  );
  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();
  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 150))
      .map((a) => ((a.current + 60) / 60).clamp(0.0, 1.0));
  @override
  Future<void> dispose() => _recorder.dispose();
}

enum CaptureState {
  idle,
  requestingPermission,
  recording,
  paused,
  finished,
  saving,
  saved,
  error,
}

class RecorderService extends ChangeNotifier {
  RecorderService({
    required this.backend,
    required this.library,
    required this.tempDirectory,
  });
  final CaptureBackend backend;
  final LibraryService library;
  final Directory tempDirectory;
  CaptureState state = CaptureState.idle;
  String? error, path;
  Duration duration = Duration.zero;
  double level = 0;
  bool busy = false, _disposed = false, _pendingInterrupt = false;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  StreamSubscription<double>? _levels;
  bool get capturing =>
      state == CaptureState.recording || state == CaptureState.paused;
  bool get hasTake => path != null;
  bool get canSave => state == CaptureState.finished;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _command(Future<void> Function() f) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await f();
    } catch (e) {
      _watch.stop();
      _timer?.cancel();
      level = 0;
      if (state != CaptureState.finished) state = CaptureState.error;
      error = e is LibraryException ? e.message : 'Не удалось записать или сохранить. Дубль не удалён: проверьте микрофон и свободное место.';
    } finally {
      busy = false;
      _notify();
      if (_pendingInterrupt) {
        _pendingInterrupt = false;
        unawaited(interrupt());
      }
    }
  }

  Future<void> start() => _command(() async {
    if (state != CaptureState.idle &&
        !(state == CaptureState.error && !hasTake)) {
      return;
    }
    state = CaptureState.requestingPermission;
    _notify();
    if (!await backend.permission()) {
      state = CaptureState.idle;
      throw const LibraryException(
        'Доступ к микрофону не разрешён. Разрешите его в настройках Android и повторите запись.',
      );
    }
    await tempDirectory.create(recursive: true);
    path = '${tempDirectory.path}/take_${newId()}.m4a';
    await backend.start(path!);
    _watch.reset();
    _watch.start();
    state = CaptureState.recording;
    _levels = backend.amplitude.listen(
      (v) {
        level = state == CaptureState.recording ? v : 0;
        _notify();
      },
      onError: (Object e) {
        unawaited(interrupt());
      },
    );
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (state == CaptureState.recording) {
        duration = _watch.elapsed;
        _notify();
      }
    });
  });
  Future<void> pause() => _command(() async {
    if (state != CaptureState.recording) return;
    await backend.pause();
    _watch.stop();
    duration = _watch.elapsed;
    level = 0;
    state = CaptureState.paused;
  });
  Future<void> resume() => _command(() async {
    if (state != CaptureState.paused) return;
    await backend.resume();
    _watch.start();
    state = CaptureState.recording;
  });
  Future<void> finish() => _command(() async {
    if (!capturing) return;
    path = await backend.stop() ?? path;
    _watch.stop();
    _timer?.cancel();
    level = 0;
    if (path == null ||
        !await File(path!).exists() ||
        await File(path!).length() == 0) {
      throw const LibraryException('Запись пуста. Запишите новый дубль.');
    }
    final actual = await library.probe(path!);
    if (actual == null || actual.inMilliseconds <= 0) {
      throw const LibraryException(
        'Не удалось прочитать запись. Дубль сохранён временно.',
      );
    }
    duration = actual;
    state = CaptureState.finished;
  });
  Future<AudioAsset?> save(
    String title,
    AudioCategory category, {
    String description = '',
    List<String> tags = const [],
  }) async {
    AudioAsset? result;
    await _command(() async {
      if (!canSave) return;
      if (title.trim().isEmpty) {
        throw const LibraryException('Введите название трека.');
      }
      state = CaptureState.saving;
      _notify();
      AudioAsset? prepared;
      try {
        prepared = await library.prepareRecording(path!);
        result = prepared.edited(
          title,
          category,
          description: description,
          section: LibrarySection.personal,
          tags: tags,
        );
        await library.save(result!);
        state = CaptureState.saved;
        try {
          await File(path!).delete();
        } catch (_) {
          /* committed audio is safe; leave temp cleanup for later */
        }
        path = null;
      } catch (_) {
        if (result == null || state != CaptureState.saved) {
          if (prepared != null) await library.discard(prepared);
          state = CaptureState.finished;
          result = null;
        }
        rethrow;
      }
    });
    return result;
  }

  Future<void> discard() => _command(() async {
    await backend.cancel();
    await _levels?.cancel();
    _levels = null;
    _timer?.cancel();
    _watch.stop();
    _watch.reset();
    if (path != null && await File(path!).exists()) await File(path!).delete();
    path = null;
    level = 0;
    duration = Duration.zero;
    state = CaptureState.idle;
  });
  Future<void> interrupt() async {
    if (busy) {
      _pendingInterrupt = true;
      return;
    }
    if (capturing) {
      await finish();
      error = 'Запись остановлена при прерывании. Проверьте и сохраните дубль.';
      _notify();
    }
  }

  Future<void> close() async {
    await backend.cancel();
    await _levels?.cancel();
    _timer?.cancel();
    _watch.stop();
    _disposed = true;
    await backend.dispose();
    super.dispose();
  }
}
