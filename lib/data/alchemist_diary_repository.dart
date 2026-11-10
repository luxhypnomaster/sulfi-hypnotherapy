import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import 'diary_repository.dart';

/// Public legacy cache is preserved. Restricted reader caches use independent
/// private SQLite namespaces and are invisible after logout/account switching.
class AlchemistDiaryRepository extends DiaryRepository {
  AlchemistDiaryRepository(super.database, {required this.scope});
  final String Function() scope;
  @override
  Future<List<DiaryEntry>> published() async {
    final entries = await super.published();
    if (scope() == 'public') return entries;
    for (final row in await database.query(
      'app_settings',
      where: 'name LIKE ?',
      whereArgs: ['alchemist_private_entry:%'],
    )) {
      try {
        final m = jsonDecode(row['value'] as String);
        if (m['scope'] == scope()) {
          final e = DiaryEntry.fromMap(Map<String, dynamic>.from(m['entry']));
          entries.removeWhere((old) => old.id == e.id);
          entries.add(e);
        }
      } catch (_) {
        invalidIds.add(row['name'] as String);
      }
    }
    return entries..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<String?> revision() async =>
      (await database.query(
            'app_settings',
            where: 'name=?',
            whereArgs: ['alchemist_reader_sync:${scope()}'],
          )).firstOrNull?['value']
          as String?;
  @override
  Future<void> cache(
    List<DiaryEntry> entries,
    Set<String> removed,
    String revision,
  ) async {
    final targetScope = scope();
    String key(String id) =>
        'alchemist_private_entry:${jsonEncode([targetScope, id])}';
    final public = entries
        .where((e) => e.extra['_alchemistScope'] == 'public')
        .toList();
    final private = entries
        .where(
          (e) =>
              e.extra['_alchemistScope'] == targetScope &&
              targetScope != 'public',
        )
        .toList();
    if (public.length + private.length != entries.length) {
      throw const FormatException('Неверная область читателя');
    }
    await super.cache(public, removed, revision);
    await database.transaction((tx) async {
      for (final id in removed) {
        await tx.delete('app_settings', where: 'name=?', whereArgs: [key(id)]);
      }
      for (final e in private) {
        await tx.insert('app_settings', {
          'name': key(e.id),
          'value': jsonEncode({'scope': targetScope, 'entry': e.toMap()}),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert('app_settings', {
        'name': 'alchemist_reader_sync:$targetScope',
        'value': revision,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
