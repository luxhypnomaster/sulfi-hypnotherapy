import 'alchemist_work_queue.dart' show initialQueuedWork;
import 'alchemist_diagnostics.dart';
import 'diary_read_state.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'diary_identity.dart';
import 'alchemist_errors.dart';

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
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final CapsuleService capsules;
  final DiaryMediaStore media;
  final DiaryRequest? connection;
  Future<File> Function(Map<String, dynamic>, String?)? downloadInBackground;
  Future<void> Function(String)? enqueueReaderSync;
  String? _token;
  bool _identityRejected = false;
  @override
  void rejectIdentity() {
    _identityRejected = true;
  }

  Future<void> Function(DiaryEntry)? beforePublication;
  bool Function()? workInterrupted;
  void Function(String)? workStage;
  void Function(int, int)? workProgress;
  String? _queueError;
  @override
  String? get queueError => _queueError;
  String? _localScope, _localRole, _accountLabel;
  bool _hintLoaded = false;
  @override
  String? get accountLabel => _accountLabel;
  @override
  void setAccountLabel(String value) => _accountLabel = value;
  @override
  Future<void> loadLocalIdentityHint() async {
    if (_hintLoaded || _subject != null) return;
    final generation = _accountGeneration;
    final disabled = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_restore_disabled'],
    );
    if (disabled.firstOrNull?['value'] == '1') return;
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_identity_hint'],
    );
    if (generation != _accountGeneration || _subject != null) return;
    if (rows.isNotEmpty) {
      try {
        final hint = jsonDecode(rows.single['value'] as String);
        if (hint['role'] == 'MASTER' &&
            hint['scope'] is String &&
            RegExp(r'^account:[a-f0-9]{64}$').hasMatch(hint['scope'])) {
          _localScope = hint['scope'];
          _localRole = 'MASTER';
        }
      } catch (_) {
        /* Invalid hints never grant authority or erase data. */
      }
    }
    _hintLoaded = true;
  }

  String? _subject;
  String? _verifiedRole;
  DateTime? _identityExpiresAt;
  DiaryIdentity? _identity;
  Future<bool>? _refreshing;
  final DateTime Function() clock;
  @override
  void bindIdentity(DiaryIdentity identity) => _identity = identity;
  @override
  Future<bool> restoreIdentity() => _singleRefresh();
  Future<bool> _singleRefresh({bool force = false}) {
    if (_refreshing case final active?) return active;
    late final Future<bool> pending;
    pending = _restore(force: force).whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    return _refreshing = pending;
  }

  Future<bool> _restore({bool force = false}) async {
    AlchemistDiagnostics.instance.stage(
      force ? 'TOKEN_REFRESH_START' : 'SESSION_RESTORE_START',
    );
    final disabled = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_restore_disabled'],
    );
    if (disabled.firstOrNull?['value'] == '1') {
      AlchemistDiagnostics.instance.stage('SESSION_RESTORE_NEEDS_USER');
      return false;
    }
    if (!force &&
        readerAuthenticated &&
        _identityExpiresAt!.isAfter(
          clock().toUtc().add(const Duration(minutes: 1)),
        )) {
      return true;
    }
    await loadLocalIdentityHint();
    final identity = _identity;
    if (identity is! RestorableDiaryIdentity) return false;
    final generation = _accountGeneration,
        subject = _subject,
        previous = _token;
    final result = await (identity as RestorableDiaryIdentity).restore();
    if (generation != _accountGeneration) {
      throw const AlchemistFailure(
        'Аккаунт изменился. Передача приостановлена.',
        401,
        'ACCOUNT_CHANGED',
        DiaryFailure.authorization,
      );
    }
    if (result == null || force && result.idToken == previous) return false;
    await _verifyIdentity(
      result.idToken,
      expectedSubject: subject,
      expectedScope: readerScope == 'public' ? null : readerScope,
    );
    _accountLabel = result.email;
    AlchemistDiagnostics.instance.stage('SESSION_RESTORE_OK');
    return true;
  }

  Future<bool> _forceRefresh() => _singleRefresh(force: true);
  @override
  Future<void> refreshIdentity() async {
    await verifiedIdentityToken();
  }

  @override
  Future<bool> refreshRejectedIdentity() => _forceRefresh();

  @override
  bool get supportsServerIdentity => true;
  @override
  String? get verifiedRole => _verifiedRole;
  @override
  DateTime? get identityExpiresAt => _identityExpiresAt;
  @override
  bool get readerAuthenticated =>
      !_identityRejected &&
      _token != null &&
      (_identityExpiresAt?.isAfter(clock().toUtc()) ?? false);
  @override
  Future<String?> verifiedIdentityToken() async {
    if (_identityExpiresAt == null ||
        !_identityExpiresAt!.isAfter(
          clock().toUtc().add(const Duration(minutes: 1)),
        )) {
      if (await restoreIdentity()) return _token;
    }
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
  int get identityGeneration => _accountGeneration;
  @override
  String get readerScope => _subject == null
      ? (_localScope ?? 'public')
      : 'account:${sha256.convert(utf8.encode('alchemist:${base.toString()}:$_subject'))}';
  @override
  // APK24's server-restored drafts used google:<verified subject>. Accept that
  // exact legacy owner only after server verification; never rewrite the row or
  // broaden this alias to another Google account, guest, or client role.
  bool canReadAuthorDraftScope(Object? scope) =>
      (_verifiedRole == 'MASTER' &&
          _subject != null &&
          (super.canReadAuthorDraftScope(scope) ||
              scope == 'google:$_subject')) ||
      (_subject == null &&
          _localRole == 'MASTER' &&
          scope == _localScope &&
          _localScope != null);
  @override
  Future<void> authenticateReader(String token) async {
    await _verifyIdentity(token);
  }

  Future<void> _verifyIdentity(
    String token, {
    String? expectedSubject,
    String? expectedScope,
  }) async {
    var generation = _accountGeneration;
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
    if (!until.isAfter(clock().toUtc())) {
      throw const DiaryApiException('Вход истёк', DiaryFailure.authorization);
    }
    final verifiedScope =
        'account:${sha256.convert(utf8.encode('alchemist:${base.toString()}:${identity['subject']}'))}';
    if (expectedScope != null && verifiedScope != expectedScope ||
        expectedSubject != null && identity['subject'] != expectedSubject) {
      throw const AlchemistFailure(
        'Google выбрал другой аккаунт. Войдите явно перед продолжением.',
        401,
        'ACCOUNT_CHANGED',
        DiaryFailure.authorization,
      );
    }
    if (_subject != null && _subject != identity['subject']) {
      _accountGeneration++;
      generation =
          _accountGeneration; // Our verified switch, not a later logout.
    }
    AlchemistDiagnostics.instance.stage(
      role == 'MASTER' ? 'SERVER_WHOAMI_MASTER' : 'SERVER_WHOAMI_CLIENT',
    );
    _subject = identity['subject'] as String;
    _verifiedRole = role;
    _identityExpiresAt = until;
    _token = token;
    _identityRejected = false;
    _localScope = readerScope;
    _localRole = _verifiedRole;
    _hintLoaded = true;
    await db.insert('app_settings', {
      'name': 'alchemist_identity_hint',
      'value': jsonEncode({'scope': readerScope, 'role': _verifiedRole}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (generation != _accountGeneration) {
      throw const DiaryApiException(
        'Вход отменён выходом из аккаунта',
        DiaryFailure.authorization,
      );
    }
  }

  Database get db => capsules.database;
  AlchemistApi get public => AlchemistApi(base, connection: connection);
  AlchemistApi get author => AlchemistApi(
    base,
    connection: connection,
    identityScope: () => readerScope,
    identityEpoch: () => identityGeneration,
    credential: verifiedIdentityToken,
    onUnauthorized: _forceRefresh,
    onAuthenticationFailure: rejectIdentity,
  );
  @override
  bool get supportsAdvancedPublication => true;
  @override
  void clearSession() {
    _accountGeneration++;
    _refreshing = null;
    _token = null;
    _identityRejected = false;
    _subject = null;
    _localScope = null;
    _localRole = null;
    _accountLabel = null;
    _hintLoaded = false;
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

  void _checkEntryOwner(Map<String, dynamic> state) {
    if (workInterrupted?.call() == true ||
        state['ownerBinding'] != null &&
            state['ownerBinding'] != author.ownerBinding) {
      throw const DiaryApiException(
        'Аккаунт изменился. Задача приостановлена.',
        DiaryFailure.authorization,
      );
    }
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
    _checkEntryOwner(state);
    final p = state['pending'];
    if (p['attempted'] == true) {
      await author.reconcileUncertain(
        p['operation'],
        Map<String, dynamic>.from(p['parameters']),
      );
    }
    p['attempted'] = true;
    await _save(id, state);
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
    state['lastReceipt'] = {
      'operation': p['operation'],
      'requestId': p['parameters']['requestId'],
      'etag': result['etag'],
      'status': result['status'],
      'confirmedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
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
    _checkEntryOwner(state);
    state['ownerBinding'] = author.ownerBinding;
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

  Future<Map<String, dynamic>> _document(
    DiaryEntry e, {
    void Function()? check,
  }) async {
    check?.call();
    if (e.contentLinks.isNotEmpty) {
      for (final link in e.contentLinks) {
        check?.call();
        await author.call('catalog.resolveReference', {
          'logicalId': link.key.content.id,
          'revisionId': link.key.revision,
          'digest': link.key.digest,
        });
      }
    }
    final blocks = <Map<String, dynamic>>[];
    for (final b in e.blocks.where((b) => b.substantive)) {
      check?.call();
      if (workInterrupted?.call() == true) {
        throw const DiaryApiException(
          'Передача приостановлена.',
          DiaryFailure.network,
        );
      }
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
        interrupted: workInterrupted,
        onStage: workStage,
        progress: workProgress,
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
    final initialOwner = readerScope, initialGeneration = identityGeneration;
    if (publish) await beforePublication?.call(e);
    void check() {
      if (initialOwner != readerScope ||
          initialGeneration != identityGeneration ||
          workInterrupted?.call() == true) {
        throw const DiaryApiException(
          'Задача приостановлена.',
          DiaryFailure.authorization,
        );
      }
    }

    check();
    final queued = await _queued(e.id);
    final state = await _state(e.id);
    _checkEntryOwner(state);
    state['ownerBinding'] = author.ownerBinding;
    if (state['pending'] != null) await _recover(e.id, state);
    final document = await _document(e, check: check);
    check();
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
      final local = _entry(result).copyWith(
        blocks: e.blocks,
        extra: {...e.extra, '_alchemistScope': readerScope},
      );
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
      extra: {
        ...e.extra,
        '_alchemistScope': readerScope,
        'publication': verified['publication'],
      },
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
        .copyWith(
          blocks: e.blocks,
          extra: {...e.extra, '_alchemistScope': readerScope},
        );
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
    final samePending = state['pending']?['operation'] == 'entry.deleteSoft';
    if (state['pending'] != null) await _recover(e.id, state);
    final receipt = state['lastReceipt'];
    if (!samePending &&
        !(receipt is Map &&
            receipt['operation'] == 'entry.deleteSoft' &&
            receipt['etag'] == state['etag'])) {
      await _mutate(e.id, state, 'entry.deleteSoft', {});
    }
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

  String _publicationRevision(DiaryEntry entry, bool? published) {
    final editable = Map<String, dynamic>.from(jsonDecode(_editable(entry)))
      ..remove('version')
      ..remove('status');
    return sha256
        .convert(
          utf8.encode(
            canonicalContent({'entry': editable, 'published': published}),
          ),
        )
        .toString();
  }

  @override
  Future<void> enqueuePublication(DiaryEntry entry, {bool? published}) =>
      _enqueue(entry, published: published);
  @override
  Future<void> enqueueDurablePublication(DiaryEntry entry, {bool? published}) =>
      _enqueue(entry, published: published, durable: true);
  Future<void> _enqueue(
    DiaryEntry entry, {
    bool? published,
    bool durable = false,
    String? action,
  }) async {
    final owner = author.ownerBinding;
    if (owner == null) {
      throw const AlchemistFailure(
        'Подтвердите Google-аккаунт перед первой отправкой.',
        401,
        'IDENTITY_REQUIRED',
        DiaryFailure.authorization,
      );
    }
    final revision = action == null
        ? _publicationRevision(entry, published)
        : contentDigest({'entry': entry.toMap(), 'action': action});
    await db.transaction((tx) async {
      final name = 'alchemist_diary_queue:${entry.id}';
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      final old = rows.isEmpty
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(rows.single['value'] as String),
            );
      if (old != null && old['ownerBinding'] != owner) {
        throw const AlchemistFailure(
          'Задача принадлежит другому аккаунту.',
          401,
          'ACCOUNT_CHANGED',
          DiaryFailure.authorization,
        );
      }
      if (old != null &&
          (old['publicationRevision'] == revision ||
              old['status'] == 'complete' &&
                  old['confirmedRevision'] == revision)) {
        if (durable && old['_work'] == null) {
          old['_work'] = initialQueuedWork(
            old,
            owner,
            complete: old['status'] == 'complete',
          );
          await tx.update(
            'app_settings',
            {'value': jsonEncode(old)},
            where: 'name=?',
            whereArgs: [name],
          );
        }
        return;
      }
      if (old != null &&
          const [
            'running',
            'preparing',
            'pausing',
            'queued',
          ].contains(old['_work']?['phase'])) {
        throw const AlchemistFailure(
          'Сначала завершите текущую отправку редакции.',
          409,
          'REVISION_IN_FLIGHT',
        );
      }
      final value = <String, dynamic>{
        'ownerBinding': owner,
        'entry': entry.toMap(),
        'published': published,
        'requestedAction': ?action,
        'publicationRevision': revision,
        'status': 'pending',
        if (old?['_work'] != null) '_work': old!['_work'],
      };
      if (durable) value['_work'] = initialQueuedWork(value, owner);
      await tx.insert('app_settings', {
        'name': name,
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> enqueueDurableMutation(DiaryEntry entry, String action) {
    if (action != 'deleteSoft') {
      throw const FormatException('Неизвестное действие');
    }
    return _enqueue(entry, durable: true, action: action);
  }

  Future<void> sendQueued(
    String name, {
    required bool Function() interrupted,
    void Function(String)? onStage,
    void Function(int, int)? progress,
  }) async {
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    );
    if (rows.isEmpty) return;
    final q = Map<String, dynamic>.from(
      jsonDecode(rows.single['value'] as String),
    );
    if (q['ownerBinding'] == null ||
        q['ownerBinding'] != author.ownerBinding ||
        interrupted()) {
      throw const DiaryApiException(
        'Аккаунт задачи не подтверждён.',
        DiaryFailure.authorization,
      );
    }
    if (q['status'] == 'complete') return;
    final e = DiaryEntry.fromMap(Map<String, dynamic>.from(q['entry']));
    final current = await db.query(
      'diary_author',
      where: 'id=?',
      whereArgs: [e.id],
    );
    if (current.isNotEmpty &&
        _editable(
              DiaryEntry.fromMap(
                Map<String, dynamic>.from(
                  jsonDecode(current.single['payload'] as String),
                ),
              ),
            ) !=
            _editable(e)) {
      throw const DiaryApiException(
        'После постановки в очередь появились новые правки. Подтвердите отправку из редактора.',
        DiaryFailure.conflict,
      );
    }
    workInterrupted = interrupted;
    workStage = onStage;
    workProgress = progress;
    try {
      onStage?.call('diary_verifying');
      final identity = await verifiedIdentityToken();
      final session = DiaryAuthorSession.verified(
        identity!,
        identityExpiresAt!,
      );
      if (q['requestedAction'] == 'deleteSoft') {
        await deleteEntry(e, session);
        final state = await _state(e.id);
        final checked = await author.call('entry.get', {'entryId': e.id});
        if (checked['etag'] != state['etag'] ||
            checked['status'] != 'archived') {
          throw const FormatException('Удаление не подтверждено сервером');
        }
        // A confirmed remote archive does not erase the author's local text or media.
        await _commitLocal(
          e.copyWith(status: DiaryStatus.unpublished),
          await _queued(e.id),
        );
      } else if (q['published'] == null) {
        await saveAuthorDraft(e, session);
      } else {
        await publish(e, session, published: q['published']);
      }
    } finally {
      workInterrupted = null;
      workStage = null;
      workProgress = null;
    }
  }

  Future<String?> _queued(String id) async {
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_diary_queue:$id'],
    );
    final raw = rows.firstOrNull?['value'] as String?;
    if (raw != null && jsonDecode(raw)['status'] == 'complete') return null;
    return raw;
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
        final name = 'alchemist_diary_queue:${result.id}';
        final latest = await tx.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [name],
        );
        final sent = Map<String, dynamic>.from(jsonDecode(queued));
        if (latest.isNotEmpty) {
          final current = Map<String, dynamic>.from(
            jsonDecode(latest.single['value'] as String),
          );
          if (current['ownerBinding'] == sent['ownerBinding'] &&
              current['publicationRevision'] == sent['publicationRevision'] &&
              canonicalContent(current['entry']) ==
                  canonicalContent(sent['entry'])) {
            final serverState = await tx.query(
              'app_settings',
              where: 'name=?',
              whereArgs: ['alchemist_entry:${result.id}'],
            );
            if (serverState.isNotEmpty) {
              current['lastReceipt'] = jsonDecode(
                serverState.single['value'] as String,
              )['lastReceipt'];
            }
            current['status'] = conflict ? 'conflict_committed' : 'complete';
            current['confirmedRevision'] = _publicationRevision(
              result,
              current['published'] as bool?,
            );
            await tx.update(
              'app_settings',
              {'value': jsonEncode(current)},
              where: 'name=?',
              whereArgs: [name],
            );
          }
        }
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
      final q = jsonDecode(row['value'] as String);
      if (q['status'] == 'complete' || q['_work'] != null) continue;
      final entry = DiaryEntry.fromMap(Map<String, dynamic>.from(q['entry']));
      if (q['ownerBinding'] != null &&
          q['ownerBinding'] != author.ownerBinding) {
        continue;
      }
      if (q['ownerBinding'] == null && readerScope != 'public') continue;
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
    if (reads.localOnly) {
      return; // Preserve historical queue/rows; no new telemetry.
    }
    if (_token == null || reads.readerId != readerScope) return;
    final name = 'alchemist_read_sync_queue:$readerScope';
    final pending = (await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    )).firstOrNull;
    final previousSync = pending == null
        ? null
        : jsonDecode(pending['value'] as String);
    if (pending != null &&
        enqueueReaderSync != null &&
        previousSync['_work']?['phase'] != 'complete') {
      // A durable executor already owns this snapshot. Periodic feed/read sync
      // must not turn USER_PAUSED/CANCELED into an implicit Resume.
      if (previousSync['_work'] == null) await enqueueReaderSync!(name);
      return;
    }
    if (pending != null && enqueueReaderSync == null) {
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
    if (enqueueReaderSync != null) {
      await enqueueReaderSync!(name);
      return;
    }
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
    final source = downloadInBackground == null
        ? await AlchemistInstall(capsules, api).downloadAsset(d)
        : await downloadInBackground!(d, media.file(m)?.path);
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
