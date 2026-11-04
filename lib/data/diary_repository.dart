import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';

/// Published cache and author work files are deliberately different tables.
class DiaryRepository {
  DiaryRepository(this.database);
  final Database database;
  final invalidIds = <String>[];
  Future<List<DiaryEntry>> published() async {
    invalidIds.clear();
    return (await database.query(
          'diary_public',
          orderBy: 'publishedAt DESC, id DESC',
        ))
        .expand((r) => _decodeRow(r, invalidIds))
        .where((e) => e.status == DiaryStatus.published)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<String?> revision() async =>
      (await database.query(
            'diary_sync',
            where: 'id=1',
          )).firstOrNull?['revision']
          as String?;
  Future<void> cache(
    List<DiaryEntry> entries,
    Set<String> removed,
    String revision,
  ) async {
    if (entries.any(
      (e) => e.status != DiaryStatus.published || e.publishedAt == null,
    )) {
      throw const FormatException('Непубличная запись в ленте');
    }
    await database.transaction((tx) async {
      for (final id in removed) {
        final old = await tx.query(
          'diary_public',
          columns: ['version'],
          where: 'id=?',
          whereArgs: [id],
        );
        final tomb = await tx.query(
          'diary_removed',
          where: 'id=?',
          whereArgs: [id],
        );
        final version =
            old.firstOrNull?['version'] as int? ??
            tomb.firstOrNull?['version'] as int? ??
            0;
        await tx.insert('diary_removed', {
          'id': id,
          'version': version,
          'revision': revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.delete('diary_public', where: 'id=?', whereArgs: [id]);
      }
      for (final e in entries) {
        if (removed.contains(e.id)) continue;
        final tomb = await tx.query(
          'diary_removed',
          where: 'id=?',
          whereArgs: [e.id],
        );
        if (tomb.isNotEmpty && (tomb.first['version'] as int) >= e.version) {
          continue;
        }
        final existing = await tx.query(
          'diary_public',
          columns: ['version'],
          where: 'id=?',
          whereArgs: [e.id],
        );
        if (existing.isNotEmpty &&
            (existing.first['version'] as int) > e.version) {
          continue;
        }
        await tx.insert('diary_public', {
          'id': e.id,
          'version': e.version,
          'publishedAt': e.publishedAt!.toUtc().toIso8601String(),
          'payload': jsonEncode(e.toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert('diary_sync', {
        'id': 1,
        'revision': revision,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

/// Private work files. Only an authenticated author may expose them in the UI.
class DiaryAuthorRepository {
  DiaryAuthorRepository(this.database);
  final Database database;
  final invalidIds = <String>[];
  Future<List<DiaryEntry>> entries() async {
    invalidIds.clear();
    return (await database.query(
        'diary_author',
        orderBy: 'updatedAt DESC',
      )).expand((r) => _decodeRow(r, invalidIds)).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> save(DiaryEntry e) => database
      .insert('diary_author', {
        'id': e.id,
        'updatedAt': e.updatedAt.toUtc().toIso8601String(),
        'payload': jsonEncode(e.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<void> saveAll(List<DiaryEntry> entries) =>
      database.transaction((tx) async {
        for (final e in entries) {
          await tx.insert('diary_author', {
            'id': e.id,
            'updatedAt': e.updatedAt.toUtc().toIso8601String(),
            'payload': jsonEncode(e.toMap()),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      });
}

/// One SQLite transaction; numbers/dates and media references are untouched.
extension DiaryAuthorOperations on DiaryAuthorRepository {
  Future<void> remove(String id) async {
    await database.delete('diary_author', where: 'id=?', whereArgs: [id]);
  }

  Future<void> reorder(List<DiaryEntry> entries) =>
      database.transaction((tx) async {
        for (var i = 0; i < entries.length; i++) {
          final e = entries[i].copyWith(order: i);
          await tx.update(
            'diary_author',
            {'payload': jsonEncode(e.toMap())},
            where: 'id=?',
            whereArgs: [e.id],
          );
        }
      });
}

Iterable<DiaryEntry> _decodeRow(
  Map<String, Object?> row,
  List<String> invalid,
) {
  try {
    return [
      DiaryEntry.fromMap(
        jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      ),
    ];
  } catch (_) {
    invalid.add(row['id'].toString());
    return const [];
  }
}
