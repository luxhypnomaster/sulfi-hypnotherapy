// Disposable two-handle Android sqflite lock-order experiment only.
// No production library DB, media, Google identity, or schema is touched.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<Map<String, dynamic>> sqliteConcurrencyNative18() async {
  const parallel = String.fromEnvironment('SULFI_EDITION') == 'client';
  // The package has not opened any DB yet. Changing a live pool is forbidden.
  if (parallel) {
    await const MethodChannel('com.tekartik.sqflite')
        .invokeMethod<void>('options', {'androidThreadCount': 4});
  }
  final root = await getApplicationSupportDirectory();
  final fixtures = Directory(p.join(root.path, 'sqlite_lock_fixture18'));
  await fixtures.create(recursive: true);
  final stage = await fixtures.createTemp('two-handles-');
  final path = p.join(stage.path, 'isolated.sqlite');
  final a = await openDatabase(path, singleInstance: false);
  await a.execute('CREATE TABLE fixture(id INTEGER PRIMARY KEY, value TEXT)');
  final b = await openDatabase(path, singleInstance: false);
  final events = <String>[];
  final entered = Completer<void>();
  final release = Completer<void>();
  final first = a.transaction((tx) async {
    await tx.insert('fixture', {'id': 1, 'value': 'writer-a'});
    events.add('a_inserted_transaction_open');
    entered.complete();
    await release.future;
    events.add('a_commit_requested');
  });
  await entered.future;
  events.add('b_write_requested_while_a_transaction_open');
  final second = b.insert('fixture', {'id': 2, 'value': 'writer-b'}).then((_) {
    events.add('b_write_completed');
  });
  // Deliberately enqueue B's SQLite lock wait before A's COMMIT callback.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  release.complete();
  String outcome;
  try {
    await Future.wait([first, second]).timeout(const Duration(seconds: 15));
    final rows = await a.query('fixture', orderBy: 'id');
    if (rows.length != 2) throw StateError('MISSING_COMMITTED_FIXTURE_ROW');
    await b.close();
    await a.close();
    outcome = 'BOTH_COMMITS_COMPLETE';
    await stage.delete(
      recursive: true,
    ); // This function's isolated fixture only.
  } on TimeoutException {
    // Never try to close/delete a blocked SQLite connection or the user's DB.
    // This disposable emulator package is stopped by the observer afterwards.
    outcome = 'BLOCKED_NATIVE_POOL_LOCK_ORDER';
  }
  final result = <String, dynamic>{
    'classification': 'CONTROLLED_NATIVE_SQFLITE_TWO_HANDLES_ONLY',
    'pool': parallel ? 4 : 1,
    'status': outcome,
    'events': events,
    'productionDatabaseOpened': false,
    'Google': 'NOT_RUN',
    'checkedAtMs': DateTime.now().millisecondsSinceEpoch,
  };
  await File(p.join(root.path, 'sqlite-concurrency18.json'))
      .writeAsString('${jsonEncode(result)}\n', flush: true);
  return result;
}
