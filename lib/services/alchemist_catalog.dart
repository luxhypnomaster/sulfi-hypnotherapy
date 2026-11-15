import 'dart:async';

import 'alchemist_errors.dart';
import 'diary_api.dart';
import 'alchemist_work_queue.dart';
import '../models/diary_entry.dart';
import 'alchemist_content_upload.dart';

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
  Future<List<Map<String, dynamic>>> drafts() async {
    if (controller.policy.serverIdentityRequired &&
        !controller.policy.isAuthor) {
      return [];
    }
    final owner = api?.ownerBinding;
    return (await db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_card:%'],
        ))
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['value'] as String)))
        .where((d) => d['ownerBinding'] == null || d['ownerBinding'] == owner)
        .toList();
  }

  final _preparing = <String, Future<Map<String, dynamic>>>{};
  Future<void> _store(Map<String, dynamic> card, {bool enqueue = false}) async {
    await db.transaction((tx) async {
      final name = 'alchemist_card:${card['catalogItemId']}';
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      if (rows.isNotEmpty) {
        final previous = jsonDecode(rows.single['value'] as String);
        if (previous['_work'] != null) card['_work'] = previous['_work'];
      }
      if (enqueue) {
        final revision = queueRevision(card), work = card['_work'];
        if (work is Map &&
            work['revision'] != revision &&
            const [
              'running',
              'preparing',
              'pausing',
              'queued',
            ].contains(work['phase'])) {
          throw const AlchemistFailure(
            'Дождитесь текущей передачи перед новой редакцией.',
            409,
            'REVISION_IN_FLIGHT',
          );
        }
        if (work is! Map || work['revision'] != revision) {
          card['_work'] = initialQueuedWork(card, api!.ownerBinding!);
        }
      }
      await tx.insert('app_settings', {
        'name': name,
        'value': jsonEncode(card),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> save(Map<String, dynamic> card, {bool enqueue = false}) async {
    if (!controller.library.policy.isAuthor) {
      throw const FormatException('Авторский режим недоступен');
    }
    final owner = api?.ownerBinding;
    if (card['ownerBinding'] != null && card['ownerBinding'] != owner) {
      throw const AlchemistFailure(
        'Задача принадлежит другому аккаунту.',
        401,
        'ACCOUNT_CHANGED',
      );
    }
    if (owner != null) card['ownerBinding'] = owner;
    if (enqueue && owner == null) {
      throw const AlchemistFailure(
        'Нужен Google-вход.',
        401,
        'AUTH_REQUIRED',
        DiaryFailure.authorization,
      );
    }
    await _store(card, enqueue: enqueue);
    final author = (card['card']?['authorDisplayName'] as String? ?? '').trim();
    if (author.isNotEmpty) {
      await db.insert('app_settings', {
        'name': 'alchemist_author_profile:${owner ?? 'device'}',
        'value': author,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<String> authorDefault() async {
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_author_profile:${api?.ownerBinding ?? 'device'}'],
    );
    return rows.firstOrNull?['value'] as String? ?? '';
  }

  Future<Map<String, dynamic>> prepare(
    ContentRevision root, {
    bool reuse = true,
  }) {
    final key = '${api?.ownerBinding}:${root.key.token}';
    if (!reuse) return _prepare(root, reuse: false);
    return _preparing.putIfAbsent(
      key,
      () => _prepare(root, reuse: true).whenComplete(() {
        _preparing.remove(key);
      }),
    );
  }

  Future<Map<String, dynamic>> _prepare(
    ContentRevision root, {
    required bool reuse,
  }) async {
    if (reuse) {
      for (final d in await drafts()) {
        if (d['type'] == root.key.content.type.name &&
            d['root'] != null &&
            ContentRevision.fromMap(Map<String, dynamic>.from(d['root']))
                    .key
                    .token ==
                root.key.token) {
          return d;
        }
      }
    }
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
        'shortAnnotation': root.payload['description'] ?? '',
        'description': root.payload['description'] ?? '',
        'categoryIds': <String>[],
        'tags': <String>[],
        'language': 'ru',
        'authorDisplayName': await authorDefault(),
        'visibility': 'private',
        'releaseNotes': '',
        'coverAssetId': null,
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
    final draft = await prepare(roots.first, reuse: false);
    draft['type'] = 'collection';
    draft['logicalId'] = newId();
    draft['roots'] = roots.map((r) => r.toMap()).toList();
    draft['card']['title'] = title;
    await _store(draft);
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
      final draft = await prepare(roots.first, reuse: false);
      draft['type'] = 'package';
      draft['logicalId'] = newId();
      draft['zipPath'] = target.path;
      draft['packageHash'] = hash;
      draft['packageBytes'] = await target.length();
      draft['packageRoots'] = roots.map((r) => r.key.toMap()).toList();
      draft['card']['title'] = p.basenameWithoutExtension(source.path);
      await _store(draft);
      return draft;
    } finally {
      await local.close();
    }
  }

  Future<Map<String, dynamic>> prepareCurrentSession() async {
    if (controller.draft.plan.allSteps.isEmpty ||
        controller.draft.unavailableStepIds.isNotEmpty) {
      throw const FormatException(
        'В текущей конфигурации нет доступного состава',
      );
    }
    final index = await LocalCatalogSource.currentIndex(controller.capsules!);
    final template = SessionTemplate(
      id: newId(),
      name: controller.draft.baseTemplateName ?? 'Сессия',
      plan: controller.draft.plan,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    final records = <String, dynamic>{
      'audio_assets': index
          .where((r) => r.key.content.type == ContentType.track)
          .map((r) => Map<String, dynamic>.from(r.payload))
          .toList(),
      'module_definitions': index
          .where((r) => r.key.content.type == ContentType.module)
          .map(
            (r) => {'id': r.key.content.id, 'payload': jsonEncode(r.payload)},
          )
          .toList(),
      'session_templates': [
        {'id': template.id, 'payload': jsonEncode(template.toMap())},
      ],
    };
    final root = LocalCatalogSource.indexRecords(records)
        .singleWhere((r) => r.key.content.id == template.id);
    final draft = await prepare(root);
    draft['type'] = 'session';
    draft['embeddedRoot'] = true;
    await _store(draft);
    return draft;
  }

  Future<int> synchronize() async {
    var count = 0;
    String? cursor;
    final locals = {for (final d in await drafts()) d['catalogItemId']: d};
    do {
      final page = await remote.call('catalog.list', {
        'ownedOnly': true,
        'cursor': ?cursor,
        'limit': 50,
      });
      for (final raw in page['items'] as List) {
        if (raw['type'] == 'diaryEntry') continue;
        final item = await remote.call('catalog.get', {
          'catalogItemId': raw['catalogItemId'],
        });
        final existing = locals[item['catalogItemId']];
        if (existing != null) {
          final root = existing['root'];
          final localRevision = existing['type'] == 'package'
              ? existing['packageHash']
              : existing['type'] == 'collection'
              ? contentDigest({
                  'roots': (existing['roots'] as List)
                      .map(
                        (v) => ContentRevision.fromMap(
                          Map<String, dynamic>.from(v),
                        ).key.toMap(),
                      )
                      .toList(),
                })
              : root?['revision'];
          final dirty =
              canonicalContent(existing['card']) !=
                  canonicalContent(existing['syncedCard']) ||
              ![
                'published',
                'withdrawn',
                'archived',
              ].contains(existing['status']) ||
              existing['remoteOnly'] != true &&
                  localRevision != existing['remoteRevision'];
          if (dirty) {
            if (existing['etag'] != item['etag']) {
              existing['remoteConflict'] = true;
              await save(existing);
            }
            continue;
          }
        }
        final changed =
            existing != null &&
            existing['remoteRevision'] != item['immutableRevisionId'];
        final draft = <String, dynamic>{
          ...?existing,
          'catalogItemId': item['catalogItemId'],
          'type': item['type'],
          'logicalId': item['logicalContentId'],
          'card': item['card'],
          'syncedCard': item['card'],
          'etag': item['etag'],
          'remoteRevision': item['immutableRevisionId'],
          'publishedRevision': item['immutableRevisionId'],
          'status': item['publicationState'],
          'remoteStatus': item['publicationState'],
          if (existing == null || changed) 'remoteOnly': true,
        };
        await _store(draft);
        count++;
      }
      cursor = page['nextPage'];
    } while (cursor != null);
    return count;
  }

  Future<void> _publishRemoteMetadata(
    Map<String, dynamic> draft,
    Map<String, dynamic> card,
  ) async {
    if (canonicalContent(draft['syncedCard']) != canonicalContent(card)) {
      await _mutation(draft, 'catalog.updateMetadata', {
        'catalogItemId': draft['catalogItemId'],
        'ifMatch': draft['etag'],
        'card': card,
      });
    }
    if (draft['remoteStatus'] != 'published') {
      await _mutation(draft, 'catalog.publish', {
        'catalogItemId': draft['catalogItemId'],
        'ifMatch': draft['etag'],
      });
    }
    final checked = await remote.call('catalog.get', {
      'catalogItemId': draft['catalogItemId'],
    });
    if (checked['publicationState'] != 'published' ||
        checked['etag'] != draft['etag']) {
      throw const FormatException('Публикация не подтверждена сервером');
    }
    draft['status'] = 'published';
    draft.remove('error');
    await _store(draft);
  }

  AlchemistApi get remote =>
      api ??
      (throw const FormatException(
        'Сервер ещё не подключён. Черновик сохранён на телефоне.',
      ));
  Future<Map<String, dynamic>> _mutation(
    Map<String, dynamic> draft,
    String operation,
    Map<String, dynamic> parameters,
  ) async {
    if (draft['ownerBinding'] != null &&
        draft['ownerBinding'] != remote.ownerBinding) {
      throw const AlchemistFailure(
        'Аккаунт изменился.',
        401,
        'ACCOUNT_CHANGED',
      );
    }
    final pending = <String, dynamic>{
      'operation': operation,
      'parameters': {'requestId': newId(), ...parameters},
    };
    draft['pending'] = pending;
    await _store(draft);
    return _recover(draft);
  }

  Future<Map<String, dynamic>> _recover(Map<String, dynamic> draft) async {
    if (draft['ownerBinding'] != null &&
        draft['ownerBinding'] != remote.ownerBinding) {
      throw const AlchemistFailure(
        'Аккаунт изменился.',
        401,
        'ACCOUNT_CHANGED',
      );
    }
    final pending = Map<String, dynamic>.from(draft['pending']);
    if (pending['attempted'] == true) {
      await remote.reconcileUncertain(
        pending['operation'],
        Map<String, dynamic>.from(pending['parameters']),
      );
    }
    pending['attempted'] = true;
    draft['pending'] = pending;
    await _store(draft);
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
    draft['lastReceipt'] = {
      'operation': pending['operation'],
      'requestId': pending['parameters']['requestId'],
      'etag': result['etag'],
      'publicationState': result['publicationState'],
      'confirmedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    draft.remove('pending');
    await _store(draft);
    return result;
  }

  Future<void> transition(Map<String, dynamic> draft, String action) async {
    if (!['withdraw', 'archive', 'restore'].contains(action)) {
      throw const FormatException('Неизвестное действие публикации');
    }
    if (controller.nativeTransfers) {
      draft['requestedAction'] = action;
      await _store(draft, enqueue: true);
      await controller.cloudQueue.enqueue(
        'alchemist_card:${draft['catalogItemId']}',
      );
      return;
    }
    final operation = 'catalog.$action';
    final recoveredSame = draft['pending']?['operation'] == operation;
    if (draft['pending'] != null) await _recover(draft);
    // Resume the persisted intent after an uncertain reply / process death.
    // Do not manufacture a fresh requestId for an already receipted transition.
    final last = draft['lastReceipt'];
    if (!recoveredSame &&
        !(last is Map &&
            last['operation'] == operation &&
            last['etag'] == draft['etag'])) {
      await _mutation(draft, operation, {
        'catalogItemId': draft['catalogItemId'],
        'ifMatch': draft['etag'],
      });
    }
    draft['status'] = draft['remoteStatus'];
    draft.remove('requestedAction');
    await _store(draft);
  }

  Future<void> publish(
    Map<String, dynamic> draft, {
    void Function(int, int)? progress,
    bool Function()? interrupted,
    void Function(String)? onStage,
  }) async {
    if (!controller.library.policy.isAuthor) {
      throw const FormatException('Авторский режим недоступен');
    }
    await save(draft);
    final owner = remote.ownerBinding, epoch = remote.identityEpoch?.call();
    void checkOwner() {
      if (owner != remote.ownerBinding ||
          epoch != remote.identityEpoch?.call() ||
          interrupted?.call() == true) {
        throw const AlchemistFailure(
          'Задача приостановлена.',
          401,
          'ACCOUNT_CHANGED',
        );
      }
    }

    final card = Map<String, dynamic>.from(draft['card'])
      ..putIfAbsent('coverAssetId', () => null);
    draft['card'] = card;
    if ((card['title'] as String).trim().isEmpty ||
        (card['shortAnnotation'] as String).trim().isEmpty) {
      throw const FormatException('Заполните название и аннотацию');
    }
    draft['status'] = 'uploading';
    await _store(draft);
    try {
      if (interrupted?.call() == true) {
        throw const FormatException('Публикация приостановлена');
      }
      checkOwner();
      final cover = draft['localCover'];
      if (cover is Map) {
        final m = DiaryMedia.fromMap(Map<String, dynamic>.from(cover));
        final file = controller.diary?.mediaStore?.file(m);
        if (file == null || !await file.exists()) {
          throw const FormatException(
            'Выбранная обложка недоступна. Выберите другую или явно уберите её.',
          );
        }
        draft['coverStatus'] = 'transferring';
        await _store(draft);
        final receipt = await AlchemistMediaTransfer(db, remote).upload(
          file,
          logicalId: m.assetId,
          revisionId: m.hash!,
          mime: m.mime,
          expectedHash: m.hash,
          interrupted: () =>
              interrupted?.call() == true ||
              owner != remote.ownerBinding ||
              epoch != remote.identityEpoch?.call(),
          onStage: onStage,
          taskId: draft['catalogItemId'],
        );
        checkOwner();
        card['coverAssetId'] = receipt['assetRevisionId'];
        draft['card'] = card;
        draft['coverStatus'] = 'verified';
        await _store(draft);
      }
      if (draft['pending'] != null) await _recover(draft);
      checkOwner();
      if (draft['remoteOnly'] == true) {
        draft['status'] = 'publishing';
        await _store(draft);
        onStage?.call('publishing');
        await _publishRemoteMetadata(draft, card);
        return;
      }
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
            interrupted: () =>
                interrupted?.call() == true ||
                owner != remote.ownerBinding ||
                epoch != remote.identityEpoch?.call(),
            onStage: onStage,
            taskId: draft['catalogItemId'],
          );
          checkOwner();
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
          final refs = await registerAlchemistContent(
            controller.capsules!,
            remote,
            roots.map((r) => r.key).toList(),
            embedded: draft['embeddedRoot'] == true ? [root] : [],
            interrupted: () =>
                interrupted?.call() == true ||
                owner != remote.ownerBinding ||
                epoch != remote.identityEpoch?.call(),
            onStage: onStage,
            taskId: draft['catalogItemId'],
            progress: progress,
          );
          checkOwner();
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
      if (interrupted?.call() == true) {
        throw const FormatException('Публикация приостановлена');
      }
      if (canonicalContent(draft['syncedCard']) != canonicalContent(card)) {
        await _mutation(draft, 'catalog.updateMetadata', {
          'catalogItemId': draft['catalogItemId'],
          'ifMatch': draft['etag'],
          'card': card,
        });
      }
      if (interrupted?.call() == true) {
        throw const FormatException('Публикация приостановлена');
      }
      draft['status'] = 'publishing';
      await _store(draft);
      onStage?.call('publishing');
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
      checkOwner();
      draft['status'] = 'published';
      if (draft['localCover'] != null) draft['coverStatus'] = 'published';
      draft.remove('error');
      await _store(draft);
    } catch (e) {
      draft['status'] = interrupted?.call() == true ? 'paused' : 'failed';
      if (draft['localCover'] != null &&
          !const ['verified', 'published'].contains(draft['coverStatus'])) {
        draft['coverStatus'] = 'failed';
      }
      final failure = AlchemistFailure.from(e);
      draft['error'] = failure.message;
      draft['errorCode'] = failure.code;
      await _store(draft);
      rethrow;
    }
  }
}
