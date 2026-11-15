import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';

import 'support/task15_fixture.dart';

void main() {
  test(
    '18 UI enqueue is persistent OS dispatch, never a second UI executor',
    () async {
      final f = await Fixture15.open();
      var sent = 0, scheduled = 0;
      final q = AlchemistWorkQueue(
        db: f.db,
        owner: () => 'original',
        dispatch: () async {
          scheduled++;
        },
        send: (_, _, _, _, _) async {
          sent++;
        },
      );
      try {
        await q.enqueueDownload('alchemist_download:one', {
          'kind': 'install',
          'card': {'immutableRevisionId': 'one'},
        });
        expect(scheduled, 1);
        expect(sent, 0);
        final before = Map<String, dynamic>.from(q.rows.single['_work']);
        q.dispose();
        final worker = AlchemistWorkQueue(
          db: f.db,
          owner: () => 'original',
          worker: true,
          send: (_, _, _, _, _) async {
            sent++;
          },
        );
        await worker.recoverNativeIntents();
        await worker.runPending();
        await worker.refresh();
        expect(sent, 1);
        expect(worker.rows.single['_work']['phase'], 'complete');
        expect(worker.rows.single['_work']['taskId'], before['taskId']);
        worker.dispose();
      } finally {
        await f.close();
      }
    },
  );

  test('18 legacy user pause/upload offsets are untouched; other owner cannot resume', () async {
    final f = await Fixture15.open();
    const name = 'alchemist_card:legacy';
    final old = {
      'ownerBinding': 'old',
      'pending': {'requestId': 'never-reset'},
      '_work': {
        'phase': 'paused',
        'code': 'USER_PAUSED',
        'bytes': 262144,
        'taskId': 'old-task',
      },
      'card': {'title': 'legacy'},
    };
    final serialized = jsonEncode(old);
    await f.db.insert('app_settings', {'name': name, 'value': serialized});
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'other',
      worker: true,
      send: (_, _, _, _, _) async => fail('foreign upload'),
    );
    try {
      await q.recoverNativeIntents();
      expect(q.rows, isEmpty);
      await expectLater(q.enqueue(name), throwsA(isA<AlchemistFailure>()));
      expect(
        (await f.db.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [name],
        )).single['value'],
        serialized,
      );
    } finally {
      q.dispose();
      await f.close();
    }
  });

  test('18 same-owner policy stop recovers; explicit native pause and cancel never auto-start', () async {
    final f = await Fixture15.open();
    var sent = 0;
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'same',
      dispatch: () async {},
      send: (_, _, _, _, _) async {},
    );
    await q.enqueueDownload('alchemist_download:policy', {'kind': 'media'});
    await q.pause('alchemist_download:policy', reason: 'WAITING_POLICY');
    await q.enqueueDownload('alchemist_download:user', {'kind': 'media'});
    await q.pause('alchemist_download:user');
    await q.enqueueDownload('alchemist_download:cancel', {'kind': 'media'});
    await q.pause('alchemist_download:cancel', cancel: true);
    q.dispose();
    final w = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'same',
      worker: true,
      send: (_, _, _, _, _) async {
        sent++;
      },
    );
    try {
      await w.recoverNativeIntents();
      await w.runPending();
      await w.refresh();
      expect(sent, 1);
      expect(
        w.rows.singleWhere(
          (r) => r['_name'] == 'alchemist_download:user',
        )['_work']['phase'],
        'paused',
      );
      expect(
        w.rows.singleWhere(
          (r) => r['_name'] == 'alchemist_download:cancel',
        )['_work']['phase'],
        'cancelled',
      );
    } finally {
      w.dispose();
      await f.close();
    }
  });

  test('18 duplicate taps remain one stable revision task and preserve request/receipt', () async {
    final f = await Fixture15.open();
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'same',
      dispatch: () async {},
      send: (_, _, _, _, _) async {},
    );
    try {
      for (var i = 0; i < 5; i++) {
        await q.enqueueDownload('alchemist_download:stable', {
          'kind': 'install',
          'card': {'immutableRevisionId': 'fixed'},
        });
      }
      expect(q.rows.length, 1);
      expect(q.rows.single['_work']['attempts'], 0);
      expect(q.rows.single['_work']['executor'], 'android18');
    } finally {
      q.dispose();
      await f.close();
    }
  });
}
