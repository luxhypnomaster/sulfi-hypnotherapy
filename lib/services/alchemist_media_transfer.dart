import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import 'alchemist_api.dart';

/// Persistent request identity and bounded, seekable file transfer. Blob commit
/// never implies publication; callers publish a separate validated manifest.
class AlchemistMediaTransfer {
  AlchemistMediaTransfer(this.db, this.api);
  final Database db;
  final AlchemistApi api;
  Future<Map<String, dynamic>> upload(
    File file, {
    required String logicalId,
    required String revisionId,
    required String mime,
    String? expectedHash,
    bool restartExpired = true,
    bool Function()? interrupted,
    void Function(int, int)? progress,
  }) async {
    void check() {
      if (interrupted?.call() == true) {
        throw const FormatException(
          'Передача приостановлена. Черновик сохранён.',
        );
      }
    }

    final size = await file.length();
    final hash = (await sha256.bind(file.openRead()).first).toString();
    if (size == 0 || expectedHash != null && expectedHash != hash) {
      throw const FormatException('Файл изменён или пуст');
    }
    final key = 'alchemist_upload:$logicalId:$revisionId:$hash';
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [key],
    );
    final requestId = rows.isEmpty
        ? newId()
        : jsonDecode(rows.single['value'] as String)['requestId'];
    final state = <String, dynamic>{
      'requestId': requestId,
      'sha256': hash,
      'byteLength': size,
      'logicalId': logicalId,
      'revisionId': revisionId,
      'mime': mime,
      'state': 'uploading',
    };
    Future<void> checkpoint() => db
        .insert('app_settings', {
          'name': key,
          'value': jsonEncode(state),
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        .then((_) {});
    await checkpoint();
    check();
    try {
      final start = await api.call('media.beginUpload', {
        'requestId': requestId,
        'logicalId': logicalId,
        'revisionId': revisionId,
        'sha256': hash,
        'byteLength': size,
        'mime': mime,
      });
      state['sessionId'] = start['sessionId'];
      state['localPath'] = file.path;
      await checkpoint();
      var offset = start['offset'] as int;
      if (offset < 0 || offset > size) {
        throw const FormatException('Некорректная позиция передачи');
      }
      final input = await file.open();
      try {
        while (offset < size) {
          check();
          await input.setPosition(offset);
          final bytes = await input.read(262144);
          if (bytes.isEmpty) throw const FormatException('Файл оборвался');
          final result = await api.call('media.uploadChunk', {
            'sessionId': start['sessionId'],
            'offset': offset,
            'base64': base64Encode(bytes),
          });
          final next = result['offset'];
          if (next is! int || next != offset + bytes.length) {
            throw const FormatException('Сервер не подтвердил блок');
          }
          offset = next;
          state['offset'] = offset;
          await checkpoint();
          progress?.call(offset, size);
        }
      } finally {
        await input.close();
      }
      Map<String, dynamic> result;
      do {
        check();
        result = await api.call('media.commitUpload', {
          'sessionId': start['sessionId'],
        });
        if (result['state'] == 'verifying') {
          progress?.call(result['verifiedBytes'] as int, size);
        }
      } while (result['state'] == 'verifying');
      if (result['sha256'] != hash ||
          result['byteLength'] != size ||
          result['logicalId'] != logicalId ||
          result['revisionId'] != revisionId) {
        throw const FormatException('Сервер не подтвердил файл');
      }
      state['state'] = 'verified';
      state['assetRevisionId'] = result['assetRevisionId'];
      await checkpoint();
      return result;
    } catch (e) {
      if (e is AlchemistApiException && e.status == 410 && restartExpired) {
        state['requestId'] = newId();
        state['state'] = 'expired';
        await checkpoint();
        return upload(
          file,
          logicalId: logicalId,
          revisionId: revisionId,
          mime: mime,
          expectedHash: expectedHash,
          restartExpired: false,
          interrupted: interrupted,
          progress: progress,
        );
      }
      state['state'] = interrupted?.call() == true ? 'paused' : 'failed';
      state['error'] = e.toString();
      await checkpoint();
      rethrow;
    }
  }
}
