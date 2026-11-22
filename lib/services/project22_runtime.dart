import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ratings22.dart';
import '../models/session_plan.dart' show newId;
import 'alchemist_work_queue.dart';
import 'metadata_gateway.dart';
import 'alchemist_errors.dart';

/// One negotiated extension, same existing API broker and queue18. No provider
/// migration, auth picker, polling, native worker, or media download here.
class Project22Runtime extends ChangeNotifier {
  Project22Runtime({
    required this.db,
    required this.rpc,
    required this.owner,
    required this.epoch,
    required this.scope,
  });
  final Database db;
  final MetadataRpc rpc;
  final String? Function() owner;
  final int Function() epoch;
  final String scope;
  Map<String, dynamic>? capability, _overview, _ratings;
  Map<String, dynamic>? get overview =>
      _binding == owner() && _epoch == epoch() && !accessDenied
      ? _overview
      : null;
  set overview(Map<String, dynamic>? v) => _overview = v;
  Map<String, dynamic>? get ratings =>
      _binding == owner() && _epoch == epoch() ? _ratings : null;
  set ratings(Map<String, dynamic>? v) => _ratings = v;
  String? _binding;
  int? _epoch;
  Future<bool>? _probe;
  Future<void>? _refresh;
  bool closed = false, stale = true, accessDenied = false;
  AlchemistFailure? _probeFailure;
  void identityChanged() {
    if (_binding != owner() || _epoch != epoch()) {
      capability = null;
      overview = null;
      ratings = null;
      stale = true;
      accessDenied = false;
      changed();
    }
  }

  String status = 'Не подключено';
  bool get ready =>
      !closed &&
      _binding == owner() &&
      _epoch == epoch() &&
      (capability?['expiresAt'] as int? ?? 0) >
          DateTime.now().millisecondsSinceEpoch;
  bool get admin => ready && capability?['admin'] == true;
  bool get canPublishPolicy => admin && capability?['canPublishPolicy'] == true;
  void changed() {
    if (!closed) notifyListeners();
  }

  String _key(String name, String a) =>
      'project22:$name:${digest22([a, scope])}';
  Future<bool> negotiate() =>
      _probe ??= _negotiate().whenComplete(() => _probe = null);
  Future<bool> _negotiate() async {
    if (ready) return true;
    final a = owner(), e = epoch();
    if (_binding != a || _epoch != e) {
      overview = null;
      ratings = null;
      capability = null;
    }
    _binding = a;
    _epoch = e;
    if (a == null || a == 'public') return false;
    try {
      final nonce = newId();
      final c = await rpc
          .call('project.capabilities', {'scope': scope, 'nonce': nonce})
          .timeout(const Duration(seconds: 20));
      if (a != owner() || e != epoch() || closed) return false;
      if (c['contract'] != 'alchemic.project22/1' ||
          c['schemaVersion'] != 22 ||
          c['canonical'] != 'sorted-json-milli-v1' ||
          c['nonce'] != nonce ||
          c['principalBinding'] != a ||
          c['scope'] != scope ||
          c['expiresAt'] is! int ||
          c['expiresAt'] <= DateTime.now().millisecondsSinceEpoch) {
        throw const FormatException('PROJECT22_CAPABILITY');
      }
      capability = c;
      accessDenied = false;
      status = 'Серверный протокол №22 подтверждён';
      changed();
      return true;
    } catch (e) {
      _probeFailure = e is FormatException
          ? AlchemistFailure.server(422, 'PROJECT22_UNSUPPORTED')
          : AlchemistFailure.from(e);
      accessDenied =
          _probeFailure?.status == 401 || _probeFailure?.status == 403;
      capability = null;
      stale = true;
      status = 'Протокол №22 недоступен; сохранённые данные оставлены';
      changed();
      return false;
    }
  }

  Future<Map<String, dynamic>> call(String op, Map<String, dynamic> p) async {
    if (!await negotiate()) {
      throw _probeFailure ??
          AlchemistFailure.server(422, 'PROJECT22_UNAVAILABLE');
    }
    final a = owner(), e = epoch();
    late final Map<String, dynamic> v;
    try {
      v = await rpc
          .call(op, {'scope': scope, ...p})
          .timeout(const Duration(seconds: 20));
    } on AlchemistFailure catch (e) {
      if (e.status == 401 || e.status == 403) {
        accessDenied = true;
        capability = null;
        stale = true;
        changed();
      }
      rethrow;
    }
    if (a != owner() || e != epoch() || closed) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    return v;
  }

