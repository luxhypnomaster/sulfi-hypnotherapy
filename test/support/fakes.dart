import 'dart:io';

import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/preview_player.dart';

AudioAsset sampleAsset({
  String id = 'sample',
  String title = 'Тестовая запись',
}) => AudioAsset(
  id: id,
  title: title,
  filePath: 'asset_$id.wav',
  durationMs: 65000,
  format: 'wav',
  createdAt: DateTime.utc(2026),
  category: AudioCategory.freeform,
  fileSizeBytes: 1024,
);

class MemoryRepository implements LibraryRepository {
  final Map<String, AudioAsset> items = {};
  bool failSave = false;
  @override
  Future<List<AudioAsset>> list() async => items.values.toList();
  @override
  Future<void> save(AudioAsset asset) async {
    if (failSave) throw StateError('test storage failure');
    items[asset.id] = asset;
  }

  @override
  Future<void> delete(String id) async {
    items.remove(id);
  }

  @override
  Future<void> clear() async {
    items.clear();
  }
}

class MemoryLibrary extends LibraryService {
  MemoryLibrary(MemoryRepository repository)
    : super(
        repository: repository,
        directory: Directory.systemTemp,
        pick: () async => null,
        probe: (_) async => null,
      );
  AudioAsset? importResult;
  bool importFails = false;
  bool discarded = false;
  @override
  Future<AudioAsset?> prepareImport() async {
    if (importFails) throw const LibraryException('Повреждённый файл');
    return importResult;
  }

  @override
  Future<void> discard(AudioAsset asset) async {
    discarded = true;
  }

  @override
  Future<void> delete(AudioAsset asset) => repository.delete(asset.id);
  @override
  Future<void> reset() => repository.clear();
}

class MemoryPlayer extends PreviewPlayer {
  AudioAsset? _current;
  bool _playing = false;
  @override
  AudioAsset? get current => _current;
  @override
  bool get playing => _playing;
  @override
  Duration get position => Duration.zero;
  @override
  String? get error => null;
  @override
  Future<void> toggle(AudioAsset asset, File file) async {
    _playing = _current?.id == asset.id ? !_playing : true;
    _current = asset;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _current = null;
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    dispose();
  }
}
