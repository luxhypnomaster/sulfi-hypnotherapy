import 'package:flutter/material.dart';

import '../data/content_revision_store.dart';
import '../models/content_link.dart';
import 'session_scope.dart';

/// Selects a real immutable registry key, never a title/latest alias or URL.
Future<ContentLink?> pickDiaryContent(BuildContext context) async {
  final scope = SessionScope.maybeOf(context);
  final database = scope?.controller.capsules?.database;
  if (database == null) return null;
  final revisions = await ContentRevisionStore(database).list();
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
