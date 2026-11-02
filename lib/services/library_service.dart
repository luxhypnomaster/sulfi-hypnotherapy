import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../data/library_repository.dart';
import '../models/audio_asset.dart';

typedef AudioSelection = ({String name, String path});
typedef AudioPicker = Future<AudioSelection?> Function();
typedef DurationProbe = Future<Duration?> Function(String path);

class LibraryException implements Exception {
  const LibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LibraryService {
  LibraryService({
    required this.repository,
    required this.directory,
    required this.pick,
    required this.probe,
    this.releaseSelection,
  });

  final LibraryRepository repository;
  final Directory directory;
  final AudioPicker pick;
  final DurationProbe probe;
  final Future<void> Function()? releaseSelection;

  File fileFor(AudioAsset asset) {
    if (p.basename(asset.filePath) != asset.filePath) {
      throw const LibraryException('Некорректный путь к аудиофайлу.');
    }
    return File(p.join(directory.path, asset.filePath));
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    // Recover abandoned imports/deletes after process death. Only our generated
    // files are eligible, and all database-referenced files are preserved.
    final retained = (await repository.list()).map((a) => a.filePath).toSet();
    await for (final entry in directory.list()) {
      final name = p.basename(entry.path);
      if (entry is File &&
          name.startsWith('asset_') &&
          !retained.contains(name)) {
        await entry.delete();
      }
    }
  }

  // Produces a private draft. The caller must commit or discard it after editing.
  Future<AudioAsset?> prepareImport() async {
    try {
      final selected = await pick();
      if (selected == null) return null;
      return await _copySelection(selected);
    } finally {
      // Android's system picker may create a private temporary cache copy.
      // Cache cleanup failure must not turn an otherwise valid import into loss.
      try {
        await releaseSelection?.call();
      } catch (_) {
        /* retried on startup */
      }
    }
  }

  Future<AudioAsset> _copySelection(AudioSelection selected) async {
    final format = p
        .extension(selected.name)
        .toLowerCase()
        .replaceFirst('.', '');
    if (!{'mp3', 'm4a', 'wav'}.contains(format)) {
      throw const LibraryException(
        'Выберите аудио в формате MP3, M4A или WAV.',
      );
    }
    final source = File(selected.path);
    if (!await source.exists()) {
      throw const LibraryException('Файл недоступен. Выберите его заново.');
    }
    if (await source.length() == 0) {
      throw const LibraryException('Файл пуст. Выберите другую запись.');
    }
    final random = Random.secure();
    final id = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    final filename = 'asset_$id.$format';
    final target = File(p.join(directory.path, filename));
    final partial = File('${target.path}.part');
    try {
      await source.copy(partial.path);
      await partial.rename(target.path);
      // Platform decoder, rather than extension alone, validates the contents.
      final duration = await probe(target.path)
          .timeout(const Duration(seconds: 30));
      if (duration == null || duration.inMilliseconds <= 0) {
        throw const LibraryException(
          'Не удалось прочитать длительность аудио. Выберите другой файл.',
        );
      }
      return AudioAsset(
        id: id,
        title: p.basenameWithoutExtension(selected.name),
        filePath: filename,
        durationMs: duration.inMilliseconds,
        format: format,
        createdAt: DateTime.now().toUtc(),
        category: AudioCategory.freeform,
        fileSizeBytes: await target.length(),
      );
    } catch (error) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists()) await target.delete();
      if (error is LibraryException) rethrow;
      throw const LibraryException(
        'Не удалось импортировать аудио. Проверьте файл и свободное место.',
      );
    }
  }

  Future<void> discard(AudioAsset asset) async {
    final file = fileFor(asset);
    if (await file.exists()) await file.delete();
  }

  Future<void> save(AudioAsset asset) async {
    if (asset.title.trim().isEmpty || asset.title.trim().length > 120) {
      throw const LibraryException(
        'Название должно содержать от 1 до 120 символов.',
      );
    }
    await repository.save(asset);
  }

  Future<void> delete(AudioAsset asset) async {
    // Delete bytes first: if that fails, the visible entry remains retryable.
    // If the DB operation fails, a missing file is shown explicitly in preview.
    await discard(asset);
    await repository.delete(asset.id);
  }

  Future<void> reset() async {
    for (final asset in await repository.list()) {
      await delete(asset);
    }
    await repository.clear();
    await initialize();
    await releaseSelection?.call();
  }
}
