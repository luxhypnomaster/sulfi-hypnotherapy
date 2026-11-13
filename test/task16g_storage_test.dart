import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/storage_preflight.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late String path;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage16g-');
    path = '${root.path}/library.sqlite';
  });
  tearDown(() async => root.delete(recursive: true));

  Future<Map<String, String>> bytes() async => {
    for (final f in await root.list(recursive: true).toList())
      if (f is File) f.path: sha256.convert(await f.readAsBytes()).toString(),
  };
  Future<void> rejectsWithoutWrites() async {
    final before = await bytes();
    await expectLater(
      openAppDatabase(path, factory: databaseFactoryFfi),
      throwsA(anything),
    );
    expect(await bytes(), before);
  }

  test(
    'genuine fresh install succeeds, later missing DB with marker fails closed',
    () async {
      final db = await openAppDatabase(path, factory: databaseFactoryFfi);
      await db.close();
      await markStorageReady(path);
      await File(path).delete();
      await rejectsWithoutWrites();
      expect(await File(path).exists(), false);
    },
  );
  test('missing DB with inherited audio does not create empty library or clean media', () async {
    await Directory('${root.path}/audio').create();
    await File('${root.path}/audio/asset_kept.wav').writeAsBytes([4, 2, 1]);
    await rejectsWithoutWrites();
  });
  test(
    'missing DB with WAL/journal evidence never creates or removes files',
    () async {
      await File('$path-wal').writeAsBytes([1, 2, 3]);
      await File('$path-journal').writeAsBytes([4, 5, 6]);
      await rejectsWithoutWrites();
    },
  );
  test('corrupt header leaves original DB, sidecars and private media byte-identical', () async {
    final db = await openAppDatabase(path, factory: databaseFactoryFfi);
    await db.close();
    final f = await File(path).open(mode: FileMode.writeOnlyAppend);
    await f.setPosition(0);
    await f.writeFrom(utf8.encode('NOT_SQLITE_TEST!!'));
    await f.close();
    await Directory('${root.path}/diary_media').create();
    await File('${root.path}/diary_media/orphan.part').writeAsBytes([9, 8]);
    await File('$path-journal').writeAsBytes([0, 0, 0]);
    await rejectsWithoutWrites();
  });
  test('zero byte DB is not treated as first install', () async {
    await File(path).create();
    await rejectsWithoutWrites();
  });
  test(
    'valid SQLite with missing required table fails before RW bootstrap',
    () async {
      final db = await openAppDatabase(path, factory: databaseFactoryFfi);
      await db.execute('DROP TABLE module_definitions');
      await db.close();
      await rejectsWithoutWrites();
    },
  );
  test('invalid JSON graph is not silently filtered into empty UI', () async {
    final db = await openAppDatabase(path, factory: databaseFactoryFfi);
    await db.insert('module_definitions', {
      'id': 'kept-module',
      'payload': '{broken',
    });
    await db.close();
    await rejectsWithoutWrites();
  });
  test(
    'unknown version never creates new tables or rewrites old data',
    () async {
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.execute('CREATE TABLE legacy(id TEXT)');
      await db.execute("INSERT INTO legacy VALUES('kept')");
      await db.close();
      await rejectsWithoutWrites();
    },
  );
  test(
    'live WAL rows read from derivative; source SQLite/WAL/SHM bytes untouched',
    () async {
      final db = await openAppDatabase(path, factory: databaseFactoryFfi);
      await db.rawQuery('PRAGMA journal_mode=WAL');
      await db.rawQuery('PRAGMA wal_autocheckpoint=0');
      await db.insert('module_definitions', {
        'id': 'in-wal',
        'payload': '{"id":"in-wal"}',
      });
      final before = await bytes();
      await preflightStorage(path, databaseFactoryFfi);
      expect(await bytes(), before);
      expect((await db.query('module_definitions')).single['id'], 'in-wal');
      await db.close();
    },
  );
  test(
    'healthy reopen retains same-title distinct IDs, graph, drafts and schema9',
    () async {
      var db = await openAppDatabase(path, factory: databaseFactoryFfi);
      for (var i = 1; i <= 2; i++) {
        await db.insert('audio_assets', {
          'id': 'audio$i',
          'title': 'Одинаковое название',
          'filePath': 'asset_$i.wav',
          'durationMs': 12000,
          'format': 'wav',
          'createdAt': '2026-11-13',
          'category': 'preparation',
          'fileSizeBytes': 3,
        });
      }
      for (final table in [
        'module_definitions',
        'session_templates',
        'session_runs',
        'diary_author',
      ]) {
        final row = <String, Object?>{
          'id': 'kept-$table',
          'payload': '{"audio":["audio1","audio2"]}',
        };
        if (table == 'session_runs') {
          row.addAll({'displayNumber': 1, 'status': 'interrupted'});
        }
        if (table == 'diary_author') row['updatedAt'] = '2026-11-13';
        await db.insert(table, row);
      }
      await db.close();
      final before = await bytes();
      await preflightStorage(path, databaseFactoryFfi);
      expect(await bytes(), before);
      db = await openAppDatabase(path, factory: databaseFactoryFfi);
      expect((await db.query('audio_assets')).map((r) => r['id']), [
        'audio1',
        'audio2',
      ]);
      for (final table in [
        'module_definitions',
        'session_templates',
        'session_runs',
        'diary_author',
      ]) {
        expect(
          (await db.query(table)).single['payload'],
          '{"audio":["audio1","audio2"]}',
        );
      }
      expect(await db.getVersion(), 9);
      await db.close();
    },
  );

  test(
    'interrupted hot rollback journal fails closed without source writes',
    () async {
      final db = await openAppDatabase(path, factory: databaseFactoryFfi);
      await db.close();
      final crash = await Process.run('python3', [
        '-c',
        '''import sqlite3,os,sys
c=sqlite3.connect(sys.argv[1])
c.execute('PRAGMA cache_size=5')
c.execute('BEGIN IMMEDIATE')
for i in range(100):c.execute('INSERT INTO app_settings VALUES(?,?)',(str(i),'x'*10000))
os._exit(0)
''',
        path,
      ]);
      expect(crash.exitCode, 0);
      expect(await File('$path-journal').exists(), true);
      await rejectsWithoutWrites();
    },
  );
}
