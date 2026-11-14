import 'alchemist_diagnostics.dart';

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/content_revision.dart';
import '../models/session_plan.dart' show newId;
import 'diary_api.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'alchemist_errors.dart';

String alchemistStageLabel(Object? phase) =>
    const {
      'restoring': 'Проверка Google-сессии и прав',
      'diary_committed': 'Запись дневника подтверждена сервером',
      'queued': 'Ожидает отправки',
      'running': 'Выполняется',
      'transferring': 'Передача файла',
      'bytes_acked': 'Байты приняты; ждём проверку',
      'server_verifying': 'Сервер проверяет файл',
      'verified': 'Файл проверен',
      'manifest_registering': 'Проверка состава',
      'publishing': 'Подтверждение каталога',
      'catalog_committed': 'Подтверждено сервером',
      'diary_verifying': 'Проверка дневниковой записи',
      'paused': 'Пауза',
      'failed': 'Сбой',
      'cancelled': 'Отправка отменена',
      'complete': 'Подтверждено сервером',
      'pausing': 'Завершается текущий запрос',
    }[phase] ??
    'Ожидание';

String alchemistWorkLabel(Map work) {
  if (work['phase'] == 'paused') {
    return const {
          'USER_PAUSED': 'Пауза пользователем',
          'LIFECYCLE_PAUSED': 'Пауза после сворачивания',
          'OWNER_CHANGED': 'Нужен исходный Google-аккаунт',
          'APP_RESTART': 'Пауза после перезапуска',
        }[work['pauseReason'] ?? work['code']] ??
        'Передача приостановлена';
  }
  return const {
        'queued': 'В очереди',
        'preparing': 'Проверка подключения и прав',
        'running': 'Выполняется',
        'complete': 'Подтверждено сервером',
        'waiting_auth': 'Ожидает Google-вход',
        'waiting_permission': 'Нужны права сервера',
        'waiting_network':
            'Ожидает сеть — нажмите «Продолжить» после подключения',
        'pausing': 'Завершается текущий запрос',
        'failed': 'Сбой — можно повторить',
        'cancelled': 'Отправка отменена',
      }[work['phase']] ??
      'Ожидание';
}

double? alchemistFileProgress(Map work) {
  if (!const ['transferring', 'bytes_acked'].contains(work['stage']) ||
      work['phase'] != 'running') {
    return null;
  }
  final total = work['totalBytes'], bytes = work['bytes'];
  return total is num && bytes is num && total > 0
      ? (bytes / total).clamp(0.0, 1.0).toDouble()
      : null;
}

class QueueEnqueueResult {
  const QueueEnqueueResult(this.phase, {this.existing = false, this.reason});
  final String phase;
  final bool existing;
  final String? reason;
}

/// Stable digest of the queued user revision, not an access token or a role.
String queueRevision(Map<String, dynamic> row) => sha256
    .convert(
      utf8.encode(
        canonicalContent({
          if (row['entry'] != null) 'entry': row['entry'],
          if (row.containsKey('published')) 'published': row['published'],
          if (row['root'] != null) 'root': row['root'],
          if (row['card'] != null) 'card': row['card'],
          if (row['localCover'] != null) 'localCover': row['localCover'],
        }),
      ),
    )
    .toString();

Map<String, dynamic> initialQueuedWork(
  Map<String, dynamic> row,
  String owner, {
  bool complete = false,
}) => {
  'phase': complete ? 'complete' : 'queued',
  'stage': complete ? 'diary_committed' : 'queued',
  'code': null,
  'message': null,
  'revision': queueRevision(row),
  'taskId': newId(),
  'ownerBinding': owner,
  'attempts': 0,
  'resumeRequested': false,
};

