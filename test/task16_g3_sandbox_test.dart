import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/content_revision_store.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';

import '../tool/task16/g3_sandbox.dart';
import 'support/task15_fixture.dart';

Future<({AudioAsset a, AudioAsset b, List<int> bytesA, List<int> bytesB})> seed(
  Fixture15 f, {
  bool active = false,
}) async {
  await f.c.library.save((await f.c.library.prepareImport())!);
  await f.c.reload();
  final a = f.c.assets.single;
  await f.c.addAudio(a);
  final run = await f.c.repository.startRun(await f.c.snapshotForStart());
  if (!active) {
    await f.c.repository.checkpoint(
      run.checkpoint(status: RunStatus.interrupted),
    );
  }
  final bytesA = await f.c.library.fileFor(a).readAsBytes(),
      bytesB = [...bytesA, 0, 0, 0, 9, 102, 114, 101, 101, 88];
  final b = AudioAsset.fromMap({
    ...a.toMap(),
    'filePath': 'asset_g3_second.m4a',
    'contentHash': sha256.convert(bytesB).toString(),
    'fileSizeBytes': bytesB.length,
    'baseRevision': 2,
  });
  await File('${f.c.library.directory.path}/${b.filePath}')
      .writeAsBytes(bytesB);
  await ContentRevisionStore(f.db)
      .put(ContentRevisionStore.revisionForRow('audio_assets', b.toMap())!);
  return (a: a, b: b, bytesA: bytesA, bytesB: bytesB);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('G3 read-only inventory binds old history exactly and does not write source', () async {
    final f = await Fixture15.open();
    try {
      final s = await seed(f),
          before = await f.db.query('session_runs'),
          assets = await f.db.query('audio_assets');
      final plan = await G3Research.inventory(f.db, f.c.library.directory);
      expect(plan.blockers, isEmpty);
      // ignore: avoid_print
      print('G3_DRY_RUN=${jsonEncode(plan.summary)}');
      expect(
        plan.revisions.values.where((r) => r.key.content.id == s.a.id),
        hasLength(2),
      );
      expect(
        plan.refs.where((r) => r['ownerType'] == 'session_runs'),
        isNotEmpty,
      );
      expect(
        plan.refs
            .where((r) => r['ownerType'] == 'session_runs')
            .every((r) => r['blobSha'] == s.a.contentHash),
        true,
      );
      expect(await f.db.query('session_runs'), before);
      expect(await f.db.query('audio_assets'), assets);
      expect(await f.c.library.fileFor(s.a).readAsBytes(), s.bytesA);
    } finally {
      await f.close();
    }
  });
  test('G3 sandbox coexists A/B exact bytes; head B never changes history A; immutable rows reject changes; rollback clone', () async {
    final f = await Fixture15.open();
    G3Sandbox? box;
    try {
      final s = await seed(f), history = await f.db.query('session_runs');
      final plan = await G3Research.inventory(f.db, f.c.library.directory);
      box = await G3Research.applyToNewSandbox(
        f.db,
        f.c.library.directory,
        plan,
      );
      final a = plan.heads[s.a.id]!,
          b = plan.revisions.values.singleWhere(
            (r) => r.payload['contentHash'] == s.b.contentHash,
          );
      await box.setExperimentalHead(s.a.id, b.key.revision);
      expect(
        await box.exact(s.a.id, a.key.revision, s.a.contentHash!),
        s.bytesA,
      );
      expect(
        await box.exact(s.a.id, b.key.revision, s.b.contentHash!),
        s.bytesB,
      );
      expect(
        (await box.db.query(
          'g3_refs',
          where: 'ownerType=?',
          whereArgs: ['session_runs'],
        )).every((r) => r['revisionId'] == a.key.revision),
        true,
      );
      expect(await box.db.query('session_runs'), history);
      expect(await f.db.query('session_runs'), history);
      expect(f.c.asset(s.a.id)!.contentHash, s.a.contentHash);
      await expectLater(
        box.exact(s.a.id, 'missing', s.a.contentHash!),
        throwsStateError,
      );
      await expectLater(
        box.exact(s.a.id, b.key.revision, s.a.contentHash!),
        throwsStateError,
      );
      await expectLater(
        box.db.update('g3_revisions', {'blobSha': 'wrong'}),
        throwsA(predicate((e) => e.toString().contains('IMMUTABLE_REVISION'))),
      );
      expect(
        (await box.db.rawQuery('pragma integrity_check')).single.values.single,
        'ok',
      );
      final restored = await box.rollbackClone();
      try {
        expect(await restored.query('session_runs'), history);
        expect(
          (await restored.rawQuery('pragma integrity_check'))
              .single
              .values
              .single,
          'ok',
        );
        expect(
          await restored.rawQuery(
            "select name from sqlite_master where name like 'g3_%'",
          ),
          isEmpty,
        );
      } finally {
        await restored.close();
      }
      expect(
        await box.exact(s.a.id, b.key.revision, s.b.contentHash!),
        s.bytesB,
        reason: 'rollback preserves experimental evidence instead of deleting files',
      );
    } finally {
      await box?.close();
      await f.close();
    }
  });
  test(
    'G3 stale inventory, changed bytes and active session fail closed',
    () async {
      for (final mutation in ['rows', 'bytes', 'active']) {
        final f = await Fixture15.open();
        try {
          final s = await seed(f, active: mutation == 'active'),
              plan = await G3Research.inventory(f.db, f.c.library.directory);
          if (mutation == 'rows') {
            await f.db.update('audio_assets', {'title': 'changed'});
          }
          if (mutation == 'bytes') {
            await f.c.library.fileFor(s.a).writeAsBytes([1, 2, 3]);
          }
          await expectLater(
            G3Research.applyToNewSandbox(f.db, f.c.library.directory, plan),
            throwsStateError,
          );
          expect(
            await f.db.rawQuery(
              "select name from sqlite_master where name like 'g3_%'",
            ),
            isEmpty,
          );
        } finally {
          await f.close();
        }
      }
    },
  );
  test('G3 ambiguous history without frozen bytes is never silently mapped to current head', () async {
    final f = await Fixture15.open();
    try {
      await seed(f);
      for (final row in await f.db.query('session_runs')) {
        dynamic strip(dynamic v) => v is Map
            ? {
                for (final e in v.entries)
                  if (e.key != 'audioAssets' && e.key != 'audioMetadata')
                    e.key: strip(e.value),
              }
            : v is List
            ? v.map(strip).toList()
            : v;
        await f.db.update(
          'session_runs',
          {'payload': jsonEncode(strip(jsonDecode(row['payload'] as String)))},
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }
      final plan = await G3Research.inventory(f.db, f.c.library.directory);
      expect(plan.blockers, contains('AMBIGUOUS_OR_MISSING_LEGACY_REFERENCE'));
      await expectLater(
        G3Research.applyToNewSandbox(f.db, f.c.library.directory, plan),
        throwsStateError,
      );
    } finally {
      await f.close();
    }
  });
  test('G3 same bytes with ambiguous metadata refuses to invent historical revision', () async {
    final f = await Fixture15.open();
    try {
      final s = await seed(f);
      final edited = AudioAsset.fromMap({
        ...s.a.toMap(),
        'title': 'Later metadata only',
      });
      await ContentRevisionStore(f.db).put(
        ContentRevisionStore.revisionForRow('audio_assets', edited.toMap())!,
      );
      final plan = await G3Research.inventory(f.db, f.c.library.directory);
      expect(plan.blockers, contains('AMBIGUOUS_HISTORY_REVISION'));
      await expectLater(
        G3Research.applyToNewSandbox(f.db, f.c.library.directory, plan),
        throwsStateError,
      );
    } finally {
      await f.close();
    }
  });
  test(
    'G3 copied blob tampering fails without falling back to the head or source',
    () async {
      final f = await Fixture15.open();
      G3Sandbox? box;
      try {
        final s = await seed(f);
        final plan = await G3Research.inventory(f.db, f.c.library.directory);
        box = await G3Research.applyToNewSandbox(
          f.db,
          f.c.library.directory,
          plan,
        );
        await File('${box.root.path}/blob-${s.a.contentHash}.bin')
            .writeAsBytes([1]);
        await expectLater(
          box.exact(s.a.id, plan.heads[s.a.id]!.key.revision, s.a.contentHash!),
          throwsStateError,
        );
        expect(await f.c.library.fileFor(s.a).readAsBytes(), s.bytesA);
      } finally {
        await box?.close();
        await f.close();
      }
    },
  );
  test('G3 injected pre-commit failure preserves source history and both original files', () async {
    final f = await Fixture15.open();
    try {
      final s = await seed(f),
          before = await f.db.query('session_runs'),
          plan = await G3Research.inventory(f.db, f.c.library.directory);
      await expectLater(
        G3Research.applyToNewSandbox(
          f.db,
          f.c.library.directory,
          plan,
          beforeCommit: () async => throw StateError('INJECTED_CRASH'),
        ),
        throwsStateError,
      );
      expect(await f.db.query('session_runs'), before);
      expect(await f.c.library.fileFor(s.a).readAsBytes(), s.bytesA);
      expect(await f.c.library.fileFor(s.b).readAsBytes(), s.bytesB);
    } finally {
      await f.close();
    }
  });
}
