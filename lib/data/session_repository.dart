import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';

abstract interface class SessionRepository {
  Future<CurrentSessionDraft?> loadDraft();
  Future<void> saveDraft(CurrentSessionDraft draft);
  Future<List<SessionTemplate>> templates();
  Future<void> saveTemplate(SessionTemplate template);
  Future<void> deleteTemplate(String id);
  Future<void> setDefault(String id);
  Future<int> nextNumber();
  Future<SessionRun> startRun(CurrentSessionDraft snapshot);
  Future<void> checkpoint(SessionRun run, {String? event});
  Future<List<SessionRun>> history();
  Future<List<Map<String, dynamic>>> events(String runId);
  Future<void> editRun(String id, {String? name, String? notes});
  Future<void> deleteRun(String id);
  Future<void> interruptUnfinished();
  Future<List<String>> references(String assetId);
  Future<void> reset();
}

class SqliteSessionRepository implements SessionRepository {
  SqliteSessionRepository(this.database);
  final Database database;
  Map<String, dynamic> _decode(Map<String, Object?> row) =>
      jsonDecode(row['payload'] as String) as Map<String, dynamic>;
  @override
  Future<CurrentSessionDraft?> loadDraft() async {
    final rows = await database.query('current_draft', where: 'id=1');
    return rows.isEmpty
        ? null
        : CurrentSessionDraft.fromMap(_decode(rows.single));
  }

  @override
  Future<void> saveDraft(CurrentSessionDraft draft) async {
    await database.insert('current_draft', {
      'id': 1,
      'payload': jsonEncode(draft.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<SessionTemplate>> templates() async => (await database.query(
    'session_templates',
    orderBy: 'rowid DESC',
  )).map((r) => SessionTemplate.fromMap(_decode(r))).toList();
  @override
  Future<void> saveTemplate(SessionTemplate template) async {
    await database.insert('session_templates', {
      'id': template.id,
      'payload': jsonEncode(template.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await database.delete('session_templates', where: 'id=?', whereArgs: [id]);
  }

  @override
  Future<void> setDefault(String id) async {
    await database.transaction((tx) async {
      for (final row in await tx.query('session_templates')) {
        final m = _decode(row);
        m['isDefault'] = m['id'] == id;
        await tx.update(
          'session_templates',
          {'payload': jsonEncode(m)},
          where: 'id=?',
          whereArgs: [m['id']],
        );
      }
    });
  }

  @override
  Future<int> nextNumber() async {
    final rows = await database.query(
      'app_counters',
      where: 'name=?',
      whereArgs: ['session'],
    );
    return (rows.firstOrNull?['value'] as int? ?? 0) + 1;
  }

  @override
  Future<SessionRun> startRun(CurrentSessionDraft snapshot) =>
      database.transaction((tx) async {
        final active = await tx.query(
          'session_runs',
          where: 'status IN (?,?)',
          whereArgs: ['running', 'paused'],
          limit: 1,
        );
        if (active.isNotEmpty) {
          throw StateError('Сначала завершите активную сессию.');
        }
        final rows = await tx.query(
          'app_counters',
          where: 'name=?',
          whereArgs: ['session'],
        );
        final number = (rows.firstOrNull?['value'] as int? ?? 0) + 1;
        final now = DateTime.now().toUtc();
        final run = SessionRun(
          id: newId(),
          displayNumber: number,
          name: formatLocalDate(now),
          snapshot: CurrentSessionDraft.fromMap(snapshot.toMap()),
          startedAt: now,
          status: RunStatus.running,
        );
        await tx.insert('app_counters', {
          'name': 'session',
          'value': number,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.insert('session_runs', {
          'id': run.id,
          'displayNumber': number,
          'status': run.status.name,
          'payload': jsonEncode(run.toMap()),
        });
        await _event(tx, run, 'started');
        return run;
      });
  Future<void> _event(DatabaseExecutor tx, SessionRun run, String type) async {
    await tx.insert('run_events', {
      'runId': run.id,
      'payload': jsonEncode({
        'eventType': type,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'stepIndex': run.stepIndex,
        'phase': run.phase,
        'playheadMs': run.playheadMs,
        'elapsedMs': run.elapsedMs,
      }),
    });
  }

  @override
  Future<void> checkpoint(SessionRun run, {String? event}) async {
    await database.transaction((tx) async {
      final rows = await tx.query(
        'session_runs',
        where: 'id=?',
        whereArgs: [run.id],
      );
      if (rows.isEmpty) throw StateError('Сессия не найдена.');
      final existing = _decode(rows.single);
      if (!['running', 'paused'].contains(existing['status'])) return;
      final update = run.toMap();
      for (final key in [
        'status',
        'stepIndex',
        'phase',
        'playheadMs',
        'elapsedMs',
        'endedAt',
      ]) {
        existing[key] = update[key];
      }
      // Checkpoints never rewrite the original plan, its metadata or user notes.
      await tx.update(
        'session_runs',
        {'status': run.status.name, 'payload': jsonEncode(existing)},
        where: 'id=?',
        whereArgs: [run.id],
      );
      if (event != null) await _event(tx, run, event);
    });
  }

  @override
  Future<List<SessionRun>> history() async => (await database.query(
    'session_runs',
    orderBy: 'displayNumber DESC',
  )).map((r) => SessionRun.fromMap(_decode(r))).toList();
  @override
  Future<List<Map<String, dynamic>>> events(String runId) async =>
      (await database.query(
        'run_events',
        where: 'runId=?',
        whereArgs: [runId],
        orderBy: 'id',
      )).map(_decode).toList();
  @override
  Future<void> editRun(String id, {String? name, String? notes}) async {
    await database.transaction((tx) async {
      final rows = await tx.query(
        'session_runs',
        where: 'id=?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      final m = _decode(rows.single);
      if (name != null) m['name'] = name;
      // User-editable notes are separate from the immutable execution snapshot.
      if (notes != null) m['userNotes'] = notes;
      await tx.update(
        'session_runs',
        {'payload': jsonEncode(m)},
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> deleteRun(String id) async {
    await database.delete(
      'session_runs',
      where: 'id=? AND status NOT IN (?,?)',
      whereArgs: [id, 'running', 'paused'],
    );
  }

  @override
  Future<void> interruptUnfinished() async {
    for (final run in await history()) {
      if (run.active) {
        await checkpoint(
          run.checkpoint(
            status: RunStatus.interrupted,
            endedAt: DateTime.now().toUtc(),
          ),
          event: 'process_interrupted',
        );
      }
    }
  }

  @override
  Future<List<String>> references(String assetId) async {
    bool uses(SessionPlan p) => p.steps.any((s) => s.audioAssetId == assetId);
    final refs = <String>[];
    final draft = await loadDraft();
    if (draft != null && uses(draft.plan)) refs.add('Текущая конфигурация');
    for (final t in await templates()) {
      if (uses(t.plan)) refs.add('Шаблон «${t.name}»');
    }
    for (final run in await history()) {
      if (run.active && uses(run.snapshot.plan)) {
        refs.add('Активная сессия №${run.displayNumber}');
      }
    }
    return refs;
  }

  @override
  Future<void> reset() async {
    await database.transaction((tx) async {
      for (final table in [
        'run_events',
        'session_runs',
        'session_templates',
        'current_draft',
        'app_counters',
      ]) {
        await tx.delete(table);
      }
    });
  }
}
