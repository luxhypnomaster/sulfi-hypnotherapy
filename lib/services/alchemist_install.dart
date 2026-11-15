import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import 'alchemist_api.dart';
import 'alchemist_diagnostics.dart';
import 'alchemist_errors.dart';
import 'diary_api.dart';
import 'capsule_service.dart';
import 'local_content_catalog.dart';

/// Remote bytes become a verified selection capsule; the existing transactional
/// importer remains the only writer of installed library/module/template data.
class AlchemistInstall {
  AlchemistInstall(this.service, this.api);
  final CapsuleService service;
  final AlchemistApi api;
  static final _active = <String, Future<File>>{};
  Future<Map<String, dynamic>> _finalize(Map<String, dynamic> asset) async {
    final receipt = await api.call('media.finalizeDownload', {
      'assetRevisionId': asset['assetRevisionId'],
      'sha256': asset['sha256'],
      'byteLength': asset['byteLength'],
    });
    if (receipt['verified'] != true ||
        receipt['assetRevisionId'] != asset['assetRevisionId']) {
      throw const AlchemistFailure(
        'Сервер не подтвердил завершение загрузки.',
        422,
        'DOWNLOAD_RECEIPT_INVALID',
        DiaryFailure.invalidData,
      );
    }
    await service.database.insert('app_settings', {
      'name':
          'alchemist_download_receipt:${api.ownerBinding ?? 'public'}:${asset['assetRevisionId']}:${asset['sha256']}',
      'value': jsonEncode({
        'ownerBinding': api.ownerBinding ?? 'public',
        'assetRevisionId': asset['assetRevisionId'],
        'sha256': asset['sha256'],
        'byteLength': asset['byteLength'],
        'receipt': receipt,
        'confirmedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return receipt;
  }

  Future<File> downloadAsset(
    Map<String, dynamic> asset, {
    bool Function()? interrupted,
    void Function(int, int)? progress,
  }) {
    final key =
        '${service.library.directory.parent.path}:${api.ownerBinding ?? 'public'}:${asset['assetRevisionId']}:${asset['sha256']}';
    final existing = _active[key];
    if (existing != null) return existing;
    late Future<File> pending;
    pending =
        _downloadAsset(
          asset,
          interrupted: interrupted,
          progress: progress,
        ).whenComplete(() {
          if (identical(_active[key], pending)) _active.remove(key);
        });
    _active[key] = pending;
    return pending;
  }

  Future<File> _downloadAsset(
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
        await _finalize(asset);
        progress?.call(size, size);
        return f;
      }
    }
    final owner = api.ownerBinding ?? 'public';
    final revision = asset['assetRevisionId'];
    if (revision is! String || revision.isEmpty) {
      throw const FormatException('Нет редакции файла');
    }
    final cache = Directory(
      p.join(
        service.library.directory.parent.path,
        'alchemist_transfers',
        owner,
      ),
    );
    await cache.create(recursive: true);
    final file = File(p.join(cache.path, '$hash.part'));
    final key = 'alchemist_download_checkpoint:$owner:$revision:$hash';
    final previous = await service.database.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [key],
    );
    final state = previous.isEmpty
        ? <String, dynamic>{
            'ownerBinding': owner,
            'assetRevisionId': revision,
            'sha256': hash,
            'byteLength': size,
            'offset': 0,
            'chunks': <dynamic>[],
          }
        : Map<String, dynamic>.from(
            jsonDecode(previous.single['value'] as String),
          );
    if (state['ownerBinding'] != owner ||
        state['assetRevisionId'] != revision ||
        state['sha256'] != hash ||
        state['byteLength'] != size) {
      throw const FormatException('Конфликт checkpoint загрузки');
    }
    // Same-owner complete verified bytes may satisfy another exact asset link.
    if (await file.exists() &&
        await file.length() == size &&
        (await sha256.bind(file.openRead()).first).toString() == hash) {
      await _finalize(asset);
      progress?.call(size, size);
      return file;
    }
    var offset = state['offset'] as int;
    if (offset < 0 || offset > size) {
      throw const FormatException('Некорректный checkpoint загрузки');
    }
    if (!await file.exists()) {
      if (offset != 0) {
        throw const FormatException(
          'Часть загрузки недоступна; исходники сохранены',
        );
      }
      await file.create();
    }
    final chunks = List<dynamic>.from(state['chunks']);
    final out = await file.open(mode: FileMode.append);
    Future<void> save() => service.database
        .insert('app_settings', {
          'name': key,
          'value': jsonEncode(state),
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        .then((_) {});
    try {
      if (await out.length() < offset) {
        throw const FormatException('Часть загрузки оборвана');
      }
      // Read-only verify every previously flushed/recorded chunk before resume.
      final input = await file.open();
      var verified = 0;
      try {
        for (final raw in chunks) {
          final m = Map<String, dynamic>.from(raw);
          final length = m['length'];
          if (m['offset'] != verified ||
              length is! int ||
              length <= 0 ||
              length > 262144 ||
              verified + length > offset) {
            throw const FormatException('Нарушен журнал загрузки');
          }
          final data = await input.read(length);
          if (data.length != length ||
              sha256.convert(data).toString() != m['sha256']) {
            throw const AlchemistFailure(
              'Повреждён сохранённый блок. Установка остановлена; исходники сохранены.',
              422,
              'LOCAL_CHUNK_CORRUPT',
              DiaryFailure.invalidData,
            );
          }
          verified += length;
        }
      } finally {
        await input.close();
      }
      if (verified != offset) {
        throw const FormatException('Нет подтверждения сохранённых байтов');
      }
      // Discard only this job's unacknowledged staging tail, never user media.
      if (await out.length() > offset) await out.truncate(offset);
      await out.setPosition(offset);
      progress?.call(offset, size);
      while (offset < size) {
        if (interrupted?.call() == true) {
          throw const FormatException(
            'Загрузка приостановлена. Можно продолжить.',
          );
        }
        Map<String, dynamic> chunk;
        final clock = Stopwatch()..start();
        try {
          chunk = await api.call('media.downloadChunk', {
            'assetRevisionId': revision,
            'offset': offset,
            'length': 262144,
          });
        } on AlchemistFailure catch (e) {
          if (const [
            'DRIVE_RANGE_FAILED',
            'DRIVE_RANGE_SIZE',
            'UNKNOWN_OPERATION',
            'OPERATION_NOT_FOUND',
            'OPERATION_NOT_SUPPORTED',
          ].contains(e.code)) {
            throw const AlchemistFailure(
              'Сервер не поддержал проверяемую докачку. Установка не завершена.',
              501,
              'CHUNK_RESUME_UNAVAILABLE',
              DiaryFailure.blocked,
            );
          }
          rethrow;
        }
        final bytes = base64Decode(chunk['base64'] as String);
        final expected = (size - offset).clamp(0, 262144);
        final chunkHash = sha256.convert(bytes).toString();
        if (chunk['offset'] != offset ||
            chunk['byteLength'] != size ||
            chunk['sha256'] != hash ||
            bytes.length != expected ||
            chunkHash != chunk['chunkSha256']) {
          throw const FormatException('Повреждённый блок загрузки');
        }
        if (interrupted?.call() == true) {
          throw const FormatException(
            'Загрузка приостановлена до сохранения блока',
          );
        }
        await out.writeFrom(bytes);
        await out.flush();
        chunks.add({
          'offset': offset,
          'length': bytes.length,
          'sha256': chunkHash,
        });
        offset += bytes.length;
        state['offset'] = offset;
        state['chunks'] = chunks;
        await save();
        final d = AlchemistDiagnostics.instance;
        d.record(
          d.begin(),
          'media.downloadChunk',
          'acked',
          clock.elapsedMilliseconds,
          confirmedBytes: bytes.length,
        );
        progress?.call(offset, size);
      }
    } finally {
      await out.close();
    }
    if ((await sha256.bind(file.openRead()).first).toString() != hash) {
      throw const FormatException(
        'Контрольная сумма загрузки не совпала; неполный материал не установлен',
      );
    }
    state['receipt'] = await _finalize(asset);
    state['verified'] = true;
    await save();
    return file;
  }

  Future<void> install(
    Map<String, dynamic> card, {
    bool Function()? interrupted,
    void Function(int, int)? progress,
  }) async {
    final identityScope = api.currentIdentityScope;
    bool cancelled() =>
        interrupted?.call() == true ||
        identityScope != api.currentIdentityScope;
    void check() {
      if (cancelled()) {
        throw const FormatException('Установка приостановлена');
      }
    }

    final fresh = await api.call('catalog.get', {
      'catalogItemId': card['catalogItemId'],
    });
    if (fresh['immutableRevisionId'] != card['immutableRevisionId']) {
      throw const FormatException('Версия изменилась. Обновите каталог.');
    }
    if (card['type'] == 'package') {
      final package = fresh['manifest']['package'];
      final plan = await api.call('catalog.getInstallPlan', {
        'catalogItemId': card['catalogItemId'],
        'installed': [],
      });
      final dependency = (plan['dependencies'] as List).single;
      final descriptor = await api.call('media.getDescriptor', {
        'assetRevisionId': dependency['assetRevisionId'],
      });
      if (descriptor['mime'] != 'application/zip' ||
          descriptor['sha256'] != package['sha256'] ||
          descriptor['byteLength'] != package['byteLength']) {
        throw const FormatException(
          'ZIP не соответствует опубликованному пакету',
        );
      }
      final zip = await downloadAsset(
        descriptor,
        interrupted: cancelled,
        progress: progress,
      );
      final local = await LocalCatalogSource.open(service, zip);
      try {
        final roots = (package['selectionRoots'] as List)
            .map((v) => RevisionKey.fromMap(Map<String, dynamic>.from(v)))
            .toList();
        final selection = await local.planRoots(roots);
        await local.install(selection, cancelled: cancelled);
        await service.library.policy.registerCatalogOriginals(
          selection.closure.revisions.map((r) => r.key.toMap()),
          api.endpoint.toString(),
          card['catalogItemId'] as String,
        );
        await _receipt(card);
      } finally {
        await local.close();
      }
      return;
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
    final List<RevisionKey> roots;
    if (card['type'] == 'collection') {
      roots = (fresh['manifest']['roots'] as List)
          .map((v) => RevisionKey.fromMap(Map<String, dynamic>.from(v)))
          .toList();
      if (contentDigest({'roots': roots.map((r) => r.toMap()).toList()}) !=
          card['immutableRevisionId']) {
        throw const FormatException('Ревизия сборки не совпала');
      }
    } else {
      roots = [
        revisions
            .singleWhere(
              (r) =>
                  r.key.content.id == card['logicalContentId'] &&
                  r.key.revision == card['immutableRevisionId'],
            )
            .key,
      ];
    }
    final closure = resolveContentRoots(roots, revisions);
    sizes.clear();
    for (final r in closure.revisions.where(
      (r) => r.key.content.type == ContentType.track,
    )) {
      sizes[r.payload['contentHash']] = r.payload['fileSizeBytes'] as int;
    }
    final needed =
        sizes.values.fold<int>(0, (n, s) => n + s) * 4 + 16 * 1024 * 1024;
    if (service.availableBytes != null &&
        await service.availableBytes!() < needed) {
      throw const FormatException('Недостаточно места. Установка не началась.');
    }
    var downloaded = 0;
    final downloadTotal = sizes.values.fold<int>(0, (n, s) => n + s);
    for (final r in closure.revisions.where(
      (r) => r.key.content.type == ContentType.track,
    )) {
      check();
      // Two logical revisions can share identical immutable bytes. Count and
      // transfer each content hash once, matching the unique-size total.
      if (files.containsKey(r.payload['contentHash'])) continue;
      files[r.payload['contentHash']] = await downloadAsset(
        descriptors[r.key.token]!,
        interrupted: cancelled,
        progress: (n, _) => progress?.call(downloaded + n, downloadTotal),
      );
      downloaded += r.payload['fileSizeBytes'] as int;
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
      final selection = await local.planRoots(roots);
      check();
      await local.install(selection, cancelled: cancelled);
      // Install receipt is written only after the existing importer verifies all records.
      await service.library.policy.registerCatalogOriginals(
        closure.revisions.map((r) => r.key.toMap()),
        api.endpoint.toString(),
        card['catalogItemId'] as String,
      );
      await _receipt(card);
    } finally {
      await local?.close();
      await stage.delete(recursive: true);
    }
  }

  Future<void> _receipt(Map<String, dynamic> card) => service.database
      .insert('app_settings', {
        'name': 'alchemist_installed:${card['catalogItemId']}',
        'value': jsonEncode(card),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
}
