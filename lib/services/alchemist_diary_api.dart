import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import '../models/content_revision.dart';
import '../models/diary_publication.dart';
import '../models/session_plan.dart';
import 'alchemist_api.dart';
import 'alchemist_install.dart';
import 'alchemist_media_transfer.dart';
import 'capsule_service.dart';
import 'diary_api.dart';
import 'diary_media_store.dart';

/// Adapter for the existing diary controller/editor. The legacy server and its
/// transport remain separate; no old endpoint receives the new protocol.
class AlchemistDiaryApi extends DiaryApi {
  AlchemistDiaryApi(
    super.base, {
    required this.capsules,
    required this.media,
    this.connection,
  });
  final CapsuleService capsules;
  final DiaryMediaStore media;
  final DiaryRequest? connection;
  String? _token;
  Database get db => capsules.database;
  AlchemistApi get public => AlchemistApi(base, connection: connection);
  AlchemistApi get author => AlchemistApi(
    base,
    connection: connection,
    credential: () async =>
        _token ?? (throw const DiaryApiException('Войдите через Google')),
  );
  @override
  bool get supportsAdvancedPublication => true;
  @override
  void clearSession() {
    _token = null;
  }

  @override
  Future<DiaryAuthorSession> authenticate(String token) async {
    final api = AlchemistApi(
      base,
      connection: connection,
      credential: () async => token,
    );
    final identity = await api.call('auth.whoami', {});
    if (!(identity['roles'] as List).any(
      (r) => r == 'owner' || r == 'author',
    )) {
      throw const DiaryApiException(
        'Нет авторских прав',
        DiaryFailure.authorization,
      );
    }
    final until = DateTime.fromMillisecondsSinceEpoch(
      (identity['expiresAt'] as int) * 1000,
      isUtc: true,
    );
    if (!until.isAfter(DateTime.now().toUtc())) {
      throw const DiaryApiException('Вход истёк');
    }
    _token = token;
    return DiaryAuthorSession.verified(token, until);
  }

  DiaryEntry _entry(Map<String, dynamic> result) {
    final raw = Map<String, dynamic>.from(result['entry']);
    raw['publication'] = result['publication'];
    return DiaryEntry.fromMap(raw);
  }

  @override
  Future<DiaryPage> feed({String? since, String? page}) async {
    final result = await public.call('feed.list', {
      'cursor': ?page,
      'limit': 50,
    });
    final entries = (result['entries'] as List)
        .map((v) => _entry(Map<String, dynamic>.from(v)))
        .where((e) => e.status == DiaryStatus.published)
        .toList();
    // Tombstones are explicit; absence from a page never implies deletion.
    final changes = await public.call('catalog.changes', {
      'sinceRevision': int.tryParse(since ?? '') ?? 0,
    });
    final removed = (changes['items'] as List)
        .where((v) => v['tombstone'] == true)
        .map((v) => v['catalogItemId'] as String)
        .where((id) => id.startsWith('entry_'))
        .map((id) => id.substring(6))
        .toSet();
    return DiaryPage(
      entries: entries,
      removedIds: removed,
      revision: result['revision'].toString(),
      nextPage: result['nextPage'],
    );
  }

