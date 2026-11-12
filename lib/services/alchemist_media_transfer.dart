import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/session_plan.dart';
import 'alchemist_api.dart';
import 'alchemist_errors.dart';
import 'diary_api.dart';

/// Existing upload checkpoints, now account-bound. Never trusts a byte counter
/// as a commit receipt and never deletes a local source on pause/cancel/failure.
class AlchemistMediaTransfer {
  AlchemistMediaTransfer(this.db, this.api);
  final Database db;
  final AlchemistApi api;
  static final Map<String, Future<Map<String, dynamic>>> _active = {};
  Future<Map<String, dynamic>> upload(
    File file, {
    required String logicalId,
    required String revisionId,
    required String mime,
    String? expectedHash,
    bool restartExpired = true,
    String? taskId,
    bool Function()? interrupted,
    void Function(int, int)? progress,
    void Function(String)? onStage,
  }) async {
    final size = await file.length(),
        hash = (await sha256.bind(file.openRead()).first).toString();
    if (size == 0 || expectedHash != null && expectedHash != hash) {
      throw const FormatException('Файл изменён или пуст');
    }
    if (api.identityScope != null && api.ownerBinding == null) {
      throw const AlchemistFailure(
        'Подтвердите вход Google перед отправкой.',
        401,
        'AUTH_REQUIRED',
        DiaryFailure.authorization,
      );
    }
    final owner = api.ownerBinding ?? 'controlled-${identityHashCode(api)}';
    final activeKey =
        '${identityHashCode(db)}:$owner:$logicalId:$revisionId:$hash';
    final existing = _active[activeKey];
    if (existing != null) return existing;
    late Future<Map<String, dynamic>> future;
    future =
        _upload(
          file,
          size,
          hash,
          owner,
          logicalId,
          revisionId,
          mime,
          restartExpired,
          taskId,
          interrupted,
          progress,
          onStage,
        ).whenComplete(() {
          if (identical(_active[activeKey], future)) _active.remove(activeKey);
        });
    _active[activeKey] = future;
    return future;
  }

  Future<Map<String, dynamic>> _upload(
    File file,
    int size,
    String hash,
    String owner,
    String logicalId,
    String revisionId,
    String mime,
    bool restartExpired,
    String? taskId,
    bool Function()? interrupted,
    void Function(int, int)? progress,
    void Function(String)? onStage,
  ) async {
    final scope = api.currentIdentityScope, epoch = api.identityEpoch?.call();
    void check() {
      if (scope != api.currentIdentityScope ||
          epoch != api.identityEpoch?.call()) {
        throw const AlchemistFailure(
          'Аккаунт изменился. Передача приостановлена.',
          401,
          'ACCOUNT_CHANGED',
          DiaryFailure.authorization,
        );
      }
      if (interrupted?.call() == true) {
        throw const AlchemistFailure(
          'Передача приостановлена. Черновик сохранён.',
          0,
          'TRANSFER_PAUSED',
          DiaryFailure.blocked,
        );
      }
    }

    final key = 'alchemist_upload:$owner:$logicalId:$revisionId:$hash';
    final rows = await db.query(
      'app_settings',
      where: 'name=?',
      whereArgs: [key],
    );
    final state = rows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(rows.single['value'] as String));
    state.addAll({
      'requestId': state['requestId'] ?? newId(),
      'ownerBinding': owner,
      'sha256': hash,
      'byteLength': size,
      'logicalId': logicalId,
      'revisionId': revisionId,
      'mime': mime,
      'localPath': file.path,
      'state': 'queued',
      'taskId': ?taskId,
    });
    Future<void> checkpoint() => db
        .insert('app_settings', {
          'name': key,
          'value': jsonEncode(state),
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        .then((_) {});
    Future<void> stage(String phase) async {
      state['state'] = phase;
      await checkpoint();
      onStage?.call(phase);
    }

    check();
    await checkpoint();
    try {
      if (state['receipt'] is Map) {
        check();
        final descriptor = await api.call('media.getDescriptor', {
          'assetRevisionId': state['receipt']['assetRevisionId'],
        });
        check();
        if (descriptor['sha256'] != hash ||
            descriptor['byteLength'] != size ||
            descriptor['logicalId'] != logicalId ||
            descriptor['revisionId'] != revisionId ||
            descriptor['mime'] != mime) {
          throw const FormatException(
            'Сервер не подтвердил прежнюю версию файла',
          );
        }
        progress?.call(size, size);
        await stage('verified');
        return Map<String, dynamic>.from(state['receipt']);
      }
      check();
      await stage('transferring');
      final start = await api.call('media.beginUpload', {
        'requestId': state['requestId'],
        'logicalId': logicalId,
        'revisionId': revisionId,
        'sha256': hash,
        'byteLength': size,
        'mime': mime,
      });
      check();
      state['sessionId'] = start['sessionId'];
      var offset = start['offset'] as int;
      if (offset < 0 || offset > size) {
        throw const FormatException('Некорректная позиция передачи');
      }
      state['offset'] = offset;
      await checkpoint();
      progress?.call(offset, size);
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
          check();
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
      await stage('bytes_acked');
      check();
      await stage('server_verifying');
      Map<String, dynamic> result;
      var previousVerified = -1, stalled = 0;
      do {
        check();
        result = await api.call('media.commitUpload', {
          'sessionId': start['sessionId'],
        });
        check();
        if (result['state'] == 'verifying') {
          final verified = result['verifiedBytes'];
          if (verified is! int ||
              verified < 0 ||
              verified > size ||
              verified < previousVerified) {
            throw const FormatException('Некорректная проверка файла');
          }
          stalled = verified == previousVerified ? stalled + 1 : 0;
          previousVerified = verified;
          if (stalled >= 3) {
            throw const AlchemistFailure(
              'Проверка на сервере остановилась. Можно продолжить позже.',
              503,
              'VERIFICATION_STALLED',
              DiaryFailure.network,
              true,
            );
          }
          state['verifiedBytes'] = verified;
          await checkpoint();
        }
      } while (result['state'] == 'verifying');
      if (result['sha256'] != hash ||
          result['byteLength'] != size ||
          result['logicalId'] != logicalId ||
          result['revisionId'] != revisionId ||
          result['assetRevisionId'] is! String) {
        throw const FormatException('Сервер не подтвердил файл');
      }
      state['assetRevisionId'] = result['assetRevisionId'];
      state['receipt'] = result;
      await stage('verified');
      return result;
    } catch (e) {
      if (e is AlchemistApiException && e.status == 410 && restartExpired) {
        state['requestId'] = newId();
        state.remove('receipt');
        state.remove('sessionId');
        await stage('expired');
        return _upload(
          file,
          size,
          hash,
          owner,
          logicalId,
          revisionId,
          mime,
          false,
          taskId,
          interrupted,
          progress,
          onStage,
        );
      }
      final failure = AlchemistFailure.from(e);
      state['state'] = interrupted?.call() == true
          ? 'paused'
          : failure.retryable
          ? 'failed_retryable'
          : 'failed_final';
      state['error'] = failure.message;
      state['errorCode'] = failure.code;
      state['httpStatus'] = failure.status;
      await checkpoint();
      rethrow;
    }
  }
}
