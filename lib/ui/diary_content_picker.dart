import 'package:flutter/material.dart';

import '../data/content_revision_store.dart';
import '../models/content_link.dart';
import '../models/content_revision.dart';
import 'session_scope.dart';
import '../services/local_content_catalog.dart';

/// Selects a real immutable registry key, never a title/latest alias or URL.
Future<ContentLink?> pickDiaryContent(BuildContext context) async {
  if (SessionScope.maybeOf(context)
          ?.controller
          .diary
          ?.api
          ?.supportsServerIdentity ??
      false) {
    return pickPublishedDiaryContent(context);
  }
  final scope = SessionScope.maybeOf(context);
  final service = scope?.controller.capsules;
  if (service == null) return null;
  final revisions = await LocalCatalogSource.currentIndex(service);
  // Retain exact keys and their dependencies; no current object or file mutation.
  for (final r in revisions) {
    await ContentRevisionStore(service.database).put(r);
  }
  if (!context.mounted) return null;
  return showDialog<ContentLink>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Материал из библиотеки'),
      children: [
        if (revisions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Сначала добавьте материал в библиотеку.'),
          ),
        for (final r in revisions)
          SimpleDialogOption(
            key: ValueKey('link-${r.key.token}'),
            onPressed: () => Navigator.pop(
              context,
              ContentLink(r.key, ContentLinkAction.install),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.payload['title'] ?? r.payload['name'] ?? r.key.content.id} · ${r.key.content.type.name}',
                ),
                Text(
                  '${r.key.revision} · ${r.key.digest.substring(0, 12)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Future<ContentLink?> pickPublishedDiaryContent(BuildContext context) async {
  final controller = SessionScope.maybeOf(context)?.controller;
  if (controller == null) return null;
  final api = controller.alchemistApi(authenticated: false);
  final items = <Map<String, dynamic>>[], seen = <String>{};
  String? cursor;
  do {
    final page = await api.call('catalog.list', {
      'readerView': true,
      'limit': 50,
      'cursor': ?cursor,
    });
    for (final value in page['items'] as List) {
      final card = Map<String, dynamic>.from(value);
      if (['track', 'module', 'template'].contains(card['type'])) {
        items.add(card);
      }
    }
    cursor = page['nextPage'] as String?;
    if (cursor != null && (!seen.add(cursor) || seen.length > 100)) {
      throw const FormatException('Ошибка страниц каталога');
    }
  } while (cursor != null);
  if (!context.mounted) return null;
  final selected = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Материал из опубликованного каталога'),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Сначала опубликуйте трек, модуль или шаблон в каталоге.',
            ),
          ),
        for (final card in items)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, card),
            child: Text('${card['card']['title']} · ${card['type']}'),
          ),
      ],
    ),
  );
  if (selected == null) return null;
  final revision = selected['immutableRevisionId'] as String;
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(revision)) {
    throw const FormatException('Некорректная ревизия каталога');
  }
  await api.call('catalog.resolveReference', {
    'logicalId': selected['logicalContentId'],
    'revisionId': revision,
    'digest': revision,
  });
  final type = ContentType.values.singleWhere(
    (t) => t.name == selected['type'],
  );
  return ContentLink(
    RevisionKey(
      ContentKey(type, selected['logicalContentId']),
      revision,
      revision,
    ),
    ContentLinkAction.install,
  );
}
