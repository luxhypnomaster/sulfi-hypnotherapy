import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import '../models/session_plan.dart';
import 'alchemist_api.dart';
import 'local_content_catalog.dart';
import 'session_controller.dart';

/// Drafts/outbox references live in existing private SQLite, never in an APK.
class AlchemistCatalog {
  AlchemistCatalog(this.controller, {this.api});
  final SessionController controller;
  final AlchemistApi? api;
  Database get db => controller.capsules!.database;
  Future<List<Map<String, dynamic>>> drafts() async =>
      (await db.query(
            'app_settings',
            where: 'name LIKE ?',
            whereArgs: ['alchemist_card:%'],
          ))
          .map(
            (r) => Map<String, dynamic>.from(jsonDecode(r['value'] as String)),
          )
          .toList();
  Future<void> save(Map<String, dynamic> card) async {
    if (!controller.library.policy.isAuthor) {
      throw const FormatException('Авторский режим недоступен');
    }
    await db.insert('app_settings', {
      'name': 'alchemist_card:${card['catalogItemId']}',
      'value': jsonEncode(card),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> prepare(ContentRevision root) async {
    final title = root.payload['title'] ?? root.payload['name'] ?? 'Материал';
    final draft = <String, dynamic>{
      'catalogItemId': newId(),
      'type': root.key.content.type.name,
      'root': root.toMap(),
      'status': 'draft',
      'createRequestId': newId(),
      'publishRequestId': newId(),
      'card': {
        'title': title,
        'shortAnnotation': '',
        'description': '',
        'categoryIds': <String>[],
        'tags': <String>[],
        'language': 'ru',
        'authorDisplayName': '',
        'visibility': 'private',
        'releaseNotes': '',
      },
    };
    await save(draft);
    return draft;
  }

  AlchemistApi get remote =>
      api ??
      (throw const FormatException(
        'Сервер ещё не подключён. Черновик сохранён на телефоне.',
      ));
  Future<Map<String, dynamic>> _upload(
    ContentRevision r,
    void Function(int, int)? progress,
  ) async {
    final asset = controller.asset(r.key.content.id);
    if (asset == null || asset.contentHash == null) {
      throw const FormatException('Для публикации нужен проверенный аудиофайл');
    }
    final file = controller.library.fileFor(asset), size = await file.length();
    if (size != asset.fileSizeBytes ||
        (await sha256.bind(file.openRead()).first).toString() !=
            asset.contentHash) {
      throw const FormatException('Аудиофайл изменён. Публикация остановлена.');
    }
    final mime = switch (asset.format.toLowerCase()) {
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => throw const FormatException('Неподдерживаемый формат'),
    };
    final key = 'alchemist_upload:${r.key.token}';
    var saved = (await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [key],
    )).firstOrNull;
    final requestId = saved == null
        ? newId()
        : jsonDecode(saved['value'] as String)['requestId'] as String;
    await db.insert('app_settings', {
      'name': key,
      'value': jsonEncode({'requestId': requestId}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final start = await remote.call('media.beginUpload', {
      'requestId': requestId,
      'logicalId': asset.id,
      'revisionId': r.key.revision,
      'sha256': asset.contentHash,
      'byteLength': size,
      'mime': mime,
    });
    var offset = start['offset'] as int;
    final input = await file.open();
    try {
      await input.setPosition(offset);
      while (offset < size) {
        final bytes = await input.read(262144);
        if (bytes.isEmpty) throw const FormatException('Файл оборвался');
        final result = await remote.call('media.uploadChunk', {
          'sessionId': start['sessionId'],
          'offset': offset,
          'base64': base64Encode(bytes),
        });
        offset = result['offset'] as int;
        await input.setPosition(offset);
        progress?.call(offset, size);
      }
    } finally {
      await input.close();
    }
    Map<String, dynamic> result;
    do {
      result = await remote.call('media.commitUpload', {
        'sessionId': start['sessionId'],
      });
      if (result['state'] == 'verifying') {
        progress?.call(result['verifiedBytes'] as int, size);
      }
    } while (result['state'] == 'verifying');
    if (result['sha256'] != asset.contentHash || result['byteLength'] != size) {
      throw const FormatException('Сервер не подтвердил байты аудио');
    }
    return {
      'logicalId': result['logicalId'],
      'revisionId': result['revisionId'],
      'sha256': result['sha256'],
    };
  }

  Future<Map<String, dynamic>> _mutation(
    Map<String, dynamic> draft,
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    final pending = <String, dynamic>{
      'operation': operation,
      'parameters': {'requestId': newId(), ...parameters},
    };
    draft['pending'] = pending;
    await save(draft);
    return _recover(draft);
  }

  Future<Map<String, dynamic>> _recover(Map<String, dynamic> draft) async {
    final pending = Map<String, dynamic>.from(draft['pending']);
    final result = await remote.call(
      pending['operation'],
      Map<String, dynamic>.from(pending['parameters']),
    );
    // Keep the exact request/ETag until the remote receipt is received.
    draft['etag'] = result['etag'];
    draft['remoteStatus'] = result['publicationState'];
    if (pending['operation'] == 'catalog.publish') {
      draft['publishedRevision'] = result['immutableRevisionId'];
    }
    if (result['card'] != null) draft['syncedCard'] = result['card'];
    if (result['immutableRevisionId'] != null) {
      draft['remoteRevision'] = result['immutableRevisionId'];
    }
    draft.remove('pending');
    await save(draft);
    return result;
  }

  Future<void> transition(Map<String, dynamic> draft, String action) async {
    if (!['withdraw', 'archive', 'restore'].contains(action)) {
      throw const FormatException('Неизвестное действие публикации');
    }
    if (draft['pending'] != null) await _recover(draft);
    final result = await _mutation(draft, 'catalog.$action', {
      'catalogItemId': draft['catalogItemId'],
      'ifMatch': draft['etag'],
    });
    draft['status'] = result['publicationState'];
    await save(draft);
  }

  Future<void> publish(
    Map<String, dynamic> draft, {
    void Function(int, int)? progress,
  }) async {
    if (!controller.library.policy.isAuthor) {
      throw const FormatException('Авторский режим недоступен');
    }
    final card = Map<String, dynamic>.from(draft['card']);
    if ((card['title'] as String).trim().isEmpty ||
        (card['shortAnnotation'] as String).trim().isEmpty) {
      throw const FormatException('Заполните название и аннотацию');
    }
    draft['status'] = 'uploading';
    await save(draft);
    try {
      if (draft['pending'] != null) await _recover(draft);
      final root = ContentRevision.fromMap(
        Map<String, dynamic>.from(draft['root']),
      );
      if (draft['remoteRevision'] != root.key.revision) {
        final index = await LocalCatalogSource.currentIndex(
          controller.capsules!,
        );
        final closure = resolveContent(root.key, index);
        final refs = <String, Map<String, dynamic>>{};
        for (final r in closure.revisions) {
          if (r.key.content.type == ContentType.track) {
            await _upload(r, progress);
          }
          final body = {
            'type': r.key.content.type.name,
            'logicalId': r.key.content.id,
            'payload': r.payload,
            'dependencies': r.dependencies.map((d) => d.toMap()).toList(),
            'parent': r.parent?.toMap(),
            'declaredVersion': r.declaredVersion,
          };
          refs[r.key.token] = await remote.call('content.registerManifest', {
            'revision': r.toMap(),
            'canonicalBody': canonicalContent(body),
            'canonicalRevision': canonicalContent(r.toMap()),
          });
        }
        final parameters = <String, dynamic>{
          'catalogItemId': draft['catalogItemId'],
          'card': card,
          'immutableRevisionId': root.key.revision,
          'manifest': {
            'schemaVersion': 1,
            'dependencyRefs': [refs[root.key.token]],
          },
        };
        if (draft['etag'] == null) {
          parameters.addAll({
            'type': draft['type'],
            'logicalContentId': root.key.content.id,
          });
          await _mutation(draft, 'catalog.createDraft', parameters);
        } else {
          parameters['ifMatch'] = draft['etag'];
          await _mutation(draft, 'catalog.patchDraft', parameters);
        }
      }
      if (canonicalContent(draft['syncedCard']) != canonicalContent(card)) {
        await _mutation(draft, 'catalog.updateMetadata', {
          'catalogItemId': draft['catalogItemId'],
          'ifMatch': draft['etag'],
          'card': card,
        });
      }
      if (draft['remoteStatus'] != 'published' ||
          draft['publishedRevision'] != root.key.revision) {
        await _mutation(draft, 'catalog.publish', {
          'catalogItemId': draft['catalogItemId'],
          'ifMatch': draft['etag'],
        });
      }
      final verified = await remote.call('catalog.get', {
        'catalogItemId': draft['catalogItemId'],
      });
      if (verified['publicationState'] != 'published' ||
          verified['etag'] != draft['etag']) {
        throw const FormatException(
          'Публикация не подтверждена чтением с сервера',
        );
      }
      draft['publishedRevision'] = root.key.revision;
      draft['status'] = 'published';
      draft.remove('error');
      await save(draft);
    } catch (e) {
      draft['status'] = 'failed';
      draft['error'] = e.toString();
      await save(draft);
      rethrow;
    }
  }
}
