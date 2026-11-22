import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import '../models/session_timeline.dart';
import '../models/ratings22.dart';

/// Device playback intervals, never attention/efficacy. A seek discontinuity is
/// not listening. Gaps/unknown samples are retained conservatively.
class Playback22Evidence {
  final ranges = <String, List<List<int>>>{};
  String? _id;
  int? _position, _wall;
  void discontinuity() {
    _id = null;
    _position = null;
    _wall = null;
  }

  void sample(
    String id,
    int position,
    int wall, {
    required bool playing,
    required int durationMs,
  }) {
    if (!playing || position < 0 || durationMs <= 0) {
      discontinuity();
      return;
    }
    if (_id == id && _position != null && _wall != null) {
      final delta = position - _position!, elapsed = wall - _wall!;
      //50ms is sampling jitter tolerance, not a rating/exposure weight.
      if (delta > 0 &&
          elapsed > 0 &&
          elapsed <= 5000 &&
          delta <= elapsed + 50) {
        final start = _position!.clamp(0, durationMs),
            end = position.clamp(0, durationMs);
        if (end > start) {
          final list = ranges.putIfAbsent(id, () => []);
          list.add([start, end]);
          list.sort((a, b) => a[0].compareTo(b[0]));
          final merged = <List<int>>[];
          for (final r in list) {
            if (merged.isNotEmpty && r[0] <= merged.last[1]) {
              if (r[1] > merged.last[1]) merged.last[1] = r[1];
            } else {
              merged.add(List.of(r));
            }
          }
          ranges[id] = merged;
        }
      }
    }
    _id = id;
    _position = position;
    _wall = wall;
  }

  int played(String id) =>
      ranges[id]?.fold<int>(0, (n, r) => n + r[1] - r[0]) ?? 0;
  Map<String, dynamic> snapshot(SessionRun run) => {
    'schemaVersion': 1,
    'runId': run.id,
    'manifestHash': digest22(run.snapshot.plan.toMap()),
    'intervals': ranges,
  };
}

Future<void> savePlayback22(
  Database db,
  SessionRun run,
  Playback22Evidence evidence,
) => db
    .insert('app_settings', {
      'name': 'playback22:${run.id}',
      'value': jsonEncode(evidence.snapshot(run)),
    }, conflictAlgorithm: ConflictAlgorithm.replace)
    .then((_) {});

/// This registry is frozen from already verified local catalog metadata at run
/// start. No network or identity picker and no guess about a missing epoch.
Future<void> freezeSources22(
  Database db,
  SessionRun run,
  List<Map<String, dynamic>> catalogItems, {
  required String owner,
  required String expectedRevision,
}) async {
  final refs = <String, Map<String, dynamic>>{};
  for (final r in catalogItems) {
    if (r['ratingEpochId'] is! String) continue;
    refs[r['contentId']] = {
      'type': r['type'] == 'template'
          ? 'PROGRAM'
          : r['type'].toString().toUpperCase(),
      'contentId': r['contentId'],
      'revisionId': r['revisionId'],
      'ratingEpochId': r['ratingEpochId'],
    };
  }
  final root = refs[run.snapshot.baseTemplateId];
  if (root == null ||
      root['revisionId'] != expectedRevision ||
      run.snapshot.baseFingerprint != run.snapshot.plan.fingerprint) {
    return;
  }
  await db.insert('app_settings', {
    'name': 'feedback22_sources:${run.id}',
    'value': jsonEncode({
      'ownerBinding': owner,
      'manifestHash': digest22(run.snapshot.plan.toMap()),
      'root': root,
      'refs': refs,
    }),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<Map<String, dynamic>?> playbackFeedback22(
  Database db,
  SessionRun run, {
  required String? owner,
}) async {
  final sources = await db.query(
    'app_settings',
    where: 'name=?',
    whereArgs: ['feedback22_sources:${run.id}'],
  );
  if (sources.isEmpty) return null;
  final src = Map<String, dynamic>.from(
    jsonDecode(sources.single['value'] as String),
  );
  if (src['ownerBinding'] != owner ||
      src['manifestHash'] != digest22(run.snapshot.plan.toMap())) {
    return null;
  }
  final rows = await db.query(
    'app_settings',
    where: 'name=?',
    whereArgs: ['playback22:${run.id}'],
  );
  final evidence = rows.isEmpty
      ? null
      : jsonDecode(rows.single['value'] as String);
  final valid = evidence?['manifestHash'] == src['manifestHash'];
  final occurrences = <Map<String, dynamic>>[];
  for (final entry in SessionTimeline(run.snapshot.plan).entries) {
    final ref = src['refs'][entry.step.audioAssetId];
    if (ref == null) continue;
    final duration = entry.step.durationMs ?? 0;
    final ranges = valid ? evidence['intervals'][entry.step.id] as List? : null;
    final played =
        ranges?.fold<int>(0, (sum, r) => sum + (r[1] as int) - (r[0] as int)) ??
        0;
    final status = !valid
        ? 'UNKNOWN'
        : played == 0
        ? 'NOT_EXPOSED'
        : played == duration && duration > 0
        ? 'COMPLETED'
        : 'PARTIAL';
    occurrences.add({
      'occurrenceId': entry.step.id,
      'target': ref,
      'status': status,
      'playedMs': played,
      'durationMs': duration,
    });
  }
  return {'target': src['root'], 'occurrences': occurrences};
}
