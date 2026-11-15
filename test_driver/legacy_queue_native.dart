// Controlled Android SQLite conversion proof only; never imported by main.dart.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';

Future<Map<String, dynamic>> checkLegacyQueueNative18(
  Database db,
  Directory root,
  String owner,
) async {
  if (!Platform.isAndroid || !root.path.contains('.transferprobe/')) {
    throw StateError('DISPOSABLE_ANDROID_FIXTURE_REQUIRED');
  }
  final qemu = await Process.run('/system/bin/getprop', ['ro.kernel.qemu']);
  if (qemu.stdout.toString().trim() != '1') {
    throw StateError('DISPOSABLE_EMULATOR_REQUIRED');
  }
  void check(bool ok, String code) {
    if (!ok) throw StateError(code);
  }

  final before = await db.query('app_settings', orderBy: 'name');
  final prefix = 'alchemist_card:controlled_native18_legacy_';
  final checkpointKey = 'alchemist_upload:controlled_native18_legacy_running';
  final names = [
    '${prefix}running',
    '${prefix}queued',
    '${prefix}paused',
    '${prefix}foreign',
    '${prefix}unbound',
    checkpointKey,
  ];
  check(!before.any((r) => names.contains(r['name'])), 'FIXTURE_KEY_COLLISION');
  final values = <String, Map<String, dynamic>>{};
  for (final kind in ['running', 'queued', 'paused', 'foreign', 'unbound']) {
    final who = kind == 'unbound'
        ? null
        : kind == 'foreign'
        ? 'controlled-foreign-owner18'
        : owner;
    final v = <String, dynamic>{
      'ownerBinding': who,
      'card': {'title': 'CONTROLLED native legacy27 $kind'},
      'pending': {
        'operation': 'catalog.publish',
        'parameters': {'requestId': 'original27-$kind', 'ifMatch': '7'},
      },
    };
    v['_work'] = {
      'phase': kind == 'paused'
          ? 'paused'
          : kind == 'queued'
          ? 'queued'
          : 'running',
      'stage': 'server_verifying',
      'ownerBinding': who,
      'taskId': 'controlled-native-old27-$kind',
      'revision': queueRevision(v),
      'runnerEpoch': 'old27',
      'bytes': 262144,
      'totalBytes': 15728640,
      'attempts': 2,
      'networkRetries': 1,
      if (kind == 'paused') ...{
        'code': 'USER_PAUSED',
        'pauseReason': 'USER_PAUSED',
      },
    };
    values['$prefix$kind'] = v;
  }
  final checkpoint = jsonEncode({
    'ownerBinding': owner,
    'sessionId': 'original-native-session27',
    'requestId': 'original-native-upload27',
    'offset': 262144,
    'receipt': null,
  });
  await db.transaction((tx) async {
    for (final e in values.entries) {
      await tx.insert('app_settings', {
        'name': e.key,
        'value': jsonEncode(e.value),
      });
    }
    await tx.insert('app_settings', {
      'name': checkpointKey,
      'value': checkpoint,
    });
  });
  var dispatches = 0;
  final queue = AlchemistWorkQueue(
    db: db,
    owner: () => owner,
    dispatch: () async => dispatches++,
    send: (_, _, _, _, _) async =>
        throw StateError('NATIVE_LEGACY_FIXTURE_MUST_NOT_SEND'),
  );
  Future<String> raw(String name) async =>
      (await db.query(
            'app_settings',
            where: 'name=?',
            whereArgs: [name],
          )).single['value']
          as String;
  try {
    await queue.recover();
    check(dispatches == 0, 'LEGACY_AUTO_DISPATCH_FORBIDDEN');
    for (final kind in ['running', 'queued']) {
      final v = jsonDecode(await raw('$prefix$kind')) as Map;
      check(
        v['_work']['phase'] == 'waiting_policy' &&
            v['_work']['autoResume'] == false &&
            v['_work']['legacyPhase'] == kind,
        'LEGACY_NOT_SAFE_POLICY_WAIT',
      );
    }
    for (final kind in ['paused', 'foreign', 'unbound']) {
      check(
        await raw('$prefix$kind') == jsonEncode(values['$prefix$kind']),
        'PAUSED_FOREIGN_OR_UNBOUND_BYTES_CHANGED',
      );
    }
    var denied = false;
    try {
      await queue.enqueue('${prefix}foreign');
    } catch (_) {
      denied = true;
    }
    check(denied && dispatches == 0, 'FOREIGN_OWNER_DISPATCHED');
    await queue.enqueue('${prefix}running');
    final resumed = jsonDecode(await raw('${prefix}running')) as Map;
    check(dispatches == 1, 'EXPLICIT_RESUME_NOT_DISPATCHED');
    check(
      resumed['_work']['executor'] == 'android18' &&
          resumed['_work']['taskId'] == 'controlled-native-old27-running' &&
          resumed['_work']['bytes'] == 262144 &&
          resumed['_work']['attempts'] == 2,
      'NATIVE_QUEUE_ID_BYTES_ATTEMPTS_LOST',
    );
    check(
      jsonEncode(resumed['pending']) ==
          jsonEncode(values['${prefix}running']!['pending']),
      'ORIGINAL_REQUEST_OR_ETAG_CHANGED',
    );
    check(await raw(checkpointKey) == checkpoint, 'UPLOAD_CHECKPOINT_CHANGED');
    return {
      'status': 'PASS',
      'classification': 'CONTROLLED_NATIVE_ANDROID_SQLITE_OLD27_SHAPE',
      'sqliteUserVersion': Sqflite.firstIntValue(
        await db.rawQuery('PRAGMA user_version'),
      ),
      'integrity': (await db.rawQuery('PRAGMA integrity_check'))
          .first
          .values
          .first,
      'runningAndQueuedConvertToPolicyWait': true,
      'noLegacyAutoDispatch': true,
      'userPausedForeignAndUnboundExactBytes': true,
      'foreignResumeDenied': true,
      'sameTaskBytesAttemptsRequestETagAndUploadSession': true,
      'dispatch': 'CONTROLLED_NO_NETWORK_NOT_OS_WORKER_PROOF',
      'realGoogle': 'NOT_RUN',
      'normalApkUpgrade': 'SEPARATE_GATE_NOT_THIS_PROOF',
      'beforeNonFixtureSettingsSHA256': sha256
          .convert(utf8.encode(jsonEncode(before)))
          .toString(),
    };
  } finally {
    queue.dispose();
    // Teardown only the fixed synthetic names inserted above, never user rows.
    await db.transaction((tx) async {
      for (final name in names) {
        await tx.delete('app_settings', where: 'name=?', whereArgs: [name]);
      }
    });
    final after = await db.query('app_settings', orderBy: 'name');
    check(
      jsonEncode(before) == jsonEncode(after),
      'NON_FIXTURE_SETTINGS_CHANGED',
    );
  }
}
