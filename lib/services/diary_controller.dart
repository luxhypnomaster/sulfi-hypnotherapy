import 'package:flutter/foundation.dart';

import '../data/diary_repository.dart';
import '../models/diary_entry.dart';
import 'diary_api.dart';

class DiaryController extends ChangeNotifier {
  DiaryController(this.repository, {this.api, this.authorRepository});
  final DiaryRepository repository;
  final DiaryAuthorRepository? authorRepository;
  final DiaryApi? api;
  DiaryAuthorSession? _session;
  bool get authorWorkspace => authorRepository != null;
  bool get authenticated => _session?.valid ?? false;
  List<DiaryEntry> published = [], drafts = [];
  bool syncing = false;
  String? error;
  Future<void> load() async {
    published = await repository.published();
    if (authorRepository != null) drafts = await authorRepository!.entries();
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
    if (!authorWorkspace || api == null) {
      throw const DiaryApiException('Авторский сервер не настроен');
    }
    _session = await api!.authenticate(token);
    notifyListeners();
  }

  void logout() {
    _session = null;
    notifyListeners();
  }

  Future<void> publish(DiaryEntry entry, {required bool published}) async {
    if (!authorWorkspace || api == null || !authenticated) {
      throw const DiaryApiException(
        'Публикация требует настроенного сервера и авторизации автора',
      );
    }
    final result = await api!.publish(entry, _session!, published: published);
    await authorRepository!.save(result);
    await load();
    await sync(); // Reader receives only the public feed, never a local draft.
  }
}
