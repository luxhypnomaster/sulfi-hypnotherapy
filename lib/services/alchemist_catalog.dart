import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'alchemist_media_transfer.dart';

import 'dart:convert';

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

  Future<Map<String, dynamic>> prepareCollection(
    List<ContentRevision> roots,
    String title,
  ) async {
    if (roots.isEmpty) {
      throw const FormatException('Выберите материалы для сборки');
    }
    resolveContentRoots(
      roots.map((r) => r.key).toList(),
      await LocalCatalogSource.currentIndex(controller.capsules!),
    );
    final draft = await prepare(roots.first);
    draft['type'] = 'collection';
    draft['logicalId'] = newId();
    draft['roots'] = roots.map((r) => r.toMap()).toList();
    draft['card']['title'] = title;
    await save(draft);
    return draft;
  }

  Future<Map<String, dynamic>> preparePackage(File source) async {
    final local = await LocalCatalogSource.open(controller.capsules!, source);
    try {
      for (final table in local.preview.records.entries) {
        if (![
              'audio_assets',
              'module_definitions',
              'session_templates',
              'content_revisions',
            ].contains(table.key) &&
            (table.value as List).isNotEmpty) {
          throw const FormatException(
            'Для публикации нужен выборочный ZIP без личной истории и дневника',
          );
        }
      }
      final children = {
        for (final r in local.revisions)
          for (final d in r.dependencies) d.token,
      };
      final roots = local.revisions
          .where((r) => !children.contains(r.key.token))
          .toList();
      if (roots.isEmpty) {
        throw const FormatException(
          'ZIP не содержит устанавливаемых материалов',
        );
      }
      final hash = (await sha256.bind(source.openRead()).first).toString();
      final folder = Directory(
        p.join(controller.library.directory.parent.path, 'alchemist_packages'),
      );
      await folder.create(recursive: true);
      final target = File(p.join(folder.path, '$hash.zip'));
      if (!await target.exists()) await source.copy(target.path);
      if ((await sha256.bind(target.openRead()).first).toString() != hash) {
        throw const FormatException('ZIP изменился');
      }
      final draft = await prepare(roots.first);
      draft['type'] = 'package';
      draft['logicalId'] = newId();
      draft['zipPath'] = target.path;
      draft['packageHash'] = hash;
      draft['packageBytes'] = await target.length();
      draft['packageRoots'] = roots.map((r) => r.key.toMap()).toList();
      draft['card']['title'] = p.basenameWithoutExtension(source.path);
      await save(draft);
      return draft;
    } finally {
      await local.close();
    }
  }

  AlchemistApi get remote =>
      api ??
      (throw const FormatException(
        'Сервер ещё не подключён. Черновик сохранён на телефоне.',
      ));
  Future<Map<String, dynamic>> _upload(
    ContentRevision r,
    void Function(int, int)? progress,
    bool Function()? interrupted,
  ) async {
    final asset = controller.asset(r.key.content.id);
    if (asset == null || asset.contentHash == null) {
      throw const FormatException('Для публикации нужен проверенный аудиофайл');
    }
    final mime = switch (asset.format.toLowerCase()) {
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => throw const FormatException('Неподдерживаемый формат'),
    };
    return AlchemistMediaTransfer(db, remote).upload(
      controller.library.fileFor(asset),
      logicalId: asset.id,
      revisionId: r.key.revision,
      mime: mime,
      expectedHash: asset.contentHash,
      progress: progress,
      interrupted: interrupted,
    );
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
    bool Function()? interrupted,
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
      if (interrupted?.call() == true) {
        throw const FormatException('Публикация приостановлена');
      }
      if (draft['pending'] != null) await _recover(draft);
      final roots = (draft['roots'] as List? ?? [draft['root']])
          .map((v) => ContentRevision.fromMap(Map<String, dynamic>.from(v)))
          .toList();
      final root = roots.first;
      final contentRevision = draft['type'] == 'package'
          ? draft['packageHash'] as String
          : draft['type'] == 'collection'
          ? contentDigest({'roots': roots.map((r) => r.key.toMap()).toList()})
          : root.key.revision;
      if (draft['remoteRevision'] != contentRevision) {
        if (draft['type'] == 'package') {
          final uploaded = await AlchemistMediaTransfer(db, remote).upload(
            File(draft['zipPath']),
            logicalId: draft['logicalId'],
            revisionId: contentRevision,
            mime: 'application/zip',
            expectedHash: contentRevision,
            progress: progress,
          );
          final parameters = <String, dynamic>{
            'catalogItemId': draft['catalogItemId'],
            'card': card,
            'immutableRevisionId': contentRevision,
            'manifest': {
              'schemaVersion': 1,
              'dependencyRefs': [
                {
                  'logicalId': uploaded['logicalId'],
                  'revisionId': uploaded['revisionId'],
                  'sha256': uploaded['sha256'],
                },
              ],
              'package': {
                'sha256': uploaded['sha256'],
                'byteLength': uploaded['byteLength'],
                'selectionRoots': draft['packageRoots'],
              },
            },
          };
          if (draft['etag'] == null) {
            parameters.addAll({
              'type': 'package',
              'logicalContentId': draft['logicalId'],
            });
            await _mutation(draft, 'catalog.createDraft', parameters);
          } else {
            parameters['ifMatch'] = draft['etag'];
            await _mutation(draft, 'catalog.patchDraft', parameters);
          }
        } else {
          final index = await LocalCatalogSource.currentIndex(
            controller.capsules!,
          );
          final closure = resolveContentRoots(
            roots.map((r) => r.key).toList(),
            index,
          );
          final refs = <String, Map<String, dynamic>>{};
          for (final r in closure.revisions) {
            if (r.key.content.type == ContentType.track) {
              await _upload(r, progress, interrupted);
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
            'immutableRevisionId': contentRevision,
            'manifest': {
              'schemaVersion': 1,
              'dependencyRefs': roots.map((r) => refs[r.key.token]).toList(),
              if (draft['type'] == 'collection')
                'roots': roots.map((r) => r.key.toMap()).toList(),
            },
          };
          if (draft['etag'] == null) {
            parameters.addAll({
              'type': draft['type'],
              'logicalContentId': draft['logicalId'] ?? root.key.content.id,
            });
            await _mutation(draft, 'catalog.createDraft', parameters);
          } else {
            parameters['ifMatch'] = draft['etag'];
            await _mutation(draft, 'catalog.patchDraft', parameters);
          }
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
          draft['publishedRevision'] != contentRevision) {
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
      draft['publishedRevision'] = contentRevision;
      draft['status'] = 'published';
      draft.remove('error');
      await save(draft);
    } catch (e) {
      draft['status'] = interrupted?.call() == true ? 'paused' : 'failed';
      draft['error'] = e.toString();
      await save(draft);
      rethrow;
    }
  }
}
