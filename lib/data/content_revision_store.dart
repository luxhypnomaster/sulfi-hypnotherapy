import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';

/// Append-only retention. No UPDATE, DELETE or automatic rebase of a run.
class ContentRevisionStore {
  ContentRevisionStore(this.database);
  final DatabaseExecutor database;
  Future<void> put(ContentRevision revision) async {
    // Round-trip validates the caller's object before persisting immutable bytes.
    final verified = ContentRevision.fromMap(revision.toMap());
    final existing = await get(verified.key);
    if (existing != null) {
      if (canonicalContent(existing.toMap()) !=
          canonicalContent(verified.toMap())) {
        throw StateError('Конфликт неизменяемой ревизии');
      }
      return;
    }
    await database.insert('content_revisions', {
      'id': verified.key.token,
      'payload': canonicalContent(verified.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<ContentRevision?> get(RevisionKey key) async {
    final rows = await database.query(
      'content_revisions',
      where: 'id=?',
      whereArgs: [key.token],
    );
    if (rows.isEmpty) return null;
    final result = ContentRevision.fromMap(
      jsonDecode(rows.single['payload'] as String),
    );
    if (result.key.digest != key.digest) {
      throw const FormatException('Конфликт digest точной ссылки');
    }
    return result;
  }

  Future<List<ContentRevision>> list() async =>
      (await database.query('content_revisions'))
          .map(
            (r) => ContentRevision.fromMap(jsonDecode(r['payload'] as String)),
          )
          .toList();

  static Future<void> retainRow(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
  ) async {
    final revision = revisionForRow(table, row);
    if (revision != null) await ContentRevisionStore(db).put(revision);
  }

  static ContentRevision? revisionForRow(
    String table,
    Map<String, Object?> row,
  ) {
    final type = switch (table) {
      'audio_assets' => ContentType.track,
      'module_definitions' => ContentType.module,
      'session_templates' => ContentType.template,
      _ => null,
    };
    if (type == null) return null;
    final payload = table == 'audio_assets'
        ? Map<String, dynamic>.from(row)
        : Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
    // Portable blob descriptor. Paths are never a revision identity or authority.
    if (type == ContentType.track) {
      payload['filePath'] = payload['contentHash'] == null
          ? null
          : 'capsule://${payload['contentHash']}';
    }
    return ContentRevision.create(
      ContentKey(type, row['id'] as String),
      payload,
      declaredVersion: type == ContentType.track
          ? payload['baseRevision']
          : payload['version'],
      parent: payload['parentRevision'] == null
          ? null
          : RevisionKey.fromMap(
              Map<String, dynamic>.from(payload['parentRevision']),
            ),
    );
  }
}
