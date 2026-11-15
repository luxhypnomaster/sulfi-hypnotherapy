import 'alchemist_diagnostics.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'alchemist_errors.dart';

import '../models/diary_publication.dart';
import 'diary_read_state.dart';

import '../data/diary_repository.dart';
import '../models/diary_entry.dart';
import 'diary_api.dart';
import 'diary_identity.dart';
import 'diary_media_store.dart';
import 'diary_audio.dart';
import 'access_policy.dart';

class DiaryController extends ChangeNotifier {
  bool _closed = false;
  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  DiaryController(
    this.repository, {
    this.api,
    DiaryReadStore? reads,
    DateTime Function()? clock,
    this.policy,
    this.authorRepository,
    this.identity,
    this.mediaStore,
    this.audioFactory,
    this.allowDebugAuthor = false,
    this.authorEmail = 'luxhypnomaster@gmail.com',
  }) : reads = reads ?? DiaryReadStore(repository.database),
       clock = clock ?? DateTime.now {
    if (api?.supportsServerIdentity ?? false) {
      if (identity != null) api!.bindIdentity(identity!);
      policy?.applyVerifiedServerRole(api?.verifiedRole);
    }
  }
  final DiaryReadStore reads;
  final DateTime Function() clock;
  Timer? _expiry;
  String _readScope = 'public';
  VoidCallback? onAccountLogout;
  Future<void> Function()? beforeAccountLogout;
  Future<void> Function(DiaryEntry, bool?)? enqueueCloudOperation;
  Future<void> Function(DiaryEntry, String)? enqueueCloudMutation;
  bool get backgroundCloudTransfers => enqueueCloudOperation != null;
  int _rotation = 0;
  final _readerAudio = <String, DiaryAudio>{};
  final _heard = <String, HeardAudio>{};
  void rotateHome() {
    _rotation++;
    notifyListeners();
  }

  void refreshVisibility() {
    notifyListeners();
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final now = clock().toUtc();
    final ends =
        published
            .map(DiaryPublication.of)
            .where((p) => p.validUntil != null && p.validUntil!.isAfter(now))
            .map((p) => p.validUntil!)
            .toList()
          ..sort();
    if (ends.isNotEmpty) {
      _expiry = Timer(ends.first.difference(now), refreshVisibility);
    }
  }

  Future<void> textProgress(DiaryEntry e, int page, {bool end = false}) async {
    if (!reads.loaded) return;
    final wasRead = reads.isRead(e);
    await reads.progress(e, page: page, textEnd: end);
    if (wasRead != reads.isRead(e)) notifyListeners();
  }

  DiaryAudio? audioFor(DiaryEntry e, {bool preview = false}) {
    if (audioFactory == null) return null;
    if (preview || !reads.loaded) return audioFactory!();
    final key = '${reads.key(e)}:${reads.fingerprint(e)}';
    return _readerAudio.putIfAbsent(key, () {
      final audio = audioFactory!();
      audio.addListener(() {
        final latest = published.where((p) => p.id == e.id).firstOrNull;
        if (latest != null &&
            (DiaryPublication.of(latest).cycle !=
                    DiaryPublication.of(e).cycle ||
                reads.fingerprint(latest) != reads.fingerprint(e))) {
          return;
        }
        final id = audio.current;
        if (id == null) return;
        final block = e.blocks.where((b) => b.id == id).firstOrNull;
        if (block == null || block.type != DiaryBlockType.audio) return;
        final state = reads.state(e);
        final saved =
            state['fingerprint'] == reads.fingerprint(e) &&
                state['audio'] is Map
            ? state['audio'][id]
            : null;
        final heard = _heard.putIfAbsent(
          '$key:$id:${block.media?.hash}',
          () => HeardAudio(
            intervals: saved is Map
                ? (saved['intervals'] as List? ?? [])
                      .map((i) => List<int>.from(i))
                      .toList()
                : const [],
          ),
        );
        final done = heard.sample(
          position: audio.position.inMilliseconds,
          nowMs: clock().millisecondsSinceEpoch,
          playing: audio.playing,
          completed: audio.transport.completed,
          duration: audio.duration?.inMilliseconds ?? block.durationMs ?? 0,
          seekEpoch: audio.seekEpoch,
        );
        final wasRead = reads.isRead(e);
        unawaited(
          reads
              .progress(
                e,
                audioId: id,
                intervals: heard.intervals.map((i) => List<int>.of(i)).toList(),
                audioDone: done,
              )
              .then((_) {
                if (wasRead != reads.isRead(e)) notifyListeners();
              })
              .catchError((Object _) {}),
        );
      });
      return audio;
    });
  }

