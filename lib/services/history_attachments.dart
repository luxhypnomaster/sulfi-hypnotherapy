import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/diary_entry.dart';
import '../models/session_plan.dart';
import 'diary_media_store.dart';

/// Mutable personal annotations never modify run payloads or execution hashes.
class HistoryAttachment {
  HistoryAttachment({
    required this.id,
    required this.runId,
    required this.block,
    required this.createdAt,
    this.transcription,
  });
  final String id, runId;
  final DiaryBlock block;
  final DateTime createdAt;
  // Future STT contract; no engine, model download or inactive action in v6.
  // text, language, segments, engine, status, timestamp, version, correctedText.
  final Map<String, dynamic>? transcription;
  Map<String, dynamic> toMap() => {
    'id': id,
    'runId': runId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'block': block.toMap(),
    if (transcription != null) 'transcription': transcription,
  };
  factory HistoryAttachment.fromMap(Map<String, dynamic> m) =>
      HistoryAttachment(
        id: m['id'],
        runId: m['runId'],
        block: DiaryBlock.fromMap(Map<String, dynamic>.from(m['block'])),
        createdAt: DateTime.parse(m['createdAt']),
        transcription: m['transcription'] == null
            ? null
            : Map<String, dynamic>.from(m['transcription']),
      );
}

class HistoryAttachments {
  HistoryAttachments(this.database, this.media);
  final Database database;
  final DiaryMediaStore media;
  Future<List<HistoryAttachment>> list(String runId) async =>
      (await database.query(
            'history_attachments',
            where: 'runId=?',
            whereArgs: [runId],
            orderBy: 'rowid',
          ))
          .map(
            (r) =>
                HistoryAttachment.fromMap(jsonDecode(r['payload'] as String)),
          )
          .toList();
  Future<HistoryAttachment> attach(String runId, DiaryBlock block) async {
    final a = HistoryAttachment(
      id: newId(),
      runId: runId,
      block: block,
      createdAt: DateTime.now().toUtc(),
    );
    final file = media.file(block.media);
    if (file == null || !await file.exists()) {
      throw const FormatException('Файл вложения недоступен');
    }
    await database.transaction((tx) async {
      final rows = await tx.query(
        'session_runs',
        columns: ['status'],
        where: 'id=?',
        whereArgs: [runId],
      );
      if (rows.isEmpty ||
          [
            'running',
            'paused',
            'exitingEarly',
          ].contains(rows.single['status'])) {
        throw const FormatException('Сначала завершите сессию');
      }
      await tx.insert('history_attachments', {
        'id': a.id,
        'runId': runId,
        'payload': jsonEncode(a.toMap()),
      });
    });
    return a;
  }

  Future<void> remove(String runId, String id) async {
    await database.delete(
      'history_attachments',
      where: 'id=? AND runId=?',
      whereArgs: [id, runId],
    );
    // File reclamation only at startup with all references. Playback can retain
    // an open file and undo/other records must never lose shared bytes.
  }

  Future<void> collect() async {
    final rows = await database.query('history_attachments');
    final retained = <String>{};
    for (final row in rows) {
      // Corrupt metadata aborts collection, preserving all original media.
      final a = HistoryAttachment.fromMap(jsonDecode(row['payload'] as String));
      final file = media.file(a.block.media);
      if (file == null || !await file.exists()) {
        throw const FormatException(
          'Ссылки требуют восстановления; уборка отменена',
        );
      }
      retained.add(file.path);
    }
    await media.collect(retained);
  }
}
