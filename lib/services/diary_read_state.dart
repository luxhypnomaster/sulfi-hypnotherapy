import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import '../models/session_plan.dart';

/// Device-local app_settings namespace. Excluded from public and content exports.
/// No user schema migration or destructive rewrite is needed.
class DiaryReadStore {
  // Explicit reader IDs are for isolated local profiles/conformance fixtures.
  // ignore: prefer_initializing_formals
  DiaryReadStore(this.db, {String? readerId}) : _readerId = readerId;
  final Database db;
  String? _readerId;
  String get readerId => _readerId!;
  bool get loaded => _readerId != null;
  final _states = <String, Map<String, dynamic>>{};
  Future<void>? _tail;
  Future<void> switchReader(String? id) async {
    if (_tail != null) await _tail;
    _readerId = id;
    _states.clear();
    await load();
  }

  Future<void> load() async {
    if (_readerId == null) {
      await db.transaction((tx) async {
        final rows = await tx.query(
          'app_settings',
          where: 'name=?',
          whereArgs: ['diary_reader_identity'],
        );
        _readerId = rows.firstOrNull?['value'] as String? ?? newId();
        await tx.insert('app_settings', {
          'name': 'diary_reader_identity',
          'value': readerId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });
    }
    if (_tail != null) await _tail;
    for (final r in await db.query(
      'app_settings',
      where: 'name LIKE ?',
      whereArgs: ['diary_read:%'],
    )) {
      try {
        final state = Map<String, dynamic>.from(
          jsonDecode(r['value'] as String),
        );
        if (state['readerId'] == readerId) {
          _states.putIfAbsent(r['name'] as String, () => state);
        }
      } catch (_) {
        /* Preserve an unreadable row rather than infer completion. */
      }
    }
  }

  String key(DiaryEntry e) =>
      'diary_read:${jsonEncode([readerId, e.id, DiaryPublication.of(e).cycle])}';
  Map<String, dynamic> state(DiaryEntry e) =>
      _readerId == null ? {} : Map.of(_states[key(e)] ?? {});
  String fingerprint(DiaryEntry e) => jsonEncode(
    e.blocks
        .map((b) => [b.id, b.text, b.media?.hash, b.media?.assetId])
        .toList(),
  );
  bool isRead(DiaryEntry e) => state(e)['read'] == true;
  Future<void> progress(
    DiaryEntry e, {
    bool textEnd = false,
    int? page,
    String? audioId,
    List<List<int>>? intervals,
    bool audioDone = false,
  }) {
    // Update memory synchronously; serialize SQLite writes to avoid lost partial progress.
    final k = key(e), old = state(e);
    if (old['read'] != true && old['fingerprint'] != fingerprint(e)) {
      old.clear();
    }
    final audios = Map<String, dynamic>.from(old['audio'] ?? {});
    if (audioId != null) {
      audios[audioId] = {
        'intervals': intervals ?? const [],
        'done':
            audioDone ||
            (audios[audioId] is Map && audios[audioId]['done'] == true),
      };
    }
    final hasVisual = e.blocks.any(
      (b) => b.substantive && b.type != DiaryBlockType.audio,
    );
    final visualDone = !hasVisual || textEnd || old['textEnd'] == true;
    final audioBlocks = e.blocks.where(
      (b) => b.substantive && b.type == DiaryBlockType.audio,
    );
    final read =
        old['read'] == true ||
        (visualDone &&
            audioBlocks.every(
              (b) => audios[b.id] is Map && audios[b.id]['done'] == true,
            ));
    final value = <String, dynamic>{
      ...old,
      'readerId': readerId,
      'entryId': e.id,
      'activationCycleId': DiaryPublication.of(e).cycle,
      'fingerprint': fingerprint(e),
      'textEnd': visualDone,
      'page': page ?? old['page'] ?? 0,
      'audio': audios,
      'read': read,
    };
    _states[k] = value;
    final snapshot = jsonEncode(value);
    final op = (_tail ?? Future<void>.value()).then(
      (_) => db.insert('app_settings', {
        'name': k,
        'value': snapshot,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _tail = op.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return op.then((_) {});
  }

  String syncFingerprint(DiaryEntry e) =>
      sha256.convert(utf8.encode(fingerprint(e))).toString();
  List<Map<String, dynamic>> syncSnapshot(List<DiaryEntry> entries) => [
    for (final e in entries)
      if (state(e).isNotEmpty)
        {
          'entryId': e.id,
          'cycle': DiaryPublication.of(e).cycle,
          'fingerprint': syncFingerprint(e),
          'read': isRead(e),
          'page': state(e)['page'] ?? 0,
        },
  ];
  Future<void> mergeSynced(DiaryEntry e, Map<String, dynamic> remote) async {
    if (remote['cycle'] != DiaryPublication.of(e).cycle ||
        remote['fingerprint'] != syncFingerprint(e) && remote['read'] != true) {
      return;
    }
    final old = state(e),
        value = <String, dynamic>{
          ...old,
          'readerId': readerId,
          'entryId': e.id,
          'activationCycleId': DiaryPublication.of(e).cycle,
          'fingerprint': fingerprint(e),
          'read': old['read'] == true || remote['read'] == true,
          'page': (old['page'] as int? ?? 0) > (remote['page'] as int)
              ? old['page']
              : remote['page'],
        };
    _states[key(e)] = value;
    await db.insert('app_settings', {
      'name': key(e),
      'value': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> flush() async {
    if (_tail != null) await _tail;
  }
}

/// Credits only continuous playback, bounded by elapsed wall time. A jump/seek
/// never contributes heard time. Completion requires both native EOF and coverage.
class HeardAudio {
  HeardAudio({List<List<int>> intervals = const []}) {
    for (final i in intervals) {
      _merge(i[0], i[1]);
    }
  }
  final List<List<int>> intervals = [];
  int? _position, _time;
  bool _playing = false;
  int? _epoch;
  bool sample({
    required int position,
    required int nowMs,
    required bool playing,
    required bool completed,
    required int duration,
    required int seekEpoch,
  }) {
    final previous = _position, time = _time;
    if (previous != null && time != null && _playing && _epoch == seekEpoch) {
      final delta = position - previous;
      if (delta > 0 && delta <= nowMs - time + 300 && nowMs >= time) {
        _merge(previous, position);
      }
    }
    _position = position;
    _time = nowMs;
    _playing = playing;
    _epoch = seekEpoch;
    return completed &&
        duration > 0 &&
        intervals.length == 1 &&
        intervals.first[0] <= 100 &&
        intervals.first[1] >= duration - 100;
  }

  void _merge(int start, int end) {
    if (start < 0 || end <= start) return;
    intervals.add([start, end]);
    intervals.sort((a, b) => a[0].compareTo(b[0]));
    for (var i = 1; i < intervals.length;) {
      if (intervals[i][0] <= intervals[i - 1][1] + 100) {
        intervals[i - 1][1] = intervals[i][1] > intervals[i - 1][1]
            ? intervals[i][1]
            : intervals[i - 1][1];
        intervals.removeAt(i);
      } else {
        i++;
      }
    }
  }
}
