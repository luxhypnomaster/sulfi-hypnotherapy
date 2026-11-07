import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

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
    this.references,
    this.resetRelatedData,
    this.externalReader,
  });

  final LibraryRepository repository;
  final Directory directory;
  final AudioPicker pick;
  final DurationProbe probe;
  final Future<void> Function()? releaseSelection;
  final Future<List<String>> Function(String assetId)? references;
  final Future<void> Function()? resetRelatedData;
  final Future<String> Function(String uri)? externalReader;
  final List<String> migrationIssues = [];

  File fileFor(AudioAsset asset) {
    if (p.basename(asset.filePath) != asset.filePath) {
      throw const LibraryException(
        'Прежний источник аудио недоступен. Сохраните оригинал на устройство и импортируйте заново.',
      );
    }
    return File(p.join(directory.path, asset.filePath));
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    migrationIssues.clear();
    for (final old in await repository.list()) {
      if (p.basename(old.filePath) == old.filePath) continue;
      String? cached;
      AudioAsset? copied;
      try {
        final path = old.filePath.startsWith('content:')
            ? (cached = await externalReader?.call(old.filePath))
            : old.filePath;
        if (path == null || !p.isAbsolute(path)) {
          throw const LibraryException('Оригинал недоступен');
        }
        copied = await _copySelection((
          name: '${old.id}.${old.format}',
          path: path,
        ));
        await repository.save(
          AudioAsset.fromMap({
            ...old.toMap(),
            'filePath': copied.filePath,
            'contentHash': copied.contentHash,
            'fileSizeBytes': copied.fileSizeBytes,
            'durationMs': copied.durationMs,
          }),
        );
      } catch (_) {
        if (copied != null) await discard(copied);
        migrationIssues.add(
          '«${old.title}»: прежний источник недоступен. Импортируйте файл заново.',
        );
      } finally {
        if (cached != null && await File(cached).exists()) {
          await File(cached).delete();
        }
      }
    }
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

  Future<AudioAsset> prepareRecording(String path) async {
    final asset = await _copySelection((name: 'Личная запись.m4a', path: path));
    return AudioAsset.fromMap({
      ...asset.toMap(),
      'source': 'recorded',
      'section': 'personal',
    });
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
      final hash = (await sha256.bind(partial.openRead()).first).toString();
      if (await partial.length() != await source.length() ||
          hash != (await sha256.bind(source.openRead()).first).toString()) {
        throw const LibraryException(
          'Файл изменился при копировании. Повторите импорт.',
        );
      }
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
        origin: 'personal',
        contentHash: hash,
        section: LibrarySection.personal,
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

  /// Lazily identifies legacy bytes without rewriting media or losing IDs.
  Future<AudioAsset> identify(AudioAsset asset, {bool verify = false}) async {
    final file = fileFor(asset);
    if (!await file.exists()) {
      throw LibraryException('Файл «${asset.title}» отсутствует.');
    }
    if (asset.contentHash != null && !verify) return asset;
    final hash = (await sha256.bind(file.openRead()).first).toString();
    if (asset.contentHash != null && asset.contentHash != hash) {
      throw LibraryException('Содержимое «${asset.title}» изменилось.');
    }
    final identified = AudioAsset.fromMap({
      ...asset.toMap(),
      'contentHash': hash,
    });
    await repository.save(identified);
    return identified;
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
    final usedBy = await references?.call(asset.id) ?? [];
    if (usedBy.isNotEmpty) {
      throw LibraryException(
        'Аудио используется: ${usedBy.join(', ')}. Сначала замените или удалите эти элементы.',
      );
    }
    // Delete bytes first: if that fails, the visible entry remains retryable.
    // If the DB operation fails, a missing file is shown explicitly in preview.
    await discard(asset);
    await repository.delete(asset.id);
  }

  Future<void> reset() async {
    await resetRelatedData?.call();
    for (final asset in await repository.list()) {
      await delete(asset);
    }
    await repository.clear();
    await initialize();
    await releaseSelection?.call();
  }
}
