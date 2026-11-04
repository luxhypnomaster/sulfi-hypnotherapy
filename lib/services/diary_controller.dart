import 'package:flutter/foundation.dart';

import '../data/diary_repository.dart';
import '../models/diary_entry.dart';
import 'diary_api.dart';
import 'diary_identity.dart';

class DiaryController extends ChangeNotifier {
  DiaryController(
    this.repository, {
    this.api,
    this.authorRepository,
    this.identity,
    this.authorEmail = 'luxhypnomaster@gmail.com',
  });
  final DiaryRepository repository;
  final DiaryAuthorRepository? authorRepository;
  final DiaryApi? api;
  final DiaryIdentity? identity;
  final String authorEmail;
  DiaryAuthorSession? _session;
  bool _localAuthor = false;
  int _authGeneration = 0;
  bool authorBusy = false;
  bool get canSignIn => identity != null && authorRepository != null;
  bool get authorWorkspace =>
      authorRepository != null && (identity == null || _localAuthor);
  bool get authenticated => _session?.valid ?? false;
  List<DiaryEntry> published = [], drafts = [];
  bool syncing = false;
  String? error;
  Future<void> load() async {
    published = await repository.published();
    final work = authorWorkspace
        ? await authorRepository!.entries()
        : <DiaryEntry>[];
    drafts = authorWorkspace ? work : [];
    notifyListeners();
  }

  Future<void> sync() async {
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
    } catch (_) {
      error = 'Не удалось обновить дневник. Сохранённые публикации доступны офлайн.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(DiaryEntry entry) async {
    if (!authorWorkspace) {
      throw const DiaryApiException('Авторский режим недоступен');
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
    if (identity != null) drafts = [];
    error = null;
    notifyListeners();
    await identity?.signOut();
  }

  Future<DiaryAuthorSession> _cloudSession() async {
    if (!authorWorkspace || api == null) {
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
    final session = await _cloudSession();
    final result = await api!.publish(entry, session, published: published);
    await authorRepository!.save(result);
    await load();
    await sync(); // Reader receives only the public feed, never a local draft.
  }
}