  Future<void> restore() async {
    final a = owner();
    if (_binding != a || _epoch != epoch()) {
      overview = null;
      ratings = null;
      capability = null;
      _binding = a;
      _epoch = epoch();
    }
    if (a == null) return;
    for (final name in ['overview', 'ratings']) {
      final rows = await db.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [_key(name, a)],
      );
      if (a != owner() || closed) return;
      if (rows.isEmpty) continue;
      try {
        final v = Map<String, dynamic>.from(
          jsonDecode(rows.single['value'] as String),
        );
        if (v['owner'] != a || digest22(v['value']) != v['hash']) continue;
        final value = Map<String, dynamic>.from(v['value']);
        if (name == 'ratings') {
          verifyRatings22(value['head'], value['snapshot']);
          ratings = value;
        } else {
          overview = value;
        }
      } catch (_) {
        /* Derived cache is untrusted; preserve bytes and personal data. */
      }
    }
    stale = true;
    changed();
  }

  Future<void> refresh(AlchemistWorkQueue queue) =>
      _refresh ??= _request(queue).whenComplete(() => _refresh = null);
  Future<void> _request(AlchemistWorkQueue queue) async {
    await restore();
    if (!await negotiate()) return;
    final a = owner()!,
        name = 'alchemist_download:$a:project22:${digest22(scope)}';
    await db.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      if (rows.isNotEmpty) {
        final phase = jsonDecode(
          rows.single['value'] as String,
        )['_work']['phase'];
        if (![
          'complete',
          'failed',
          'failed_permanent',
          'cancelled',
        ].contains(phase)) {
          return;
        }
      }
      if (a != owner()) throw const FormatException('ACCOUNT_CHANGED');
      final row = <String, dynamic>{
        'ownerBinding': a,
        'download': {'kind': 'projectMetadata22', 'scope': scope},
      };
      row['_work'] = initialQueuedWork(row, a);
      await tx.insert('app_settings', {
        'name': name,
        'value': jsonEncode(row),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await queue.refresh();
    final row = queue.rows.where((r) => r['_name'] == name).firstOrNull;
    if (row?['_work']?['phase'] == 'queued') await queue.enqueue(name);
  }

  Future<void> execute(Map<String, dynamic> row, bool Function() stop) async {
    final a = owner();
    if (a == null ||
        row['ownerBinding'] != a ||
        row['download']['scope'] != scope ||
        stop()) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    try {
      if (!await negotiate()) {
        throw _probeFailure ??
            AlchemistFailure.server(422, 'PROJECT22_UNAVAILABLE');
      }
      final nextOverview = admin ? await call('project.overview', {}) : null;
      if (nextOverview != null &&
          (nextOverview['schemaVersion'] != 22 ||
              nextOverview['scope'] != capability?['adminScope'] ||
              nextOverview['sections'] is! List ||
              nextOverview['sections'].length != 7)) {
        throw const FormatException('OVERVIEW_SCHEMA');
      }
      final view = await call('ratings.head', {}), head = view['head'];
      Map<String, dynamic>? nextRatings = ratings;
      if (head != null) {
        if (head['ratingsRevision'] is! int) {
          throw const FormatException('RATINGS_HEAD');
        }
        if (ratings == null ||
            head['ratingsRevision'] > ratings!['head']['ratingsRevision']) {
          final snapshot = await call('ratings.snapshot', {
            'hash': head['ratingsSnapshotHash'],
          });
          verifyRatings22(head, snapshot);
          nextRatings = {'head': head, 'snapshot': snapshot};
        } else if (head['ratingsRevision'] ==
                ratings!['head']['ratingsRevision'] &&
            head['ratingsSnapshotHash'] !=
                ratings!['head']['ratingsSnapshotHash']) {
          throw const FormatException('RATINGS_REVISION_CONFLICT');
        }
      }
      if (a != owner() || stop() || closed) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      await db.transaction((tx) async {
        if (a != owner() || stop() || closed) {
          throw const FormatException('ACCOUNT_CHANGED');
        }
        for (final pair in [
          ('overview', nextOverview),
          ('ratings', nextRatings),
        ]) {
          if (pair.$2 == null) continue;
          await tx.insert('app_settings', {
            'name': _key(pair.$1, a),
            'value': jsonEncode({
              'owner': a,
              'hash': digest22(pair.$2),
              'value': pair.$2,
            }),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      overview = nextOverview;
      ratings = nextRatings;
      stale = view['dirty'] == true;
      status = stale
          ? 'Расчёт обновляется; показана проверенная копия'
          : 'Получены подтверждённые данные';
      changed();
    } catch (_) {
      stale = true;
      status = 'Обновление недоступно; показана последняя проверенная копия';
      changed();
      rethrow;
    }
  }

  Map<String, dynamic>? summaryFor(String type, String contentId) {
    final wireType = type == 'template' ? 'PROGRAM' : type.toUpperCase();
    return (ratings?['snapshot']?['items'] as List?)
        ?.cast<Map<String, dynamic>>()
        .where(
          (s) =>
              s['target']['type'] == wireType &&
              s['target']['contentId'] == contentId,
        )
        .firstOrNull;
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}
