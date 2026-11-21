import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/catalog_snapshot_sync.dart';

import 'support/task15_fixture.dart';

class Transport20 implements CatalogSnapshotTransport {
  int heads = 0, snapshots = 0, revision = 1;
  bool corrupt = false, offline = false;
  Completer<void>? gate;
  Map<String, dynamic> body(String scope) => {
    'schemaVersion': 1,
    'scope': scope,
    'catalogRevision': revision,
    'createdAt': '2026-11-21T00:00:00.000Z',
    'items': <dynamic>[],
  };
  @override
  Future<Map<String, dynamic>> head(String scope) async {
    heads++;
    await gate?.future;
    if (offline) throw TimeoutException('controlled offline');
    final s = body(scope), hash = contentDigest(s);
    return {
      'schemaVersion': 1,
      'scope': scope,
      'catalogRevision': revision,
      'snapshotId': 'sha256-$hash',
      'snapshotHash': hash,
      'createdAt': s['createdAt'],
    };
  }

  @override
  Future<Map<String, dynamic>> snapshot(String scope, String id) async {
    snapshots++;
    return {...body(scope), if (corrupt) 'scope': 'wrong'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('20 SQLite: six refreshes one existing durable queue task; equal HEAD zero snapshot; cold read', () async {
    final f = await Fixture15.open(),
        t = Transport20()..gate = Completer<void>();
    String? account = 'verified-A';
    final sync = CatalogSnapshotSync(
      db: f.db,
      transport: t,
      owner: () => account,
    );
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => account,
      send: (_, v, stop, _, _) => sync.execute(v, stop),
    );
    var changed = 0;
    sync.addListener(() => changed++);
    try {
      final names = await Future.wait(
        List.generate(6, (_) => sync.request('client:public', q)),
      );
      expect(names.toSet().length, 1);
      expect(
        (await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_download:%'],
        )).length,
        1,
      );
      t.gate!.complete();
      t.gate = null;
      for (var i = 0; i < 200 && changed == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await q.runPending();
      expect(t.heads, 1);
      expect(t.snapshots, 1);
      expect(changed, 1);
      final cold = CatalogSnapshotSync(
        db: f.db,
        transport: t,
        owner: () => account,
      );
      expect(
        (await cold.lastGood('client:public'))!['head']['catalogRevision'],
        1,
      );
      await cold.execute({
        'ownerBinding': account,
        'download': {'scope': 'client:public'},
      }, () => false);
      expect(t.snapshots, 1);
      expect(changed, 1);
      account = 'verified-B';
      expect(await cold.lastGood('client:public'), null);
      account = 'verified-A';
      expect(await cold.lastGood('master:public'), null);
      expect(
        (await cold.lastGood('client:public'))!['head']['catalogRevision'],
        1,
      );
    } finally {
      q.dispose();
      sync.dispose();
      await f.close();
    }
  });
  test('20 lastGood survives offline, bad hash, older HEAD and account swap; prepared/current atomic', () async {
    final f = await Fixture15.open(), t = Transport20();
    String? account = 'A';
    final s = CatalogSnapshotSync(db: f.db, transport: t, owner: () => account);
    final row = <String, dynamic>{
      'ownerBinding': 'A',
      'download': {'scope': 'client:public'},
    };
    try {
      await s.execute(row, () => false);
      final old = await s.lastGood('client:public');
      t.offline = true;
      await expectLater(
        s.execute(row, () => false),
        throwsA(isA<TimeoutException>()),
      );
      t.offline = false;
      t.revision = 2;
      t.corrupt = true;
      await expectLater(s.execute(row, () => false), throwsFormatException);
      expect(await s.lastGood('client:public'), old);
      t.corrupt = false;
      await s.execute(row, () => false);
      t.revision = 1;
      await s.execute(row, () => false);
      expect(
        (await s.lastGood('client:public'))!['head']['catalogRevision'],
        2,
      );
      t.gate = Completer<void>();
      final attempt = s.execute(row, () => false);
      account = 'B';
      t.gate!.complete();
      await expectLater(attempt, throwsFormatException);
      expect(await s.lastGood('client:public'), null);
      final rows = await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['catalog20:%:prepared:%'],
      );
      expect(rows.length, 2);
      expect(await f.db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      final current = await f.db.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['catalog20:%:current'],
      );
      expect(
        jsonDecode(
          current.single['value'] as String,
        )['head']['catalogRevision'],
        2,
      );
    } finally {
      s.dispose();
      await f.close();
    }
  });
  test('20 snapshot rejects schema, scope, cycle and missing exact dependency even when hashed', () {
    for (final mode in ['schema', 'scope', 'missing', 'cycle']) {
      final items = <dynamic>[];
      if (mode == 'missing' || mode == 'cycle')
        items.add({
          'contentId': 'm',
          'revisionId': '1',
          'sha256': 'a' * 64,
          'dependencies': [
            {
              'contentId': mode == 'cycle' ? 'm' : 'absent',
              'revisionId': '1',
              'sha256': 'a' * 64,
            },
          ],
        });
      final body = {
        'schemaVersion': mode == 'schema' ? 2 : 1,
        'scope': mode == 'scope' ? 'other' : 'client:public',
        'catalogRevision': 1,
        'items': items,
      };
      final hash = contentDigest(body),
          h = {
            'schemaVersion': 1,
            'scope': 'client:public',
            'catalogRevision': 1,
            'snapshotId': 'sha256-$hash',
            'snapshotHash': hash,
          };
      expect(
        () => CatalogSnapshotSync.verify(h, body, 'client:public'),
        throwsFormatException,
      );
    }
  });
}
