import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/content_revision.dart';
import '../models/session_plan.dart' show newId;
import '../models/vitrine_config.dart';
import 'alchemist_work_queue.dart';

/// Negotiated v1 metadata transport. No production GAS6 route is assumed.
abstract interface class CatalogSnapshotTransport {
  Future<Map<String, dynamic>> head(String scope);
  Future<Map<String, dynamic>> snapshot(String scope, String id);
}

/// Metadata uses the EXISTING download job namespace/executor, not a new queue.
/// Caller must provide a server-verified account binding (never email/edition).
class CatalogSnapshotSync extends ChangeNotifier {
  CatalogSnapshotSync({
    required this.db,
    required this.transport,
    required this.owner,
    this.deadline = const Duration(seconds: 30),
  });
  final Database db;
  final CatalogSnapshotTransport transport;
  final String? Function() owner;
  final Duration deadline;
  String _key(String account, String scope) =>
      'catalog20:${contentDigest([account, scope])}';

  /// Local-only, immediate lastGood read, with checksum revalidation on restart.
  Future<Map<String, dynamic>?> lastGood(String scope) async {
    final account = owner();
    if (account == null) return null;
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['${_key(account, scope)}:current'],
    );
    if (account != owner() || rows.isEmpty) return null;
    final value = Map<String, dynamic>.from(
      jsonDecode(rows.single['value'] as String),
    );
    verify(value['head'], value['snapshot'], scope);
    return value;
  }

  Future<String> request(String scope, AlchemistWorkQueue queue) async {
    final account = owner();
    if (account == null) throw const FormatException('WAITING_AUTH');
    final name =
        'alchemist_download:$account:catalog20:${contentDigest(scope)}';
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      if (rows.isNotEmpty) {
        final old = jsonDecode(rows.single['value'] as String);
        // Coalesce even after process death. USER_PAUSED is never auto-resumed.
        if (!const [
          'complete',
          'failed',
          'failed_permanent',
          'cancelled',
        ].contains(old['_work']?['phase'])) {
          return;
        }
      }
      final row = <String, dynamic>{
        'ownerBinding': account,
        'download': {
          'kind': 'catalogSnapshot20',
          'scope': scope,
          'intentId': newId(),
        },
      };
      row['_work'] = initialQueuedWork(row, account);
      await tx.insert('app_settings', {
        'name': name,
        'value': jsonEncode(row),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    // Dispatch existing pump, but don't override a deliberate user pause.
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    );
    final work = jsonDecode(rows.single['value'] as String)['_work'];
    if (work['phase'] == 'queued') await queue.enqueue(name);
    return name;
  }

  Future<void> execute(Map<String, dynamic> row, bool Function() stop) async {
    final account = owner(), scope = row['download']['scope'] as String;
    bool invalid() =>
        stop() ||
        account == null ||
        account != owner() ||
        row['ownerBinding'] != account;
    if (invalid()) throw const FormatException('ACCOUNT_CHANGED');
    final key = _key(account!, scope);
    final head = await transport.head(scope).timeout(deadline);
    if (invalid()) throw const FormatException('ACCOUNT_CHANGED');
    if (head['schemaVersion'] != 1 ||
        head['scope'] != scope ||
        head['catalogRevision'] is! int ||
        head['catalogRevision'] < 1) {
      throw const FormatException('UNSUPPORTED_HEAD');
    }
    final old = await lastGood(scope);
    if (old != null &&
        head['catalogRevision'] < old['head']['catalogRevision']) {
      return;
    }
    if (old != null &&
        head['catalogRevision'] == old['head']['catalogRevision']) {
      if (head['snapshotHash'] != old['head']['snapshotHash'] ||
          head['snapshotId'] != old['head']['snapshotId']) {
        throw const FormatException('REVISION_CONFLICT');
      }
      return; // unchanged HEAD: exactly zero full snapshot requests.
    }
    final snapshot = await transport
        .snapshot(scope, head['snapshotId'] as String)
        .timeout(deadline);
    verify(head, snapshot, scope);
    if (invalid()) throw const FormatException('ACCOUNT_CHANGED');
    final value = jsonEncode({'head': head, 'snapshot': snapshot});
    // Prepared bytes survive interruption; no file/library/SessionRun mutation.
    await db.insert('app_settings', {
      'name': '$key:prepared:${head['snapshotHash']}',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    var changed = false;
    await db.transaction((tx) async {
      if (invalid()) throw const FormatException('ACCOUNT_CHANGED');
      final current = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: ['$key:current'],
      );
      if (current.isNotEmpty) {
        final latest = jsonDecode(current.single['value'] as String);
        if (latest['head']['catalogRevision'] >= head['catalogRevision']) {
          return;
        }
      }
      await tx.insert('app_settings', {
        'name': '$key:current',
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
    });
    if (changed && !invalid()) {
      notifyListeners(); // one CatalogChanged per commit.
    }
  }

  static void verify(Map head, Map snapshot, String scope) {
    if (head['schemaVersion'] != 1 ||
        snapshot['schemaVersion'] != 1 ||
        snapshot['scope'] != scope ||
        head['scope'] != scope ||
        head['catalogRevision'] != snapshot['catalogRevision'] ||
        contentDigest(snapshot) != head['snapshotHash'] ||
        head['snapshotId'] != 'sha256-${head['snapshotHash']}') {
      throw const FormatException('SNAPSHOT_VERIFY_FAILED');
    }
    if (snapshot['vitrineConfig'] != null) {
      VitrineConfig.fromMap(snapshot['vitrineConfig']);
      if (snapshot['configRevision'] is! int ||
          snapshot['configRevision'] < 1) {
        throw const FormatException('INVALID_CONFIG_REVISION');
      }
    }
    final items = snapshot['items'] as List;
    final exact = <String, Map>{};
    final logical = <String>{};
    for (final raw in items) {
      final r = raw as Map;
      final key = '${r['contentId']}:${r['revisionId']}';
      if (r['contentId'] is! String ||
          r['revisionId'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(r['sha256'] as String? ?? '') ||
          exact.containsKey(key) ||
          !logical.add(r['contentId'] as String)) {
        throw const FormatException('INVALID_ITEM');
      }
      exact[key] = r;
    }
    final visited = <String>{}, visiting = <String>{};
    void visit(String key) {
      if (visiting.contains(key)) {
        throw const FormatException('DEPENDENCY_CYCLE');
      }
      if (!visited.add(key)) return;
      visiting.add(key);
      for (final ref in exact[key]!['dependencies'] as List) {
        final dep = '${ref['contentId']}:${ref['revisionId']}';
        if (exact[dep]?['sha256'] != ref['sha256']) {
          throw const FormatException('MISSING_EXACT_DEPENDENCY');
        }
        visit(dep);
      }
      visiting.remove(key);
    }

    for (final key in exact.keys) {
      visit(key);
    }
  }
}
