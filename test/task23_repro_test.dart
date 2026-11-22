// Disposable synthetic domain tests, not owner-device forensics/native upgrade.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

Future<Map<String, dynamic>> manifest23(File file) async =>
    Map<String, dynamic>.from(
      jsonDecode(
        utf8.decode(
          ZipDecoder()
              .decodeBytes(await file.readAsBytes())
              .findFile('manifest.json')!
              .content,
        ),
      ),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('23 RED→GREEN headless allowMigrations=false must never create missing local DB', () async {
    final root = await Directory.systemTemp.createTemp('t23-no-create-'),
        path = '${root.path}/library.sqlite';
    try {
      await expectLater(
        openAppDatabase(
          path,
          factory: databaseFactoryFfi,
          allowMigrations: false,
        ),
        throwsA(anything),
      );
      expect(
        await File(path).exists(),
        false,
        reason: 'A background bootstrap refusal cannot leave a new empty DB',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('23 RED→GREEN startup never deletes name-only unknown-owner capsules or staging bytes', () async {
    final f = await Fixture15.open();
    try {
      await seed15(f);
      final zip = await f.c.capsules!.export(moduleId: 'portable-module'),
          root = f.c.capsules!.workspace;
      final unknown = Directory('${root.path}/export-user-owned');
      await unknown.create();
      final kept = await zip.copy('${unknown.path}/personal.zip'),
          before = await kept.readAsBytes();
      final loose = await File('${root.path}/sulfi-user-backup.zip')
          .writeAsBytes(before);
      await CapsuleService.cleanWorkspace(root);
      expect(await kept.exists(), true);
      expect(await kept.readAsBytes(), before);
      expect(await loose.readAsBytes(), before);
    } finally {
      await f.close();
    }
  });
  test('23 RED→GREEN validated capsule preview mutation is refused before any destination write', () async {
    final a = await Fixture15.open(), b = await Fixture15.open();
    CapsulePreview? p;
    try {
      await seed15(a);
      final zip = await a.c.capsules!.export(moduleId: 'portable-module');
      p = await b.c.capsules!.inspect(zip);
      final row = p.records['module_definitions'][0],
          m = jsonDecode(row['payload']);
      m['title'] = 'TAMPERED AFTER INSPECT';
      row['payload'] = jsonEncode(m);
      await expectLater(b.c.capsules!.restore(p), throwsFormatException);
      expect(await b.db.query('module_definitions'), isEmpty);
      expect(await b.db.query('audio_assets'), isEmpty);
      expect(await b.c.library.directory.list().toList(), isEmpty);
    } finally {
      await p?.close();
      await a.close();
      await b.close();
    }
  });
  test('23 RED→GREEN a MASTER role alone cannot export another account private draft without owner scope proof', () async {
    final f = await Fixture15.open();
    try {
      f.c.policy.applyVerifiedServerRole('MASTER');
      final author = DiaryAuthorRepository(f.db), now = DateTime.utc(2026);
      for (final id in ['account-A', 'account-B', 'local']) {
        await author.save(
          DiaryEntry(
            id: id,
            message: 'Synthetic private text',
            createdAt: now,
            updatedAt: now,
            extra: {'_alchemistScope': id == 'local' ? 'local-device' : id},
          ),
        );
      }
      final rows = await f.db.query('diary_author');
      final zip = await f.c.capsules!.export(), m = await manifest23(zip);
      expect((m['records']['diary_author'] as List).map((r) => r['id']), [
        'local',
      ]);
      expect(await f.db.query('diary_author'), rows);
    } finally {
      await f.close();
    }
  });
}
