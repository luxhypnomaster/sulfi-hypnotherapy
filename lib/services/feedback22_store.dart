import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import '../models/ratings22.dart';
import 'alchemist_work_queue.dart';
import 'project22_runtime.dart';
import 'playback22_evidence.dart';

/// Personal feedback lives on device. No notes/voice/text/contact goes into the
/// wire envelope. Consent is a separate action, never session completion.
class Feedback22Store {
  Feedback22Store(this.db, {required this.owner, this.runtime, this.queue});
  final Database db;
  final String? Function() owner;
  final Project22Runtime? runtime;
  final AlchemistWorkQueue? queue;
  String _key(String runId) =>
      'feedback22:${digest22([owner() ?? 'local', runId])}';
  Future<Map<String, dynamic>?> load(String runId) async {
    final a = owner(),
        rows = await db.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [_key(runId)],
        );
    if (a != owner() || rows.isEmpty) return null;
    return Map<String, dynamic>.from(
      jsonDecode(rows.single['value'] as String),
    );
  }

  Future<void> save(
    SessionRun run,
    int rating, {
    Map<String, dynamic>? exactTarget,
    String? recordKey,
    Map<String, dynamic>? execution,
    List<Map<String, dynamic>> occurrences = const [],
    List<Map<String, dynamic>> componentRatings = const [],
  }) async {
    if (rating < 1 || rating > 5) {
      throw const FormatException('Оценка от 1 до 5');
    }
    final key = recordKey ?? run.id;
    final a = owner(), old = await load(key);
    final captured = await playbackFeedback22(db, run, owner: a);
    exactTarget ??= captured?['target'];
    if (occurrences.isEmpty && captured != null) {
      occurrences = List<Map<String, dynamic>>.from(captured['occurrences']);
    }
    final target =
        exactTarget ??
        old?['feedback']?['target'] ??
        {
          'type': 'PROGRAM',
          'contentId':
              run.snapshot.baseTemplateId ??
              'local-${digest22(run.snapshot.plan.toMap())}',
          'revisionId':
              run.snapshot.baseFingerprint ??
              digest22(run.snapshot.plan.toMap()),
          'ratingEpochId': 'local-unresolved',
        };
    final feedback = {
      'schemaVersion': 1,
      'feedbackId': old?['feedback']?['feedbackId'] ?? newId(),
      'sequence': (old?['serverSequence'] as int? ?? 0) + 1,
      'target': target,
      'rating': rating,
      'execution':
          execution ??
          {
            'executionId': run.id,
            'manifestHash': digest22(run.snapshot.plan.toMap()),
            'partialExecution': run.status != RunStatus.completed,
          },
      'occurrences': occurrences,
      'componentRatings': componentRatings,
      'consent': {'schemaVersion': 1, 'share': false},
      'sourceApp': 'CLIENT',
    };
    await db.transaction((tx) async {
      if (a != owner()) throw const FormatException('ACCOUNT_CHANGED');
      await tx.insert('app_settings', {
        'name': _key(key),
        'value': jsonEncode({
          ...?old,
          'ownerBinding': a,
          'runId': run.id,
          'feedback': feedback,
          'shareReady':
              target['ratingEpochId'] != 'local-unresolved' &&
              (exactTarget != null || old?['shareReady'] == true),
          'localOnly': true,
          'dirty': true,
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<String> consent(String runId, bool share) async {
    final old = await load(runId), a = owner();
    if (old == null ||
        a == null ||
        runtime == null ||
        queue == null ||
        old['shareReady'] != true) {
      throw const FormatException('Нет подтверждённой редакции и подключения');
    }
    final sequence = (old['serverSequence'] as int? ?? 0) + 1;
    final feedback = Map<String, dynamic>.from(old['feedback']);
    feedback['sequence'] = sequence;
    feedback['consent'] = {'schemaVersion': 1, 'share': share};
    final requestId = 'feedback22-${feedback['feedbackId']}-$sequence',
        name = 'alchemist_download:$a:$requestId';
    final payload = {'requestId': requestId, 'feedback': feedback};
    await queue!.enqueueDownload(name, {
      'kind': 'feedback22',
      'scope': runtime!.scope,
      'payload': payload,
      'runId': runId,
    });
    return name;
  }

  Future<void> execute(Map<String, dynamic> row, bool Function() stop) async {
    final a = owner();
    if (a == null || row['ownerBinding'] != a || stop()) {
      throw const FormatException('ACCOUNT_CHANGED');
    }
    final d = row['download'],
        payload = Map<String, dynamic>.from(d['payload']);
    final result = await runtime!.call('feedback.ingest', payload);
    if (result['feedbackId'] != payload['feedback']['feedbackId'] ||
        result['sequence'] != payload['feedback']['sequence'] ||
        result['accepted'] != true ||
        result['shared'] != payload['feedback']['consent']['share']) {
      throw const FormatException('FEEDBACK_RECEIPT_INVALID');
    }
    await db.transaction((tx) async {
      if (a != owner() || stop()) {
        throw const FormatException('ACCOUNT_CHANGED');
      }
      final key = _key(d['runId']);
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [key],
      );
      if (rows.isEmpty) return;
      final v = Map<String, dynamic>.from(
        jsonDecode(rows.single['value'] as String),
      );
      final local = Map<String, dynamic>.from(v['feedback']);
      final sent = Map<String, dynamic>.from(payload['feedback']);
      local.remove('sequence');
      local.remove('consent');
      sent.remove('sequence');
      sent.remove('consent');
      final dirty = digest22(local) != digest22(sent);
      await tx.insert('app_settings', {
        'name': key,
        'value': jsonEncode({
          ...v,
          'serverSequence': result['sequence'],
          'receipt': result,
          'localOnly': !result['shared'],
          'dirty': dirty,
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