  Future<Map<String, dynamic>> _state(String id) async {
    final row = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_entry:$id'],
    );
    return row.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(row.single['value'] as String));
  }

  Future<void> _save(String id, Map<String, dynamic> state) => db
      .insert('app_settings', {
        'name': 'alchemist_entry:$id',
        'value': jsonEncode(state),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<Map<String, dynamic>> _recover(
    String id,
    Map<String, dynamic> state,
  ) async {
    final p = state['pending'];
    final result = await author.call(
      p['operation'],
      Map<String, dynamic>.from(p['parameters']),
    );
    state['etag'] = result['etag'];
    state['remoteStatus'] = result['status'];
    state['manifest'] = result['entry'];
    state['publication'] = result['publication'];
    if (p['operation'] == 'entry.patchDraft' ||
        p['operation'] == 'entry.createDraft') {
      state['contentDirty'] = true;
    }
    if (p['operation'] == 'entry.publish') state['contentDirty'] = false;
    state.remove('pending');
    await _save(id, state);
    return result;
  }

  Future<Map<String, dynamic>> _mutate(
    String id,
    Map<String, dynamic> state,
    String op,
    Map<String, dynamic> parameters,
  ) async {
    state['pending'] = {
      'operation': op,
      'parameters': {
        'entryId': id,
        'requestId': newId(),
        if (state['etag'] != null) 'ifMatch': state['etag'],
        ...parameters,
      },
    };
    await _save(id, state);
    return _recover(id, state);
  }

  Future<Map<String, dynamic>> _document(DiaryEntry e) async {
    final blocks = <Map<String, dynamic>>[];
    for (final b in e.blocks) {
      if (b.type == DiaryBlockType.text) {
        blocks.add({'id': b.id, 'type': 'text', 'text': b.text});
        continue;
      }
      final m = b.media!, file = media.file(b.media);
      if (file == null || !await file.exists() || m.hash == null) {
        throw const FormatException('Вложение недоступно на телефоне');
      }
      final asset = await AlchemistMediaTransfer(db, author).upload(
        file,
        logicalId: m.assetId,
        revisionId: m.hash!,
        mime: m.mime,
        expectedHash: m.hash,
      );
      blocks.add({
        'id': b.id,
        'type': b.type.name,
        'mediaRef': {
          'logicalId': asset['logicalId'],
          'revisionId': asset['revisionId'],
          'sha256': asset['sha256'],
        },
        'label': b.label,
        'caption': b.caption,
        'altText': b.altText,
        'width': b.width,
        'height': b.height,
        'durationMs': b.durationMs,
      });
    }
    return {
      'id': e.id,
      'title': e.title,
      'message': e.message,
      'blocks': blocks,
      'publication': DiaryPublication.of(e).toMap(),
      'contentLinks': e.contentLinks.map((l) => l.toMap()).toList(),
      'order': e.order,
      'createdAt': e.createdAt.toUtc().toIso8601String(),
    };
  }

  Future<DiaryEntry> _saveRemote(DiaryEntry e, {required bool publish}) async {
    final queued = await _queued(e.id);
    final state = await _state(e.id);
    if (state['pending'] != null) await _recover(e.id, state);
    final document = await _document(e);
    final previous = state['manifest'];
    final beforeBlocks = previous is Map
        ? (previous['blocks'] as List).map((v) {
            final m = Map<String, dynamic>.from(v);
            m.remove('media');
            return m;
          }).toList()
        : null;
    final metadataOnly =
        previous is Map &&
        canonicalContent(beforeBlocks) ==
            canonicalContent(document['blocks']) &&
        canonicalContent(previous['contentLinks'] ?? []) ==
            canonicalContent(document['contentLinks']);
    final result = await _mutate(
      e.id,
      state,
      state['etag'] == null
          ? 'entry.createDraft'
          : metadataOnly
          ? 'entry.updateMetadata'
          : 'entry.patchDraft',
      metadataOnly
          ? {
              'title': e.title,
              'message': e.message,
              'publication': document['publication'],
              'order': e.order,
            }
          : {
              'entry': document,
              if (state['etag'] == null) 'visibility': 'public',
            },
    );
    if (!publish) {
      final local = _entry(result).copyWith(blocks: e.blocks, extra: e.extra);
      await _commitLocal(local, queued);
      return local;
    }
    final published =
        state['contentDirty'] == true || state['remoteStatus'] != 'published'
        ? await _mutate(e.id, state, 'entry.publish', {})
        : result;
    final verified = await author.call('entry.get', {'entryId': e.id});
    if (verified['etag'] != published['etag'] ||
        verified['status'] != 'published') {
      throw const FormatException('Сервер не подтвердил публикацию');
    }
    final local = _entry(verified).copyWith(
      blocks: e.blocks,
      extra: {...e.extra, 'publication': verified['publication']},
    );
    await _commitLocal(local, queued);
    return local;
  }

  @override
  Future<DiaryEntry> publish(
    DiaryEntry entry,
    DiaryAuthorSession session, {
    required bool published,
  }) async {
    final e = entry;
    if (!session.valid) throw const DiaryApiException('Вход истёк');
    if (published) return _saveRemote(e, publish: true);
    final state = await _state(e.id);
    if (state['pending'] != null) await _recover(e.id, state);
    final queued = await _queued(e.id);
    final local = _entry(await _mutate(e.id, state, 'entry.unpublish', {}))
        .copyWith(blocks: e.blocks, extra: e.extra);
    await _commitLocal(local, queued);
    return local;
  }

  @override
  Future<DiaryEntry> saveAuthorDraft(
    DiaryEntry entry,
    DiaryAuthorSession session,
  ) async {
    final e = entry;
    if (!session.valid) throw const DiaryApiException('Вход истёк');
    return _saveRemote(e, publish: false);
  }

  @override
  Future<List<DiaryEntry>> authorDrafts(DiaryAuthorSession session) async {
    if (!session.valid) throw const DiaryApiException('Вход истёк');
    final result = <DiaryEntry>[];
    String? cursor;
    do {
      final page = await author.call('feed.list', {
        'cursor': ?cursor,
        'limit': 50,
      });
      result.addAll(
        (page['entries'] as List).map(
          (v) => _entry(Map<String, dynamic>.from(v)),
        ),
      );
      cursor = page['nextPage'];
    } while (cursor != null);
    return result;
  }

  @override
  Future<void> deleteEntry(DiaryEntry entry, DiaryAuthorSession session) async {
    final e = entry;
    if (!session.valid) throw const DiaryApiException('Вход истёк');
    final state = await _state(e.id);
    if (state['pending'] != null) await _recover(e.id, state);
    await _mutate(e.id, state, 'entry.deleteSoft', {});
  }

  @override
  Future<void> reorderEntries(
    List<DiaryEntry> entries,
    DiaryAuthorSession session, {
    required String? expectedRevision,
  }) async {
    for (final e in entries) {
      await saveAuthorDraft(e, session);
    }
  }

  @override
  Future<void> enqueuePublication(DiaryEntry entry, {bool? published}) async {
    await db.insert('app_settings', {
      'name': 'alchemist_diary_queue:${entry.id}',
      'value': jsonEncode({
        'entry': entry.toMap(),
        'published': published,
        'status': 'pending',
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> _queued(String id) async {
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_diary_queue:$id'],
    );
    return rows.firstOrNull?['value'] as String?;
  }

  Future<void> _commitLocal(DiaryEntry result, String? queued) async {
    await db.transaction((tx) async {
      await tx.insert('diary_author', {
        'id': result.id,
        'updatedAt': result.updatedAt.toUtc().toIso8601String(),
        'payload': jsonEncode(result.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (queued != null) {
        await tx.delete(
          'app_settings',
          where: 'name=? AND value=?',
          whereArgs: ['alchemist_diary_queue:${result.id}', queued],
        );
      }
    });
  }

  @override
  Future<int> flushPending(DiaryAuthorSession session) async {
    var completed = 0;
    for (final row in await db.query(
      'app_settings',
      where: 'name LIKE ?',
      whereArgs: ['alchemist_diary_queue:%'],
    )) {
      final q = jsonDecode(row['value'] as String),
          entry = DiaryEntry.fromMap(Map<String, dynamic>.from(q['entry']));
      final result = q['published'] == null
          ? await saveAuthorDraft(entry, session)
          : await publish(entry, session, published: q['published']);
      await db.insert('diary_author', {
        'id': result.id,
        'updatedAt': result.updatedAt.toUtc().toIso8601String(),
        'payload': jsonEncode(result.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      completed++;
    }
    return completed;
  }

  Future<File?> resolveMedia(DiaryMedia m) async {
    if (m.hash == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(m.hash!)) {
      throw const FormatException('Нет контрольной суммы');
    }
    final api = _token == null ? public : author;
    final d = await api.call('media.getDescriptor', {
      'assetRevisionId': m.assetId,
    });
    if (d['sha256'] != m.hash ||
        d['mime'] != m.mime ||
        d['byteLength'] != m.bytes) {
      throw const FormatException('Описание медиа не совпало');
    }
    final source = await AlchemistInstall(capsules, api).downloadAsset(d);
    final target = media.file(m);
    if (target == null) {
      throw const FormatException('Неподдерживаемый формат медиа');
    }
    await media.directory.create(recursive: true);
    final temp = File('${target.path}.part');
    await source.copy(temp.path);
    await temp.rename(target.path);
    return target;
  }
}
