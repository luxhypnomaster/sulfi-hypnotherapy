import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diagnostics.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

import 'support/task15_fixture.dart';

Future<void> settle17(AlchemistWorkQueue q, String phase) async {
  for (var i = 0; i < 150; i++) {
    await q.refresh();
    if (q.rows.isNotEmpty && q.rows.single['_work']['phase'] == phase) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Phase not reached: $phase');
}

Future<void> seedQueue17(Fixture15 f, String name) => f.db
    .insert('app_settings', {
      'name': name,
      'value': jsonEncode({
        'ownerBinding': 'verified-owner',
        'card': {'title': 'Controlled'},
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace)
    .then((_) {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('17 G2 five taps and restart reuse one owner/revision; changed revision is distinct', () async {
    final f = await Fixture15.open();
    var sent = 0;
    const name = 'alchemist_card:controlled17';
    final gate = Completer<void>();
    var disposed = false;
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'verified-owner',
      send: (_, _, _, _, _) async {
        sent++;
        if (sent == 1) await gate.future;
      },
    );
    try {
      await seedQueue17(f, name);
      await Future.wait(List.generate(5, (_) => q.enqueue(name)));
      await settle17(q, 'running');
      for (var i = 0; i < 150 && sent == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sent, 1);
      final task = q.rows.single['_work']['taskId'];
      gate.complete();
      await settle17(q, 'complete');
      final again = await q.enqueue(name);
      expect(again.existing, true);
      expect(sent, 1);
      q.dispose();
      disposed = true;
      final restarted = AlchemistWorkQueue(
        db: f.db,
        owner: () => 'verified-owner',
        send: (_, _, _, _, _) async {
          sent++;
        },
      );
      await restarted.recover();
      expect((await restarted.enqueue(name)).phase, 'complete');
      expect(sent, 1);
      final row = Map<String, dynamic>.from(
        jsonDecode(
          (await f.db.query(
                'app_settings',
                where: 'name=?',
                whereArgs: [name],
              )).single['value']
              as String,
        ),
      );
      row['card'] = {'title': 'Changed revision'};
      await f.db.update(
        'app_settings',
        {'value': jsonEncode(row)},
        where: 'name=?',
        whereArgs: [name],
      );
      await restarted.enqueue(name);
      await settle17(restarted, 'complete');
      expect(sent, 2);
      expect(restarted.rows.single['_work']['taskId'], isNot(task));
      restarted.dispose();
    } finally {
      if (!disposed) q.dispose();
      if (!gate.isCompleted) gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await f.close();
    }
  });
  test('17 G2 resume during cooperative pause is deferred, never silently dropped; recover does not fake process death', () async {
    final f = await Fixture15.open();
    var sent = 0;
    const name = 'alchemist_card:controlled17';
    final gate = Completer<void>();
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'verified-owner',
      send: (_, _, stop, _, _) async {
        sent++;
        if (sent == 1) {
          await gate.future;
          if (stop()) throw const SocketException('CONTROLLED_STOP');
        }
      },
    );
    try {
      await seedQueue17(f, name);
      await q.enqueue(name);
      await settle17(q, 'running');
      await q.pauseAll();
      await q.recover();
      expect(q.rows.single['_work']['phase'], 'pausing');
      final resume = await q.enqueue(name);
      expect(resume.reason, 'RESUME_AFTER_CURRENT_REQUEST');
      gate.complete();
      await settle17(q, 'complete');
      expect(sent, 2);
      expect(q.rows.single['_work']['attempts'], 2);
    } finally {
      q.dispose();
      if (!gate.isCompleted) gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await f.close();
    }
  });
  test('17 G2 auth/network/permission preflight distinct with zero send attempts; same owner resumes, other owner denied', () async {
    for (final entry in <Object, String>{
      const AlchemistFailure(
        'Controlled auth',
        401,
        'IDENTITY_REQUIRED',
        DiaryFailure.authorization,
      ): 'waiting_auth',
      const AlchemistFailure(
        'Controlled permission',
        403,
        'OWNER_REQUIRED',
        DiaryFailure.blocked,
      ): 'waiting_permission',
      const SocketException('CONTROLLED_OFFLINE'): 'waiting_network',
    }.entries) {
      final f = await Fixture15.open();
      var sent = 0;
      var blocked = true;
      var owner = 'verified-owner';
      const name = 'alchemist_card:controlled17';
      final q = AlchemistWorkQueue(
        db: f.db,
        owner: () => owner,
        prepare: () async {
          if (blocked) throw entry.key;
        },
        send: (_, _, _, _, _) async {
          sent++;
        },
      );
      try {
        await seedQueue17(f, name);
        await q.enqueue(name);
        await settle17(q, entry.value);
        expect(sent, 0);
        expect(q.rows.single['_work']['attempts'], 0);
        owner = 'other-owner';
        await expectLater(q.enqueue(name), throwsA(isA<AlchemistFailure>()));
        owner = 'verified-owner';
        blocked = false;
        await q.enqueue(name);
        await settle17(q, 'complete');
        expect(sent, 1);
      } finally {
        q.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await f.close();
      }
    }
  });
  test('17 G2 production retry measurements remain accurate without opt-in trace collection', () async {
    final f = await Fixture15.open();
    var calls = 0;
    const name = 'alchemist_card:controlled17';
    AlchemistDiagnostics.instance.enable(false);
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'verified-owner',
      send: (_, _, _, _, _) async {
        final api = AlchemistApi(
          Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
          delay: (_) async {},
          connection: (_, _, _, _) async {
            calls++;
            if (calls < 3) throw const SocketException('CONTROLLED_OFFLINE');
            return DiaryResponse(
              200,
              jsonEncode({'ok': true, 'status': 200, 'result': {}}),
            );
          },
        );
        await api.call('catalog.list', {});
      },
    );
    try {
      await seedQueue17(f, name);
      await q.enqueue(name);
      await settle17(q, 'complete');
      expect(calls, 3);
      expect(q.rows.single['_work']['networkRetries'], 2);
      expect(AlchemistDiagnostics.instance.events, isEmpty);
    } finally {
      q.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await f.close();
    }
  });
}
