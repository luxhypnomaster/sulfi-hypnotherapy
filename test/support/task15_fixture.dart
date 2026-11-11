import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';

import 'fakes.dart';

class Fixture15 {
  Fixture15._(this.root, this.db, this.c, this.player);
  final Directory root;
  final Database db;
  final SessionController c;
  final MemoryPlayer player;
  static Future<Fixture15> open({
    bool client = false,
    Future<Duration?> Function(String)? probe,
  }) async {
    sqfliteFfiInit();
    final root = await Directory.systemTemp.createTemp('task15-ui');
    final db = await openAppDatabase(
      '${root.path}/db',
      factory: databaseFactoryFfi,
    );
    final policy = AccessPolicy(database: db, clientEdition: client);
    await policy.load();
    final library = LibraryService(
      repository: SqliteLibraryRepository(db),
      directory: Directory('${root.path}/audio'),
      pick: () async =>
          (name: 'sample.m4a', path: 'test/fixtures/android_aac_isom.m4a'),
      probe: probe ?? (_) async => const Duration(seconds: 65),
      policy: policy,
    );
    await library.initialize();
    final c = SessionController(
      repository: SqliteSessionRepository(db, policy),
      library: library,
      modules: ModuleCatalog(db, policy),
      capsules: CapsuleService(
        database: db,
        library: library,
        diaryDirectory: Directory('${root.path}/diary'),
        workspace: Directory('${root.path}/capsules'),
      ),
    );
    await c.initialize();
    return Fixture15._(root, db, c, MemoryPlayer());
  }

  Future<void> close() async {
    await c.flush();
    c.dispose();
    await player.close();
    await db.close();
    await root.delete(recursive: true);
  }
}