/// One runner over the existing card and diary outbox records. No second queue.
/// Survives editor navigation. Android suspension cooperatively pauses work;
/// restart never silently starts an upload under a newly selected account.
class AlchemistWorkQueue extends ChangeNotifier {
  AlchemistWorkQueue({
    required this.db,
    required this.owner,
    required this.send,
    this.prepare,
  });
  final Future<void> Function()? prepare;
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
  bool _running = false, _closed = false, _wakeRequested = false;
  final _pauseCodes = <String, String>{};
  final _resumeRequested = <String>{};
  String? _activeName;
  String _runnerEpoch =
      newId(); // Local execution intent, never Google identity.
  bool _backgroundPaused = false;
  void foreground() => _backgroundPaused = false;
  void invalidateOwner() {
    _runnerEpoch = newId();
    for (final row in rows) {
      final name = row['_name'] as String;
      _stops[name] = true;
      _pauseCodes[name] = 'OWNER_CHANGED';
    }
  }

  final _cancelled = <String>{};
  Future<void> _progress = Future.value();
  void _recordProgress(String name, Map<String, dynamic> values) {
    _progress = _progress
        .then((_) => _patch(name, values))
        .catchError((Object _) {});
  }

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

  Future<QueueEnqueueResult> enqueue(String name) async {
    AlchemistDiagnostics.instance.stage('RESUME_REQUESTED');
    final result = await db.transaction((tx) async {
      final records = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      final current = owner();
      final value = records.isEmpty
          ? null
          : Map<String, dynamic>.from(
              jsonDecode(records.single['value'] as String),
            );
      if (value == null ||
          current == null ||
          value['ownerBinding'] != current) {
        AlchemistDiagnostics.instance.stage(
          'RESUME_DENIED_OWNER',
          ownerEqual: false,
        );
        throw const AlchemistFailure(
          'Подтвердите исходный Google-аккаунт задачи.',
          401,
          'ACCOUNT_CHANGED',
          DiaryFailure.authorization,
        );
      }
      AlchemistDiagnostics.instance.stage(
        'QUEUE_OWNER_MATCH',
        ownerEqual: true,
      );
      final revision = queueRevision(value);
      final work = Map<String, dynamic>.from(value['_work'] ?? {});
      final phase = work['phase'];
      if (work['revision'] == revision && phase == 'complete') {
        return const QueueEnqueueResult(
          'complete',
          existing: true,
          reason: 'ALREADY_COMMITTED',
        );
      }
      if (_backgroundPaused) {
        _stops[name] = true;
        _pauseCodes[name] = 'LIFECYCLE_PAUSED';
        value['_work'] = {
          ...work,
          'phase': _activeName == name ? 'pausing' : 'paused',
          'code': 'LIFECYCLE_PAUSED',
          'pauseReason': 'LIFECYCLE_PAUSED',
        };
        await tx.update(
          'app_settings',
          {'value': jsonEncode(value)},
          where: 'name=?',
          whereArgs: [name],
        );
        return const QueueEnqueueResult(
          'paused',
          existing: true,
          reason: 'LIFECYCLE_PAUSED',
        );
      }
      if (_activeName == name) {
        if (work['revision'] != null && work['revision'] != revision) {
          throw const AlchemistFailure(
            'Дождитесь текущей передачи перед новой редакцией.',
            409,
            'REVISION_IN_FLIGHT',
          );
        }
        if (_stops[name] == true) {
          _resumeRequested.add(name);
          work['resumeRequested'] = true;
          work['runnerEpoch'] = _runnerEpoch;
          value['_work'] = work;
          await tx.update(
            'app_settings',
            {'value': jsonEncode(value)},
            where: 'name=?',
            whereArgs: [name],
          );
          return const QueueEnqueueResult(
            'pausing',
            existing: true,
            reason: 'RESUME_AFTER_CURRENT_REQUEST',
          );
        }
        return QueueEnqueueResult(
          phase as String? ?? 'running',
          existing: true,
          reason: 'ALREADY_RUNNING',
        );
      }
      if (work['revision'] == revision &&
          phase == 'queued' &&
          work['runnerEpoch'] == _runnerEpoch &&
          _stops[name] != true) {
        return const QueueEnqueueResult('queued', existing: true);
      }
      final same = work['revision'] == revision;
      _cancelled.remove(name);
      _resumeRequested.remove(name);
      _stops[name] = false;
      _pauseCodes.remove(name);
      value['_work'] = {
        if (same) ...work,
        'phase': 'queued',
        'stage': 'queued',
        'code': null,
        'message': null,
        'revision': revision,
        'taskId': same ? work['taskId'] ?? newId() : newId(),
        'ownerBinding': current,
        'runnerEpoch': _runnerEpoch,
        'pauseReason': null,
        'attempts': same ? work['attempts'] ?? 0 : 0,
        'resumeRequested': false,
      };
      await tx.update(
        'app_settings',
        {'value': jsonEncode(value)},
        where: 'name=?',
        whereArgs: [name],
      );
      return const QueueEnqueueResult('queued');
    });
    await refresh();
    if (result.phase != 'complete') unawaited(_pump());
    AlchemistDiagnostics.instance.stage('RESUME_ALLOWED');
    return result;
  }

