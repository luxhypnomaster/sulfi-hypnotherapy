import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import 'alchemist_api.dart';
import 'capsule_service.dart';
import 'local_content_catalog.dart';

/// Remote bytes become a verified selection capsule; the existing transactional
/// importer remains the only writer of installed library/module/template data.
class AlchemistInstall {
  AlchemistInstall(this.service, this.api);
  final CapsuleService service;
  final AlchemistApi api;
  Future<File> _bytes(
    Map<String, dynamic> asset, {
    bool Function()? interrupted,
    void Function(int, int)? progress,
  }) async {
    final hash = asset['sha256'] as String, size = asset['byteLength'] as int;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) || size <= 0) {
      throw const FormatException('Некорректный файл сервера');
    }
    for (final local in await service.library.repository.list()) {
      final f = service.library.fileFor(local);
      if (local.contentHash == hash &&
          await f.exists() &&
          await f.length() == size &&
          (await sha256.bind(f.openRead()).first).toString() == hash) {
        return f;
      }
    }
    final cache = Directory(
      p.join(service.library.directory.parent.path, 'alchemist_transfers'),
    );
    await cache.create(recursive: true);
    final file = File(p.join(cache.path, '$hash.part'));
    if (!await file.exists()) await file.create();
    var offset = await file.length();
    // Only complete, flushed chunks are resumable after process death.
    if (offset > size || offset < size && offset % 262144 != 0) {
      offset -= offset % 262144;
      if (offset > size) offset = 0;
      final repair = await file.open(mode: FileMode.append);
      try {
        await repair.truncate(offset);
      } finally {
        await repair.close();
      }
    }
    final out = await file.open(mode: FileMode.append);
    try {
      while (offset < size) {
        if (interrupted?.call() == true) {
          throw const FormatException(
            'Загрузка приостановлена. Можно продолжить.',
          );
        }
        final chunk = await api.call('media.downloadChunk', {
          'assetRevisionId': asset['assetRevisionId'],
          'offset': offset,
          'length': 262144,
        });
        final bytes = base64Decode(chunk['base64'] as String);
        final expected = (size - offset).clamp(0, 262144);
        if (chunk['offset'] != offset ||
            chunk['byteLength'] != size ||
            chunk['sha256'] != hash ||
            bytes.length != expected ||
            sha256.convert(bytes).toString() != chunk['chunkSha256']) {
          throw const FormatException('Повреждённый блок загрузки');
        }
        await out.writeFrom(bytes);
        await out.flush();
        offset += bytes.length;
        progress?.call(offset, size);
      }
    } finally {
      await out.close();
    }
    if ((await sha256.bind(file.openRead()).first).toString() != hash) {
      // A corrupt checkpoint must not poison every subsequent retry.
      await file.delete();
      throw const FormatException('Контрольная сумма загрузки не совпала');
    }
    await api.call('media.finalizeDownload', {
      'assetRevisionId': asset['assetRevisionId'],
      'sha256': hash,
      'byteLength': size,
    });
    return file;
  }

  Future<void> install(
    Map<String, dynamic> card, {
    bool Function()? interrupted,
    void Function(int, int)? progress,
  }) async {
    void check() {
      if (interrupted?.call() == true) {
        throw const FormatException('Установка приостановлена');
      }
    }

    final fresh = await api.call('catalog.get', {
      'catalogItemId': card['catalogItemId'],
    });
    if (fresh['immutableRevisionId'] != card['immutableRevisionId']) {
      throw const FormatException('Версия изменилась. Обновите каталог.');
    }
    final plan = await api.call('catalog.getInstallPlan', {
      'catalogItemId': card['catalogItemId'],
      'installed': <String>[],
    });
    final descriptors = <String, Map<String, dynamic>>{};
    final revisions = <ContentRevision>[];
    final files = <String, File>{};
    final sizes = <String, int>{};
    for (final raw in plan['dependencies'] as List) {
      check();
      final item = Map<String, dynamic>.from(raw);
      final d = await api.call('media.getDescriptor', {
        'assetRevisionId': item['assetRevisionId'],
      });
      if (d['logicalId'] != item['logicalId'] ||
          d['revisionId'] != item['revisionId'] ||
          d['sha256'] != item['sha256'] ||
          d['byteLength'] != item['byteLength']) {
        throw const FormatException('Описание зависимости не совпало');
      }
      final rawRevision = d['canonicalRevision'];
      if (rawRevision is! String) {
        throw const FormatException('Нет точного манифеста материала');
      }
      final revision = ContentRevision.fromMap(
        Map<String, dynamic>.from(jsonDecode(rawRevision)),
      );
      if (revision.key.content.id != d['logicalId'] ||
          revision.key.revision != d['revisionId']) {
        throw const FormatException('Подмена ссылки материала');
      }
      if (revision.key.content.type != ContentType.track &&
          sha256.convert(utf8.encode(rawRevision)).toString() != d['sha256']) {
        throw const FormatException('Повреждённый манифест');
      }
      revisions.add(revision);
      descriptors[revision.key.token] = d;
      if (revision.key.content.type == ContentType.track) {
        if (revision.payload['contentHash'] != d['sha256'] ||
            revision.payload['fileSizeBytes'] != d['byteLength']) {
          throw const FormatException('Байты трека не соответствуют манифесту');
        }
        sizes[d['sha256']] = d['byteLength'];
      }
    }
    final root = revisions.singleWhere(
      (r) =>
          r.key.content.id == card['logicalContentId'] &&
          r.key.revision == card['immutableRevisionId'],
    );
    final closure = resolveContent(root.key, revisions);
    final needed =
        sizes.values.fold<int>(0, (n, s) => n + s) * 4 + 16 * 1024 * 1024;
    if (service.availableBytes != null &&
        await service.availableBytes!() < needed) {
      throw const FormatException('Недостаточно места. Установка не началась.');
    }
    for (final r in closure.revisions.where(
      (r) => r.key.content.type == ContentType.track,
    )) {
      check();
      files[r.payload['contentHash']] = await _bytes(
        descriptors[r.key.token]!,
        interrupted: interrupted,
        progress: progress,
      );
    }
    await service.workspace.create(recursive: true);
    final stage = await service.workspace.createTemp('remote-selection-');
    LocalCatalogSource? local;
    try {
      final records = <String, dynamic>{
        for (final t in CapsuleService.tables) t: <dynamic>[],
      };
      for (final r in closure.revisions) {
        records[LocalCatalogSource.table(r.key.content.type)].add(
          r.key.content.type == ContentType.track
              ? Map<String, dynamic>.from(r.payload)
              : {'id': r.key.content.id, 'payload': jsonEncode(r.payload)},
        );
        records['content_revisions'].add({
          'id': r.key.token,
          'payload': jsonEncode(r.toMap()),
        });
      }
      final manifest = <String, dynamic>{
        'format': 'sulfi-capsule',
        'schema': CapsuleService.schema,
        'databaseSchema': 9,
        'scope': 'catalog-selection',
        'records': records,
        'files': [
          for (final e in files.entries)
            {'path': 'blobs/${e.key}', 'sha256': e.key, 'bytes': sizes[e.key]},
        ],
        'dependencies':
            closure.revisions
                .where((r) => r.key.content.type == ContentType.track)
                .map((r) => r.key.content.id)
                .toList()
              ..sort(),
      };
      manifest['id'] = CapsuleService.digest(manifest);
      await File(p.join(stage.path, 'manifest.json'))
          .writeAsString(jsonEncode(manifest));
      final zipFile = File(p.join(stage.path, 'selection.zip'));
      final zip = ZipFileEncoder();
      zip.create(zipFile.path, level: 0);
      try {
        await zip.addFile(
          File(p.join(stage.path, 'manifest.json')),
          'manifest.json',
        );
        for (final e in files.entries) {
          check();
          await zip.addFile(e.value, 'blobs/${e.key}');
        }
      } finally {
        await zip.close();
      }
      local = await LocalCatalogSource.open(service, zipFile);
      final selection = await local.plan(root.key);
      check();
      await local.install(selection, cancelled: interrupted);
      // Install receipt is written only after the existing importer verifies all records.
      await service.database.insert('app_settings', {
        'name': 'alchemist_installed:${card['catalogItemId']}',
        'value': jsonEncode(card),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } finally {
      await local?.close();
      await stage.delete(recursive: true);
    }
  }
}
