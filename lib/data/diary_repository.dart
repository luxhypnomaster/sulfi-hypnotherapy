import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';

/// Published cache and author work files are deliberately different tables.
class DiaryRepository {
  DiaryRepository(this.database);
  final Database database;
  Future<List<DiaryEntry>> published() async =>
      (await database.query(
            'diary_public',
            orderBy: 'publishedAt DESC, id DESC',
          ))
          .map(
            (r) => DiaryEntry.fromMap(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .where((e) => e.status == DiaryStatus.published)
          .toList();
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
        await tx.delete('diary_public', where: 'id=?', whereArgs: [id]);
      }
      for (final e in entries) {
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
  Future<List<DiaryEntry>> entries() async =>
      (await database.query('diary_author', orderBy: 'updatedAt DESC'))
          .map(
            (r) => DiaryEntry.fromMap(
              jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList();
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
