import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';

import 'support/task15_fixture.dart';

import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/diary_read_state.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

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
  test(
    '18 denied OS start is durable WAITING_AUTH/POLICY, never ghost RUNNING',
    () async {
      final f = await Fixture15.open();
      final q = AlchemistWorkQueue(
        db: f.db,
        owner: () => 'same',
        dispatch: () async =>
            throw const AlchemistFailure('Нужен вход', 401, 'WAITING_AUTH'),
        send: (_, _, _, _, _) async => fail('UI must not send'),
      );
      try {
        await expectLater(
          q.enqueueDownload('alchemist_download:auth', {'kind': 'media'}),
          throwsA(isA<AlchemistFailure>()),
        );
        await q.refresh();
        expect(q.rows.single['_work']['phase'], 'waiting_auth');
        expect(q.rows.single['_work']['state'], 'WAITING_AUTH');
        expect(q.rows.single['_work']['attempts'], 0);
        expect(q.rows.single['download']['kind'], 'media');
      } finally {
        q.dispose();
        await f.close();
      }
    },
  );

  test('18 additive canonical states distinguish system restrictions from user pause', () {
    expect(
      alchemistCanonicalState({
        'phase': 'running',
        'stage': 'server_verifying',
      }),
      'VERIFYING',
    );
    expect(
      alchemistCanonicalState({'phase': 'running', 'stage': 'publishing'}),
      'COMMITTING',
    );
    expect(
      alchemistCanonicalState({'phase': 'paused', 'code': 'WAITING_POLICY'}),
      'WAITING_POLICY',
    );
    expect(
      alchemistCanonicalState({'phase': 'paused', 'code': 'USER_PAUSED'}),
      'PAUSED_BY_USER',
    );
    expect(alchemistCanonicalState({'phase': 'cancelled'}), 'CANCELED');
    expect(
      alchemistCanonicalState({'phase': 'retry_scheduled'}),
      'RETRY_SCHEDULED',
    );
    expect(
      alchemistCanonicalState({'phase': 'failed_permanent'}),
      'FAILED_PERMANENT',
    );
  });
  test('18 periodic reader sync never resumes a manually paused persistent snapshot', () async {
    final f = await Fixture15.open();
    var enqueues = 0, rpc = 0;
    final api = AlchemistDiaryApi(
      Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
      capsules: f.c.capsules!,
      media: DiaryMediaStore(
        Directory('${f.root.path}/media'),
        pick: (_) async => null,
        probe: (_) async => null,
      ),
      connection: (_, _, _, _) async {
        rpc++;
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {
              'subject': 'controlled-client',
              'role': 'CLIENT',
              'expiresAt':
                  DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            },
          }),
        );
      },
    );
    try {
      await api.authenticateReader('CONTROLLED_NOT_GOOGLE');
      final reads = DiaryReadStore(f.db, readerId: api.readerScope);
      await reads.load();
      final name = 'alchemist_read_sync_queue:${api.readerScope}';
      final raw = jsonEncode({
        'requestId': 'same-reader-request',
        'ifMatch': '0',
        'entries': [],
        'ownerBinding': api.author.ownerBinding,
        '_work': {
          'phase': 'paused',
          'code': 'USER_PAUSED',
          'pauseReason': 'USER_PAUSED',
          'taskId': 'unchanged',
        },
      });
      await f.db.insert('app_settings', {'name': name, 'value': raw});
      api.enqueueReaderSync = (_) async {
        enqueues++;
      };
      rpc = 0;
      await api.synchronizeReads(reads, []);
      expect(enqueues, 0);
      expect(rpc, 0);
      expect(
        (await f.db.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [name],
        )).single['value'],
        raw,
      );
    } finally {
      await f.close();
    }
  });

  test('18 transient server failure schedules a bounded retry, never an immediate busy loop', () async {
    final f = await Fixture15.open();
    var sent = 0;
    final ui = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'same',
      dispatch: () async {},
      send: (_, _, _, _, _) async {},
    );
    await ui.enqueueDownload('alchemist_download:retry', {'kind': 'media'});
    ui.dispose();
    var rpc = 0;
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
      delay: (_) async {},
      connection: (_, _, _, _) async {
        rpc++;
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': false,
            'status': 503,
            'error': {'code': 'BUSY'},
          }),
        );
      },
    );
    final worker = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'same',
      worker: true,
      send: (_, _, _, _, _) async {
        sent++;
        await api.call('catalog.list', {});
      },
    );
    try {
      await worker.recoverNativeIntents();
      await worker.runPending();
      await worker.refresh();
      expect(sent, 1);
      expect(rpc, 3);
      expect(worker.rows.single['_work']['networkRetries'], 2);
      expect(worker.rows.single['_work']['httpStatus'], 503);
      expect(worker.rows.single['_work']['phase'], 'retry_scheduled');
      expect(worker.rows.single['_work']['state'], 'RETRY_SCHEDULED');
      expect(
        worker.rows.single['_work']['retryAtMs'],
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
      await worker.recoverNativeIntents();
      await worker.runPending();
      expect(sent, 1);
    } finally {
      worker.dispose();
      await f.close();
    }
  });
}
