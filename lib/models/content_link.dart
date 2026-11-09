import 'content_revision.dart';

enum ContentLinkAction { install, open }

/// Structured exact content reference, never a URL or a diary media block.
class ContentLink {
  const ContentLink(this.key, this.action, {this.extra = const {}});
  final RevisionKey key;
  final ContentLinkAction action;
  final Map<String, dynamic> extra;
  Map<String, dynamic> toMap() => {
    ...extra,
    ...key.toMap(),
    'action': action.name,
  };
  factory ContentLink.fromMap(Map<String, dynamic> map) => ContentLink(
    RevisionKey.fromMap(map),
    ContentLinkAction.values.byName(map['action']),
    extra: {
      for (final e in map.entries)
        if (!{
          'type',
          'logicalId',
          'revision',
          'digest',
          'action',
        }.contains(e.key))
          e.key: e.value,
    },
  );
}