  bool ownsAudio(DiaryAudio? audio) => _readerAudio.values.contains(audio);

  @override
  void dispose() {
    _closed = true;
    _authGeneration++;
    _expiry?.cancel();
    for (final audio in _readerAudio.values) {
      unawaited(audio.close());
    }
    super.dispose();
  }

  final DiaryRepository repository;
  final AccessPolicy? policy;
  final DiaryAuthorRepository? authorRepository;
  final DiaryApi? api;
  final DiaryIdentity? identity;
  final String authorEmail;
  final DiaryMediaStore? mediaStore;
  final DiaryAudio Function()? audioFactory;
  final bool allowDebugAuthor;
  bool debugAuthor = false;
  bool hasCache = false;
  void enterDebugAuthor() {
    if (!kDebugMode ||
        !allowDebugAuthor ||
        (policy?.clientEdition ?? false) ||
        (api?.supportsServerIdentity ?? false)) {
      return;
    }
    debugAuthor = true;
    _localAuthor = true;
    notifyListeners();
  }

  DiaryEntry? get currentEntry {
    final list = diaryRotation(published, clock(), reads.isRead);
    return list.isEmpty ? null : list[_rotation % list.length];
  }

  Future<void> deleteEntry(DiaryEntry entry) async {
    if (!authorWorkspace) {
      throw const DiaryApiException('Авторский режим недоступен');
    }
    if (published.any((e) => e.id == entry.id) ||
        entry.status == DiaryStatus.published) {
      if (enqueueCloudMutation != null) {
        await enqueueCloudMutation!(entry, 'deleteSoft');
        // Keep the local copy until a server receipt; never optimistic delete.
        return;
      }
      final session = await _cloudSession();
      await api!.deleteEntry(entry, session);
      await sync();
      if (published.any((e) => e.id == entry.id)) {
        throw const DiaryApiException(
          'Удаление ещё не подтверждено синхронизацией',
        );
      }
    }
    await authorRepository!.remove(entry.id);
    await load();
  }

  Future<void> reorderEntries(List<DiaryEntry> entries) async {
    if (!authorWorkspace) {
      throw const DiaryApiException('Авторский режим недоступен');
    }
    if (enqueueCloudOperation != null) {
      // Persist explicit local ordering before creating per-entry transfer intents.
      // No UI-owned upload remains after this bounded database operation.
      await authorRepository!.reorder(entries);
      await load();
      for (final original in entries) {
        final e = drafts.where((e) => e.id == original.id).firstOrNull;
        if (e != null && published.any((p) => p.id == original.id)) {
          await enqueueCloudOperation!(e, null);
        }
      }
      return;
    }
    if (entries.any((e) => published.any((p) => p.id == e.id))) {
      final session = await _cloudSession();
      await api!.reorderEntries(
        entries,
        session,
        expectedRevision: await repository.revision(),
      );
      await sync();
      if (error != null) {
        throw const DiaryApiException(
          'Порядок не подтверждён. Обновите дневник.',
        );
      }
    }
    await authorRepository!.reorder(entries);
    await load();
  }

