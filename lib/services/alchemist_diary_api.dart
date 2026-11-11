import 'diary_read_state.dart';

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
  String? _queueError;
  @override
  String? get queueError => _queueError;
  String? _subject;
  String? _verifiedRole;
  DateTime? _identityExpiresAt;
  @override
  bool get supportsServerIdentity => true;
  @override
  String? get verifiedRole => _verifiedRole;
  @override
  DateTime? get identityExpiresAt => _identityExpiresAt;
  @override
  bool get readerAuthenticated =>
      _token != null &&
      (_identityExpiresAt?.isAfter(DateTime.now().toUtc()) ?? false);
  @override
  Future<String?> verifiedIdentityToken() async {
    if (!readerAuthenticated) {
      throw const DiaryApiException(
        'Войдите через Google заново',
        DiaryFailure.authorization,
      );
    }
    return _token;
  }

  int _accountGeneration = 0;
  @override
  String get readerScope => _subject == null ? 'public' : 'google:$_subject';
  @override
  Future<void> authenticateReader(String token) async {
    clearSession();
    final generation = _accountGeneration;
    final identity = await AlchemistApi(
      base,
      connection: connection,
      credential: () async => token,
    ).call('auth.whoami', {});
    if (generation != _accountGeneration) {
      throw const DiaryApiException(
        'Вход отменён выходом из аккаунта',
        DiaryFailure.authorization,
      );
    }
    final roles = identity['roles'];
    final role =
        identity['role'] ??
        (roles is List && roles.contains('owner') ? 'MASTER' : 'CLIENT');
    final expires = identity['expiresAt'];
    if (!['MASTER', 'CLIENT'].contains(role) ||
        expires is! int ||
        identity['subject'] is! String ||
        (identity['subject'] as String).isEmpty) {
      throw const DiaryApiException(
        'Сервер не подтвердил роль',
        DiaryFailure.authorization,
      );
    }
    final until = DateTime.fromMillisecondsSinceEpoch(
      expires * 1000,
      isUtc: true,
    );
    if (!until.isAfter(DateTime.now().toUtc())) {
      throw const DiaryApiException('Вход истёк', DiaryFailure.authorization);
    }
    _subject = identity['subject'] as String;
    _verifiedRole = role;
    _identityExpiresAt = until;
    _token = token;
  }

  Database get db => capsules.database;
  AlchemistApi get public => AlchemistApi(base, connection: connection);
  AlchemistApi get author => AlchemistApi(
    base,
    connection: connection,
    identityScope: () => readerScope,
    credential: () async =>
        _token ?? (throw const DiaryApiException('Войдите через Google')),
  );
  @override
  bool get supportsAdvancedPublication => true;
  @override
  void clearSession() {
    _accountGeneration++;
    _token = null;
    _subject = null;
    _verifiedRole = null;
    _identityExpiresAt = null;
  }

  @override
  Future<DiaryAuthorSession> authenticate(String token) async {
    await authenticateReader(token);
    if (_verifiedRole != 'MASTER') {
      throw const DiaryApiException(
        'Нет прав мастера',
        DiaryFailure.authorization,
      );
    }
    return DiaryAuthorSession.verified(token, _identityExpiresAt!);
  }

  DiaryEntry _entry(Map<String, dynamic> result) {
    final raw = Map<String, dynamic>.from(result['entry']);
    raw['publication'] = result['publication'];
    raw['_alchemistScope'] = result['visibility'] == 'public'
        ? 'public'
        : readerScope;
    return DiaryEntry.fromMap(raw);
  }

  @override
  Future<DiaryPage> feed({String? since, String? page}) async {
    final scope = readerScope, generation = _accountGeneration;
    final result = await (_token == null ? public : author).call('feed.list', {
      'cursor': ?page,
      'limit': 50,
    });
    if (scope != readerScope || generation != _accountGeneration) {
      throw const DiaryApiException(
        'Аккаунт изменился. Обновите дневник.',
        DiaryFailure.authorization,
      );
    }
    final entries = (result['entries'] as List)
        .map((v) => _entry(Map<String, dynamic>.from(v)))
        .where((e) => e.status == DiaryStatus.published)
        .toList();
    // Tombstones are explicit; absence from a page never implies deletion.
    final removed = <String>{};
    if (page == null) {
      int? offset;
      int? snapshot;
      do {
        final changes = await (_token == null ? public : author).call(
          'catalog.changes',
          {
            'sinceRevision': int.tryParse(since ?? '') ?? 0,
            'offset': ?offset,
            'snapshotRevision': ?snapshot,
          },
        );
        snapshot = changes['revision'] as int;
        if (snapshot != result['revision']) {
          throw const DiaryApiException(
            'Снимок дневника изменился. Повторите обновление.',
            DiaryFailure.conflict,
          );
        }
        removed.addAll(
          (changes['items'] as List)
              .where((v) => v['tombstone'] == true)
              .map((v) => v['catalogItemId'] as String)
              .where((id) => id.startsWith('entry_'))
              .map((id) => id.substring(6)),
        );
        offset = changes['nextOffset'] as int?;
      } while (offset != null);
    }
    if (scope != readerScope || generation != _accountGeneration) {
      throw const DiaryApiException(
        'Аккаунт изменился. Обновите дневник.',
        DiaryFailure.authorization,
      );
    }
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
    if (e.contentLinks.isNotEmpty) {
      for (final link in e.contentLinks) {
        await author.call('catalog.resolveReference', {
          'logicalId': link.key.content.id,
          'revisionId': link.key.revision,
          'digest': link.key.digest,
        });
      }
    }
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
        'ownedOnly': true,
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

  String _editable(DiaryEntry e) => canonicalContent({
    'title': e.title,
    'version': e.version,
    'status': e.status.name,
    'message': e.message,
    'blocks': e.blocks.map((b) => b.toMap()).toList(),
    'order': e.order,
    'extra': {
      for (final v in e.extra.entries)
        if (v.key != '_alchemistScope') v.key: v.value,
    },
  });
  Future<void> _commitLocal(DiaryEntry result, String? queued) async {
    var conflict = false;
    await db.transaction((tx) async {
      if (queued != null) {
        final sent = DiaryEntry.fromMap(
          Map<String, dynamic>.from(jsonDecode(queued)['entry']),
        );
        final rows = await tx.query(
          'diary_author',
          where: 'id=?',
          whereArgs: [result.id],
        );
        if (rows.isNotEmpty) {
          final current = DiaryEntry.fromMap(
            Map<String, dynamic>.from(
              jsonDecode(rows.single['payload'] as String),
            ),
          );
          conflict = _editable(current) != _editable(sent);
        }
      }
      if (conflict) {
        await tx.insert('app_settings', {
          'name': 'alchemist_diary_conflict:${result.id}',
          'value': jsonEncode(result.toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await tx.insert('diary_author', {
          'id': result.id,
          'updatedAt': result.updatedAt.toUtc().toIso8601String(),
          'payload': jsonEncode(result.toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (queued != null) {
        await tx.delete(
          'app_settings',
          where: 'name=? AND value=?',
          whereArgs: ['alchemist_diary_queue:${result.id}', queued],
        );
      }
    });
    if (conflict) {
      throw const DiaryApiException(
        'Сохранённая версия отправлена на сервер. Более поздние правки остались на телефоне; проверьте конфликт.',
        DiaryFailure.conflict,
      );
    }
  }

  @override
  Future<int> flushPending(DiaryAuthorSession session) async {
    _queueError = null;
    var completed = 0;
    for (final row in await db.query(
      'app_settings',
      where: 'name LIKE ?',
      whereArgs: ['alchemist_diary_queue:%'],
    )) {
      final q = jsonDecode(row['value'] as String),
          entry = DiaryEntry.fromMap(Map<String, dynamic>.from(q['entry']));
      final current = await db.query(
        'diary_author',
        where: 'id=?',
        whereArgs: [entry.id],
      );
      if (current.isNotEmpty &&
          _editable(
                DiaryEntry.fromMap(
                  Map<String, dynamic>.from(
                    jsonDecode(current.single['payload'] as String),
                  ),
                ),
              ) !=
              _editable(entry)) {
        _queueError = 'В очереди есть запись с новыми локальными правками. Откройте её и подтвердите публикацию ещё раз.';
        q['status'] = 'localConflict';
        q['error'] = 'После постановки в очередь появились новые правки. Требуется явная повторная публикация.';
        await db.update(
          'app_settings',
          {'value': jsonEncode(q)},
          where: 'name=?',
          whereArgs: [row['name']],
        );
        continue;
      }
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

  @override
  Future<void> synchronizeReads(
    DiaryReadStore reads,
    List<DiaryEntry> entries,
  ) async {
    if (_token == null || reads.readerId != readerScope) return;
    final name = 'alchemist_read_sync_queue:$readerScope';
    final pending = (await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    )).firstOrNull;
    if (pending != null) {
      try {
        await author.call(
          'sync.push',
          Map<String, dynamic>.from(jsonDecode(pending['value'] as String)),
        );
      } on AlchemistApiException catch (e) {
        if (e.status != 412) rethrow;
      }
      await db.delete('app_settings', where: 'name=?', whereArgs: [name]);
    }
    final remote = await author.call('sync.pull', {'readerStateOnly': true});
    final state = remote['readerState'];
    for (final raw in state['entries'] as List) {
      final e = entries.where((e) => e.id == raw['entryId']).firstOrNull;
      if (e != null) await reads.mergeSynced(e, Map<String, dynamic>.from(raw));
    }
    final local = reads.syncSnapshot(entries),
        merged = <String, Map<String, dynamic>>{
          for (final raw in state['entries'] as List)
            '${raw['entryId']}:${raw['cycle']}': Map<String, dynamic>.from(raw),
          for (final raw in local) '${raw['entryId']}:${raw['cycle']}': raw,
        };
    final values = merged.values.toList();
    if (canonicalContent(values) == canonicalContent(state['entries'])) return;
    final q = {
      'requestId': newId(),
      'ifMatch': state['etag'],
      'entries': values,
    };
    await db.insert('app_settings', {
      'name': name,
      'value': jsonEncode(q),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await author.call('sync.push', q);
    await db.delete('app_settings', where: 'name=?', whereArgs: [name]);
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
