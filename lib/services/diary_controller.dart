import 'dart:async';

import 'package:flutter/foundation.dart';

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
       clock = clock ?? DateTime.now;
  final DiaryReadStore reads;
  final DateTime Function() clock;
  Timer? _expiry;
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
    if (!kDebugMode || !allowDebugAuthor || (policy?.clientEdition ?? false)) {
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
      authorRepository != null &&
      (policy?.isAuthor ?? true);
  bool get authorWorkspace =>
      authorRepository != null &&
      !(policy?.clientEdition ?? false) &&
      (policy != null || identity == null || _localAuthor);
  bool get authenticated => _session?.valid ?? false;
  List<DiaryEntry> published = [], drafts = [];
  bool syncing = false;
  String? error;
  Future<void> load() async {
    await reads.load();
    final oldCycles = published
        .map((e) => '${e.id}:${DiaryPublication.of(e).cycle}')
        .toSet();
    published = await repository.published();
    if (published.any(
      (e) => !oldCycles.contains('${e.id}:${DiaryPublication.of(e).cycle}'),
    )) {
      _rotation = 0;
    }
    hasCache = await repository.revision() != null;
    final work = authorWorkspace
        ? await authorRepository!.entries()
        : <DiaryEntry>[];
    drafts = authorWorkspace ? work : [];
    if (repository.invalidIds.isNotEmpty ||
        (authorWorkspace && authorRepository!.invalidIds.isNotEmpty)) {
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
      await repository.cache(entries, removed, revision);
      await load();
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

  /// Uses the platform account chooser. Local editing and server permissions
  /// remain separate: a network failure never deletes the author's drafts.
  Future<void> signInAuthor() async {
    if (!canSignIn || authorBusy) {
      throw const DiaryApiException('Вход автора недоступен');
    }
    final generation = ++_authGeneration;
    authorBusy = true;
    _session = null;
    notifyListeners();
    try {
      final result = await identity!.signIn();
      if (generation != _authGeneration) return;
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
          if (generation == _authGeneration) _session = session;
          error = null;
        } catch (_) {
          error = 'Вход Google выполнен. Облачный сервер не подтвердил доступ; локальные черновики доступны.';
        }
      }
    } finally {
      authorBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    ++_authGeneration;
    _session = null;
    _localAuthor = false;
    debugAuthor = false;
    if (identity != null) drafts = [];
    error = null;
    notifyListeners();
    await identity?.signOut();
  }

  Future<DiaryAuthorSession> _cloudSession() async {
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

  Future<void> saveToCloud(DiaryEntry entry) async {
    if (entry.extra.containsKey('contentLinks') ||
        entry.extra.containsKey('publication')) {
      throw const DiaryApiException(
        'Ссылки на материалы пока сохраняются только локально. Серверный контракт не подтверждён.',
      );
    }
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
    if (entry.extra.containsKey('contentLinks') ||
        entry.extra.containsKey('publication')) {
      throw const DiaryApiException(
        'Публикация ссылок на материалы пока недоступна. Локальная запись сохранена.',
      );
    }
    final session = await _cloudSession();
    final result = await api!.publish(entry, session, published: published);
    await authorRepository!.save(result);
    await load();
    await sync(); // Reader receives only the public feed, never a local draft.
  }
}