  DiaryAuthorSession? _session;
  bool _localAuthor = false;
  int _authGeneration = 0;
  bool authorBusy = false;
  bool get canSignIn =>
      identity != null &&
      ((api?.supportsServerIdentity ?? false) ||
          (authorRepository != null && (policy?.isAuthor ?? true)));
  bool get authorWorkspace =>
      authorRepository != null &&
      (!(api?.supportsServerIdentity ?? false) ||
          api?.verifiedRole != 'CLIENT') &&
      !(policy?.clientEdition ?? false) &&
      (policy != null || identity == null || _localAuthor);
  bool get authenticated => (api?.supportsServerIdentity ?? false)
      ? api!.readerAuthenticated
      : (_session?.valid ?? false);
  List<DiaryEntry> published = [], drafts = [];
  bool syncing = false;
  String? error;
  int _loadGeneration = 0;
  Future<void> load() async {
    final generation = ++_loadGeneration;
    await api?.loadLocalIdentityHint();
    final scope = api?.readerScope ?? 'public';
    if (scope != _readScope) {
      await reads.switchReader(scope == 'public' ? null : scope);
      _readScope = scope;
    }
    await reads.load();
    final nextPublished = await repository.published(),
        cached = await repository.revision();
    final workspace = authorWorkspace;
    final work = workspace ? await authorRepository!.entries() : <DiaryEntry>[];
    if (generation != _loadGeneration ||
        scope != (api?.readerScope ?? 'public')) {
      return;
    }
    final oldCycles = published
        .map((e) => '${e.id}:${DiaryPublication.of(e).cycle}')
        .toSet();
    if (nextPublished.any(
      (e) => !oldCycles.contains('${e.id}:${DiaryPublication.of(e).cycle}'),
    )) {
      _rotation = 0;
    }
    published = nextPublished;
    hasCache = cached != null;
    drafts = (api?.supportsServerIdentity ?? false)
        ? work
              .where(
                (e) =>
                    e.extra['_alchemistScope'] == 'local-device' ||
                    api!.canReadAuthorDraftScope(e.extra['_alchemistScope']),
              )
              .toList()
        : work;
    if (repository.invalidIds.isNotEmpty ||
        (workspace && authorRepository!.invalidIds.isNotEmpty)) {
      error = 'Некоторые записи не удалось прочитать. Исходные данные и вложения сохранены; остальные записи доступны.';
    }
    _scheduleExpiry();
    notifyListeners();
  }

  Future<void> sync({bool retrySnapshot = true}) async {
    if (syncing) return;
    if (api == null) {
      error = 'Облачный дневник ещё не настроен. Сохранённые публикации доступны офлайн.';
      notifyListeners();
      return;
    }
    final syncScope = api!.readerScope;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      final since = await repository.revision();
      String? page;
      String? revision;
      final seen = <String>{};
      final entries = <DiaryEntry>[];
      final removed = <String>{};
      do {
        final result = await api!.feed(since: since, page: page);
        if (revision != null && result.revision != revision) {
          if (retrySnapshot) {
            syncing = false;
            await sync(retrySnapshot: false);
            return;
          }
          throw const DiaryApiException(
            'Лента изменилась. Повторите обновление.',
          );
        }
        revision = result.revision;
        entries.addAll(result.entries);
        removed.addAll(result.removedIds);
        page = result.nextPage;
        if (page != null && (!seen.add(page) || seen.length > 100)) {
          throw const DiaryApiException('Ошибка страниц дневника');
        }
      } while (page != null);
      if (syncScope != api!.readerScope) return;
      await repository.cache(entries, removed, revision);
      await load();
      await api!.synchronizeReads(reads, published);
    } catch (e) {
      error = e is DiaryApiException ? e.message : 'Не удалось обновить дневник. Последний сохранённый каталог не изменён.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(DiaryEntry entry) async {
    if (!authorWorkspace) {
      throw const DiaryApiException('Авторский режим недоступен');
    }
    DiaryEntry.fromMap(
      entry.toMap(),
    ); // Validate before writing; failed drafts never poison stored JSON.
    if (api?.supportsServerIdentity ?? false) {
      final existing = (await authorRepository!.entries())
          .where((e) => e.id == entry.id)
          .firstOrNull;
      final scope =
          existing?.extra['_alchemistScope'] ?? entry.extra['_alchemistScope'];
      if (existing != null &&
          scope != 'local-device' &&
          !api!.canReadAuthorDraftScope(scope)) {
        throw const DiaryApiException(
          'Черновик принадлежит другому аккаунту.',
          DiaryFailure.authorization,
        );
      }
      entry = entry.copyWith(
        extra: {
          ...entry.extra,
          '_alchemistScope':
              scope ??
              (api!.readerScope == 'public'
                  ? 'local-device'
                  : api!.readerScope),
        },
      );
    }
    final localPublished = (await authorRepository!.entries())
        .where((e) => e.id == entry.id && e.status == DiaryStatus.published)
        .firstOrNull;
    final snapshot =
        published.where((e) => e.id == entry.id).firstOrNull ?? localPublished;
    if (snapshot != null) {
      entry = entry.copyWith(
        status: diaryEditFingerprint(entry) == diaryEditFingerprint(snapshot)
            ? DiaryStatus.published
            : DiaryStatus.draft,
      );
    }
    await authorRepository!.save(entry);
    await load();
  }