  Future<void> pause(
    String name, {
    bool cancel = false,
    String reason = 'USER_PAUSED',
  }) async {
    if (!const {
      'USER_PAUSED',
      'LIFECYCLE_PAUSED',
      'OWNER_CHANGED',
      'WAITING_AUTH',
      'WAITING_NETWORK',
    }.contains(reason)) {
      throw ArgumentError('Invalid pause reason');
    }
    _pauseCodes[name] = reason;
    _resumeRequested.remove(name);
    AlchemistDiagnostics.instance.stage(
      reason == 'USER_PAUSED'
          ? 'PAUSE_USER'
          : reason == 'OWNER_CHANGED'
          ? 'QUEUE_OWNER_MISMATCH'
          : 'PAUSE_LIFECYCLE',
    );
    _stops[name] = true;
    if (cancel) _cancelled.add(name);
    await _patch(name, {
      'phase': cancel
          ? 'cancelled'
          : _activeName == name
          ? 'pausing'
          : 'paused',
      'code': cancel ? 'CANCELLED' : reason,
      'pauseReason': reason,
    });
  }

  Future<void> pauseAll({String reason = 'LIFECYCLE_PAUSED'}) async {
    if (reason == 'LIFECYCLE_PAUSED') _backgroundPaused = true;
    for (final row in List<Map<String, dynamic>>.of(rows)) {
      if (!const [
        'complete',
        'cancelled',
        'paused',
        'failed',
      ].contains(row['_work']?['phase'])) {
        await pause(row['_name'], reason: reason);
      }
    }
  }

  Future<void> recover() async {
    await refresh();
    if (_running) return;
    for (final row in List<Map<String, dynamic>>.of(rows)) {
      if (!const [
            'complete',
            'cancelled',
            'paused',
            'failed',
          ].contains(row['_work']?['phase']) &&
          row['_work']?['runnerEpoch'] != _runnerEpoch) {
        await _patch(row['_name'], {'phase': 'paused', 'code': 'APP_RESTART'});
      }
    }
  }

