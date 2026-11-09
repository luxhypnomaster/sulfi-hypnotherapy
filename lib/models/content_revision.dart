import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ContentType { track, module, template }

String canonicalContent(Object? value) {
  Object? sort(Object? v) => v is Map
      ? {
          for (final k in v.keys.map((k) => k.toString()).toList()..sort())
            k: sort(v[k]),
        }
      : v is List
      ? v.map(sort).toList()
      : v;
  return jsonEncode(sort(value));
}

String contentDigest(Object? value) =>
    sha256.convert(utf8.encode(canonicalContent(value))).toString();

class ContentKey {
  const ContentKey(this.type, this.id);
  final ContentType type;
  final String id;
  String get token => '${type.name}:$id';
}

class RevisionKey {
  const RevisionKey(this.content, this.revision, this.digest);
  final ContentKey content;
  final String revision, digest;
  String get token => '${content.token}:$revision';
  Map<String, dynamic> toMap() => {
    'type': content.type.name,
    'logicalId': content.id,
    'revision': revision,
    'digest': digest,
  };
  factory RevisionKey.fromMap(Map<String, dynamic> m) {
    final key = RevisionKey(
      ContentKey(ContentType.values.byName(m['type']), m['logicalId']),
      m['revision'].toString(),
      m['digest'],
    );
    if (key.content.id.isEmpty ||
        key.content.id.length > 512 ||
        key.revision.isEmpty ||
        key.revision.length > 128 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(key.digest)) {
      throw const FormatException('Некорректная точная ссылка');
    }
    return key;
  }
}

/// Content-addressed immutable snapshot. A digest proves integrity, not author
/// identity, payment, entitlement or a digital signature.
class ContentRevision {
  ContentRevision({
    required this.key,
    required this.payload,
    this.dependencies = const [],
    this.parent,
    this.declaredVersion,
  });
  final RevisionKey key;
  final Map<String, dynamic> payload;
  final List<RevisionKey> dependencies;
  final RevisionKey? parent;
  final int? declaredVersion;
  static ContentRevision create(
    ContentKey content,
    Map<String, dynamic> payload, {
    List<RevisionKey> dependencies = const [],
    RevisionKey? parent,
    int? declaredVersion,
  }) {
    final body = {
      'payload': payload,
      'dependencies': dependencies.map((d) => d.toMap()).toList(),
      'parent': parent?.toMap(),
      'declaredVersion': declaredVersion,
    };
    final hash = contentDigest(body);
    return ContentRevision(
      key: RevisionKey(content, hash, hash),
      payload: Map.unmodifiable(payload),
      dependencies: List.unmodifiable(dependencies),
      parent: parent,
      declaredVersion: declaredVersion,
    );
  }

  Map<String, dynamic> toMap() => {
    'schema': 1,
    ...key.toMap(),
    'payload': payload,
    'dependencies': dependencies.map((d) => d.toMap()).toList(),
    'parent': parent?.toMap(),
    'declaredVersion': declaredVersion,
  };
  factory ContentRevision.fromMap(Map<String, dynamic> m) {
    if (m['schema'] != 1) {
      throw const FormatException('Неизвестная схема материала');
    }
    final key = RevisionKey.fromMap(m);
    final value = ContentRevision.create(
      key.content,
      Map<String, dynamic>.from(m['payload']),
      dependencies: (m['dependencies'] as List)
          .map((d) => RevisionKey.fromMap(Map<String, dynamic>.from(d)))
          .toList(),
      parent: m['parent'] == null
          ? null
          : RevisionKey.fromMap(Map<String, dynamic>.from(m['parent'])),
      declaredVersion: m['declaredVersion'],
    );
    if (value.key.digest != key.digest || value.key.revision != key.revision) {
      throw const FormatException('Ревизия повреждена');
    }
    return value;
  }
  ContentRevision fork(String newId) {
    if (newId == key.content.id || newId.isEmpty) {
      throw ArgumentError('Личная копия требует нового ID');
    }
    return ContentRevision.create(
      ContentKey(key.content.type, newId),
      {...payload, 'id': newId, 'origin': 'personal'},
      dependencies: dependencies,
      parent: key,
      declaredVersion: 1,
    );
  }
}
