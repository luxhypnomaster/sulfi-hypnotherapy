import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import 'access_policy.dart';
import 'diary_contract_provider.dart';

/// Local offline contract queue only. No automatic live connection or rebasing.
class DiaryContractOutbox {
  DiaryContractOutbox(this.db, this.policy);
  final Database db;
  final AccessPolicy policy;
  Future<void> enqueue(
    DiaryEntry e, {
    required String ifMatch,
    required String requestId,
  }) async {
    if (!policy.isAuthor) throw ContractFailure(403);
    final value = jsonEncode({
      'entry': e.toMap(),
      'ifMatch': ifMatch,
      'requestId': requestId,
    });
    final name = 'diary_contract_outbox:$requestId';
    final existing = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    );
    if (existing.isNotEmpty && existing.single['value'] != value) {
      throw ContractFailure(409);
    }
    await db.insert('app_settings', {
      'name': name,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> flush(DiaryContractProvider provider) async {
    if (!policy.isAuthor) throw ContractFailure(403);
    var count = 0;
    for (final row in await db.query(
      'app_settings',
      where: 'name LIKE ?',
      whereArgs: ['diary_contract_outbox:%'],
      orderBy: 'name',
    )) {
      final m = jsonDecode(row['value'] as String);
      await provider.publish(
        DiaryEntry.fromMap(Map<String, dynamic>.from(m['entry'])),
        ifMatch: m['ifMatch'],
        idempotencyKey: m['requestId'],
      );
      await db.delete(
        'app_settings',
        where: 'name=?',
        whereArgs: [row['name']],
      );
      count++;
    }
    return count;
  }
}