  Future<void> _pump() async {
    if (_closed) return;
    if (_running) {
      _wakeRequested = true;
      return;
    }
    _running = true;
    final pumpOwner = owner(), pumpEpoch = _runnerEpoch;
    try {
      while (!_closed) {
        if (owner() != pumpOwner || _runnerEpoch != pumpEpoch) break;
        await refresh();
        final row = rows
            .where(
              (v) =>
                  v['_work']?['phase'] == 'queued' &&
                  v['_work']?['runnerEpoch'] == _runnerEpoch,
            )
            .firstOrNull;
        if (row == null) break;
        final name = row['_name'] as String, originalOwner = owner();
        bool stop() =>
            _closed ||
            _backgroundPaused ||
            _runnerEpoch != pumpEpoch ||
            _stops[name] == true ||
            owner() != originalOwner;
        if (stop()) {
          await pause(
            name,
            reason:
                _pauseCodes[name] ??
                (_backgroundPaused ? 'LIFECYCLE_PAUSED' : 'OWNER_CHANGED'),
          );
          continue;
        }
        _activeName = name;
        await _patch(name, {'phase': 'preparing', 'stage': 'restoring'});

        final retries = <String, int>{};
        void diagnostic() {
          final event = AlchemistDiagnostics.instance.lastMeasurement;
          if (event == null ||
              stop() ||
              event['taskId'] != row['_work']?['taskId']) {
            return;
          }
          final trace = event['traceId'] as String,
              attempt = event['attempt'] as int;
          retries[trace] = attempt > (retries[trace] ?? 0)
              ? attempt
              : (retries[trace] ?? 0);
          _recordProgress(name, {
            'traceId': trace,
            'networkRetries':
                (row['_work']?['networkRetries'] as int? ?? 0) +
                retries.values.fold<int>(0, (n, v) => n + v),
          });
        }

        AlchemistDiagnostics.instance.addListener(diagnostic);
        try {
          await prepare?.call();
          if (stop()) {
            throw const AlchemistFailure(
              'Задача приостановлена.',
              401,
              'ACCOUNT_CHANGED',
              DiaryFailure.authorization,
            );
          }
          await _patch(name, {
            'phase': 'running',
            'attempts': (row['_work']?['attempts'] as int? ?? 0) + 1,
          });
          final value = (await _read(name))!;
          await runZoned(
            () => send(
              name,
              value,
              stop,
              (stage) {
                // Progress is serialized below; callbacks must not overwrite a card receipt.
                if (!stop()) _recordProgress(name, {'stage': stage});
              },
              (n, total) {
                if (!stop()) {
                  _recordProgress(name, {'bytes': n, 'totalBytes': total});
                }
              },
            ),
            zoneValues: {
              #alchemistTask: row['_work']?['taskId'],
              #alchemistInterrupted: stop,
            },
          );
          await _progress;
          await _patch(name, {
            'phase': _cancelled.contains(name)
                ? 'cancelled'
                : stop()
                ? 'paused'
                : 'complete',
            'code': _cancelled.contains(name)
                ? 'CANCELLED'
                : stop()
                ? _pauseCodes[name] ?? 'OWNER_CHANGED'
                : null,
            'stage': _cancelled.contains(name)
                ? 'cancelled'
                : stop()
                ? 'paused'
                : name.startsWith('alchemist_diary_queue:')
                ? 'diary_committed'
                : 'catalog_committed',
            if (!stop() && !_cancelled.contains(name))
              'revision': queueRevision((await _read(name)) ?? value),
          });
        } catch (e) {
          await _progress;
          final failure = AlchemistFailure.from(e);
          await _patch(name, {
            'phase': _cancelled.contains(name)
                ? 'cancelled'
                : stop()
                ? 'paused'
                : failure.status == 401
                ? 'waiting_auth'
                : failure.status == 403
                ? 'waiting_permission'
                : failure.kind == DiaryFailure.network
                ? 'waiting_network'
                : 'failed',
            'code': _cancelled.contains(name)
                ? 'CANCELLED'
                : stop()
                ? _pauseCodes[name] ?? 'OWNER_CHANGED'
                : failure.code,
            'message': failure.message,
          });
        } finally {
          AlchemistDiagnostics.instance.removeListener(diagnostic);
          _activeName = null;
          if (_resumeRequested.remove(name) &&
              !_closed &&
              !_cancelled.contains(name) &&
              owner() == originalOwner) {
            _stops[name] = false;
            _pauseCodes.remove(name);
            await _patch(name, {
              'phase': 'queued',
              'stage': 'queued',
              'code': null,
              'message': null,
              'resumeRequested': false,
            });
          }
        }
      }
    } finally {
      _running = false;
      if (_wakeRequested && !_closed) {
        _wakeRequested = false;
        unawaited(_pump());
      }
      changed();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
