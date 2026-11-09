// Explicit subprocess fixture, outside test/ so normal discovery never runs it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';

void main() {
  test('controlled importer crash worker', () async {
    const root = String.fromEnvironment('TASK15_CRASH_ROOT'),
        zip = String.fromEnvironment('TASK15_CRASH_ZIP'),
        marker = String.fromEnvironment('TASK15_CRASH_MARKER'),
        nonce = String.fromEnvironment('TASK15_CRASH_NONCE'),
        phase = String.fromEnvironment('TASK15_CRASH_PHASE');
    if (!p.basename(root).startsWith('task15-ui') ||
        nonce.isEmpty ||
        !{'before', 'after'}.contains(phase) ||
        !await File('$root/db').exists()) {
      throw StateError(
        'Only explicitly provisioned temporary task15 fixture is allowed',
      );
    }
    sqfliteFfiInit();
    final db = await openAppDatabase('$root/db', factory: databaseFactoryFfi);
    final library = LibraryService(
      repository: SqliteLibraryRepository(db),
      directory: Directory('$root/audio'),
      pick: () async => null,
      probe: (_) async => const Duration(seconds: 65),
    );
    await library.initialize();
    final service = CapsuleService(
      database: db,
      library: library,
      diaryDirectory: Directory('$root/diary'),
      workspace: Directory('$root/capsules'),
    );
    final preview = await service.inspect(File(zip));
    Future<void> checkpoint() async {
      await File(marker).writeAsString(
        jsonEncode({'pid': pid, 'nonce': nonce, 'phase': phase}),
        flush: true,
      );
      await Completer<void>().future; // Parent kills this real OS process.
    }

    await service.restore(
      preview,
      beforeCommit: phase == 'before' ? checkpoint : null,
    );
    await checkpoint();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
