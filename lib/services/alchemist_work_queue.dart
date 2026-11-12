import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'alchemist_errors.dart';

/// One runner over the existing card and diary outbox records. No second queue.
/// Survives editor navigation. Android suspension cooperatively pauses work;
/// restart never silently starts an upload under a newly selected account.
class AlchemistWorkQueue extends ChangeNotifier {
  AlchemistWorkQueue({
    required this.db,
    required this.owner,
    required this.send,
  });
  final Database db;
  final String? Function() owner;
  final Future<void> Function(
    String,
    Map<String, dynamic>,
    bool Function(),
    void Function(String),
    void Function(int, int),
  )
  send;
  final Map<String, bool> _stops = {};
  bool _running = false, _closed = false;
  List<Map<String, dynamic>> rows = [];
  int get pendingCount => rows
      .where(
        (r) => !const ['complete', 'cancelled'].contains(r['_work']?['phase']),
      )
      .length;
  void changed() {
    if (!_closed) notifyListeners();
  }

  Future<Map<String, dynamic>?> _read(String name) async {
    final r = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [name],
    );
    return r.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(r.single['value'] as String));
  }

  Future<void> _patch(String name, Map<String, dynamic> values) async {
    await db.transaction((tx) async {
      final r = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      if (r.isEmpty) return;
      final v = Map<String, dynamic>.from(
        jsonDecode(r.single['value'] as String),
      );
      final work = Map<String, dynamic>.from(v['_work'] ?? {})..addAll(values);
      v['_work'] = work;
      await tx.update(
        'app_settings',
        {'value': jsonEncode(v)},
        where: 'name=?',
        whereArgs: [name],
      );
    });
    await refresh();
  }

  Future<void> refresh() async {
    final current = owner();
    final records = await db.query(
      'app_settings',
      where: 'name LIKE ? OR name LIKE ?',
      whereArgs: ['alchemist_card:%', 'alchemist_diary_queue:%'],
    );
    rows = records
        .map(
          (r) => <String, dynamic>{
            ...Map<String, dynamic>.from(jsonDecode(r['value'] as String)),
            '_name': r['name'],
          },
        )
        .where(
          (v) =>
              current != null &&
              v['ownerBinding'] == current &&
              v['_work'] != null,
        )
        .toList();
    changed();
  }

  Future<void> enqueue(String name) async {
    final v = await _read(name), current = owner();
    if (v == null || current == null || v['ownerBinding'] != current) {
      throw const AlchemistFailure(
        'Подтвердите аккаунт владельца задачи.',
        401,
        'ACCOUNT_CHANGED',
      );
    }
    if (const ['queued', 'running'].contains(v['_work']?['phase']) &&
        _running) {
      return;
    }
    _stops[name] = false;
    await _patch(name, {
      'phase': 'queued',
      'code': null,
      'message': null,
      'taskId': name.split(':').last,
      'ownerBinding': current,
    });
    unawaited(_pump());
  }

  Future<void> pause(String name, {bool cancel = false}) async {
    _stops[name] = true;
    await _patch(name, {
      'phase': cancel ? 'cancelled' : 'paused',
      'code': cancel ? 'CANCELLED' : 'USER_PAUSED',
    });
  }

  Future<void> pauseAll() async {
    for (final row in List<Map<String, dynamic>>.of(rows)) {
      if (!const [
        'complete',
        'cancelled',
        'paused',
        'failed',
      ].contains(row['_work']?['phase'])) {
        await pause(row['_name']);
      }
    }
  }

  Future<void> recover() async {
    await refresh();
    for (final row in List<Map<String, dynamic>>.of(rows)) {
      if (!const [
        'complete',
        'cancelled',
        'paused',
        'failed',
      ].contains(row['_work']?['phase'])) {
        await _patch(row['_name'], {'phase': 'paused', 'code': 'APP_RESTART'});
      }
    }
  }

  Future<void> _pump() async {
    if (_running || _closed) return;
    _running = true;
    try {
      while (!_closed) {
        await refresh();
        final row = rows
            .where((v) => v['_work']?['phase'] == 'queued')
            .firstOrNull;
        if (row == null) break;
        final name = row['_name'] as String, originalOwner = owner();
        bool stop() =>
            _closed || _stops[name] == true || owner() != originalOwner;
        if (stop()) {
          await pause(name);
          continue;
        }
        await _patch(name, {
          'phase': 'running',
          'attempts': (row['_work']?['attempts'] as int? ?? 0) + 1,
        });
        try {
          final value = (await _read(name))!;
          await send(
            name,
            value,
            stop,
            (stage) {
              // Progress is serialized below; callbacks must not overwrite a card receipt.
              if (!stop()) unawaited(_patch(name, {'stage': stage}));
            },
            (n, total) {
              if (!stop()) {
                unawaited(_patch(name, {'bytes': n, 'totalBytes': total}));
              }
            },
          );
          await _patch(name, {
            'phase': stop() ? 'paused' : 'complete',
            'code': null,
            'stage': 'catalog_committed',
          });
        } catch (e) {
          final failure = AlchemistFailure.from(e);
          await _patch(name, {
            'phase': stop() ? 'paused' : 'failed',
            'code': failure.code,
            'message': failure.message,
          });
        }
      }
    } finally {
      _running = false;
      changed();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