  Future<void> authenticate(String token) async {
    if (identity != null || !authorWorkspace || api == null) {
      throw const DiaryApiException('Авторский сервер не настроен');
    }
    _session = await api!.authenticate(token);
    notifyListeners();
  }

  Future<void>? _restoring;
  DiaryFailure? _restoreFailure;
  Future<void> restoreSignIn() {
    if (_restoring case final active?) return active;
    late final Future<void> pending;
    pending = _restoreSignIn().whenComplete(() {
      if (identical(_restoring, pending)) _restoring = null;
    });
    return _restoring = pending;
  }

  Future<void> _restoreSignIn() async {
    if (_closed) return;
    _restoreFailure = null;
    if (!(api?.supportsServerIdentity ?? false)) return;
    final optOut = await repository.database.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['alchemist_restore_disabled'],
    );
    if (optOut.firstOrNull?['value'] == '1' || api!.readerAuthenticated) return;
    final generation = _authGeneration;
    _restoreFailure = null;
    try {
      if (!await api!.restoreIdentity() || generation != _authGeneration) {
        return;
      }
      policy?.applyVerifiedServerRole(api!.verifiedRole);
      _localAuthor = api!.verifiedRole == 'MASTER';
      final token = await api!.verifiedIdentityToken();
      if (generation != _authGeneration) return;
      _session = _localAuthor && token != null
          ? DiaryAuthorSession.verified(token, api!.identityExpiresAt!)
          : null;
      await load();
    } catch (e) {
      // Network loss is not logout and does not delete authority/drafts.
      final failure = AlchemistFailure.from(e);
      _restoreFailure = failure.kind;
      error = failure.message;
      AlchemistDiagnostics.instance.stage(
        failure.kind == DiaryFailure.network
            ? 'SESSION_RESTORE_OFFLINE'
            : 'SESSION_RESTORE_ERROR',
      );
      notifyListeners();
    }
  }

  /// Uses the platform account chooser. Local editing and server permissions
  /// remain separate: a network failure never deletes the author's drafts.
  Future<void> signInAuthor() async {
    if (api?.supportsServerIdentity ?? false) {
      await restoreSignIn();
      if (api!.readerAuthenticated) return;
      if (_restoreFailure == DiaryFailure.network) {
        throw DiaryApiException(
          error ?? 'Сеть недоступна. Повторите позже.',
          DiaryFailure.network,
        );
      }
    }
    if (!canSignIn || authorBusy) {
      throw const DiaryApiException('Вход автора недоступен');
    }
    final generation = ++_authGeneration;
    if (!(api?.supportsServerIdentity ?? false)) api?.clearSession();
    if (api?.supportsServerIdentity ?? false) {
      // Hide the previous private workspace while an explicit account choice
      // is unverified. Ordinary transport failures never enter this path.
      policy?.applyVerifiedServerRole(null);
      drafts = [];
    }
    await beforeAccountLogout?.call();
    onAccountLogout?.call();
    published = published
        .where(
          (e) =>
              e.extra['_alchemistScope'] == null ||
              e.extra['_alchemistScope'] == 'public',
        )
        .toList();
    authorBusy = true;
    if (!(api?.supportsServerIdentity ?? false)) _session = null;
    notifyListeners();
    try {
      final result = await identity!.signIn();
      if (generation != _authGeneration) return;
      if (api?.supportsServerIdentity ?? false) {
        await api!.authenticateReader(result.idToken);
        api!.setAccountLabel(result.email);
        if (generation != _authGeneration) return;
        policy?.applyVerifiedServerRole(api!.verifiedRole);
        await repository.database.insert('app_settings', {
          'name': 'alchemist_restore_disabled',
          'value': '0',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        _localAuthor = api!.verifiedRole == 'MASTER';
        if (_localAuthor) {
          _session = DiaryAuthorSession.verified(
            result.idToken,
            api!.identityExpiresAt!,
          );
        }
        await load();
        if (generation != _authGeneration) return;
        // Pending work requires an explicit account-bound resume, never an
        // automatic upload of legacy/unowned drafts at sign-in.
        await sync();
        return;
      }
      if (result.email.toLowerCase() != authorEmail.toLowerCase()) {
        await identity!.signOut();
        throw const DiaryApiException(
          'Этот аккаунт не является автором дневника.',
        );
      }
      _localAuthor = true;
      await load();
      if (generation != _authGeneration) return;
      if (api == null) {
        error = 'Вы вошли как автор. Черновики сохраняются на телефоне; облачный сервер ещё не подключён.';
      } else {
        try {
          final session = await api!.authenticate(result.idToken);
          if (generation == _authGeneration) {
            _session = session;
            await load();
            try {
              await api!.flushPending(session);
              await load();
              error = api!.queueError;
            } catch (e) {
              error = 'Вход подтверждён. Очередь пока не отправлена: $e';
            }
          }
        } catch (_) {
          error = 'Вход Google выполнен. Облачный сервер не подтвердил доступ; локальные черновики доступны.';
        }
      }
    } finally {
      if (generation == _authGeneration) authorBusy = false;
      notifyListeners();
    }
  }

  Future<void> verifyGoogleRights() async {
    final token = await api?.verifiedIdentityToken();
    if (token == null) {
      throw const DiaryApiException(
        'Нужен Google-вход',
        DiaryFailure.authorization,
      );
    }
    // auth.whoami only; no pilot provisioning, ACL or server mutations.
    await api!.authenticateReader(token);
    policy?.applyVerifiedServerRole(api!.verifiedRole);
    _localAuthor = api!.verifiedRole == 'MASTER';
    await load();
  }

  Future<void> switchGoogleAccount() async {
    await logout();
    await signInAuthor();
  }

  Future<void> pauseReaders() async {
    for (final audio in _readerAudio.values) {
      await audio.pause();
    }
  }

  Future<void> logout() async {
    ++_authGeneration;
    ++_loadGeneration;
    await beforeAccountLogout?.call();
    authorBusy = false;
    _restoring = null;
    if (api?.supportsServerIdentity ?? false) {
      await repository.database.insert('app_settings', {
        'name': 'alchemist_restore_disabled',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    api?.clearSession();
    if (api?.supportsServerIdentity ?? false) {
      policy?.applyVerifiedServerRole(null);
    }
    published = published
        .where(
          (e) =>
              e.extra['_alchemistScope'] == null ||
              e.extra['_alchemistScope'] == 'public',
        )
        .toList();
    onAccountLogout?.call();
    _session = null;
    _localAuthor = false;
    debugAuthor = false;
    if (identity != null) drafts = [];
    error = null;
    notifyListeners();
    await pauseReaders();
    try {
      await identity?.signOut();
    } finally {
      await load();
    }
  }

  Future<DiaryAuthorSession> _cloudSession() async {
    if (api?.supportsServerIdentity ?? false) {
      if (authorBusy) {
        throw const DiaryApiException(
          'Выбор аккаунта ещё не завершён.',
          DiaryFailure.authorization,
        );
      }
      final token = await api!.verifiedIdentityToken();
      policy?.applyVerifiedServerRole(api!.verifiedRole);
      if (api!.verifiedRole != 'MASTER' ||
          policy?.isAuthor == false ||
          policy?.clientEdition == true ||
          token == null) {
        throw const DiaryApiException(
          'Сервер не разрешил публикацию для этой роли.',
          DiaryFailure.blocked,
        );
      }
      _session = DiaryAuthorSession.verified(token, api!.identityExpiresAt!);
      return _session!;
    }
    if (policy != null && !policy!.isAuthor) {
      throw const DiaryApiException(
        'В клиентском режиме доступны личные записи. Публикация авторских материалов запрещена.',
      );
    }
    if (debugAuthor || !authorWorkspace || api == null) {
      throw const DiaryApiException(
        'Облачный сервер ещё не подключён. Черновик сохранён на телефоне.',
      );
    }
    if (!authenticated && identity != null) await signInAuthor();
    if (!authenticated) {
      throw const DiaryApiException(
        'Сервер не подтвердил права автора. Войдите через Google заново.',
      );
    }
    return _session!;
  }

  Future<int> flushCloudQueue() async {
    final session = await _cloudSession();
    final completed = await api!.flushPending(session);
    await load();
    await sync();
    return completed;
  }

  Future<void> saveToCloud(DiaryEntry entry) async {
    if (enqueueCloudOperation != null) {
      await enqueueCloudOperation!(entry, null);
      return;
    }
    if (!(api?.supportsAdvancedPublication ?? false) &&
        (entry.extra.containsKey('contentLinks') ||
            entry.extra.containsKey('publication'))) {
      throw const DiaryApiException(
        'Ссылки на материалы пока сохраняются только локально. Серверный контракт не подтверждён.',
      );
    }
    await api?.enqueuePublication(entry);
    final session = await _cloudSession();
    final result = await api!.saveAuthorDraft(entry, session);
    await authorRepository!.save(result);
    await load();
  }

  /// Restore missing entries only; never silently overwrite local work.
  Future<int> restoreFromCloud() async {
    final session = await _cloudSession();
    final remote = await api!.authorDrafts(session);
    final local = (await authorRepository!.entries()).map((e) => e.id).toSet();
    final missing = remote.where((e) => !local.contains(e.id)).toList();
    await authorRepository!.saveAll(missing);
    await load();
    return missing.length;
  }

  Future<void> publish(DiaryEntry entry, {required bool published}) async {
    if (enqueueCloudOperation != null) {
      await enqueueCloudOperation!(entry, published);
      return;
    }
    if (!(api?.supportsAdvancedPublication ?? false) &&
        (entry.extra.containsKey('contentLinks') ||
            entry.extra.containsKey('publication'))) {
      throw const DiaryApiException(
        'Публикация ссылок на материалы пока недоступна. Локальная запись сохранена.',
      );
    }
    await api?.enqueuePublication(entry, published: published);
    final session = await _cloudSession();
    final result = await api!.publish(entry, session, published: published);
    await authorRepository!.save(result);
    await load();
    await sync(); // Reader receives only the public feed, never a local draft.
  }
}
