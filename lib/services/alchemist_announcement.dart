import '../models/content_link.dart';
import '../models/content_revision.dart';
import '../models/diary_entry.dart';
import '../models/session_plan.dart';
import 'alchemist_catalog.dart';

/// Exact references remain frozen; a repeated announcement is a new diary post.
Future<DiaryEntry> prepareCatalogAnnouncement(
  AlchemistCatalog catalog,
  Map<String, dynamic> draft,
) async {
  final diary = catalog.controller.diary!;
  final root = ContentRevision.fromMap(
    Map<String, dynamic>.from(draft['root']),
  );
  for (final e in await diary.authorRepository!.entries()) {
    if (e.status == DiaryStatus.draft &&
        e.extra['catalogItemId'] == draft['catalogItemId'] &&
        e.contentLinks.any((l) => l.key.token == root.key.token)) {
      return e;
    }
  }
  final card = draft['card'] as Map;
  final now = DateTime.now().toUtc();
  final entry = DiaryEntry(
    id: newId(),
    title: card['title'] as String,
    message: (card['shortAnnotation'] as String).isEmpty
        ? card['title'] as String
        : card['shortAnnotation'] as String,
    body: (card['description'] as String).isEmpty
        ? card['title'] as String
        : card['description'] as String,
    createdAt: now,
    updatedAt: now,
    extra: {
      'catalogItemId': draft['catalogItemId'],
      'catalogRevision': root.key.revision,
      'contentLinks': [
        ContentLink(root.key, ContentLinkAction.install).toMap(),
      ],
    },
  );
  await diary.saveDraft(entry);
  return entry;
}

Future<void> commitAnnouncementDependency(
  AlchemistCatalog catalog,
  DiaryEntry entry, {
  bool Function()? interrupted,
  void Function(String)? onStage,
  void Function(int, int)? progress,
}) async {
  final id = entry.extra['catalogItemId'];
  if (id == null) return;
  final draft = (await catalog.drafts())
      .where((d) => d['catalogItemId'] == id)
      .firstOrNull;
  if (draft == null) {
    throw const FormatException(
      'Карточка материала недоступна этому аккаунту.',
    );
  }
  final expected = entry.extra['catalogRevision'];
  final root = ContentRevision.fromMap(
    Map<String, dynamic>.from(draft['root']),
  );
  if (root.key.revision != expected ||
      !entry.contentLinks.any((l) => l.key.token == root.key.token)) {
    throw const FormatException(
      'Состав карточки изменился. Подготовьте анонс выбранной версии заново.',
    );
  }
  if (draft['card']['visibility'] != 'public') {
    throw const FormatException(
      'Для анонса читателям явно выберите «Для всех читателей» в карточке материала.',
    );
  }
  if ((draft['card']['shortAnnotation'] as String).trim().isEmpty) {
    draft['card']['shortAnnotation'] = entry.message;
    await catalog.save(draft);
  }
  await catalog.publish(
    draft,
    interrupted: interrupted,
    onStage: onStage,
    progress: progress,
  );
  if (draft['publishedRevision'] != expected ||
      draft['status'] != 'published') {
    throw const FormatException(
      'Точная версия материала не подтверждена. Анонс сохранён на телефоне.',
    );
  }
}
