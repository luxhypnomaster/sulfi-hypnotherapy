import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

import 'support/task15_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('17 G0 lifecycle before dispatch: zero attempts is not a user pause; same owner resume dispatches', () async {
    final f = await Fixture15.open();
    var sent = 0, interruptOnce = true;
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'server-verified-stable-owner',
      send: (_, _, stop, _, _) async {
        sent++;
      },
    );
    const name = 'alchemist_card:17controlled';
    try {
      await f.db.insert('app_settings', {
        'name': name,
        'value': jsonEncode({
          'ownerBinding': 'server-verified-stable-owner',
          'card': {'title': 'Controlled'},
        }),
      });
      q.addListener(() {
        if (interruptOnce &&
            q.rows.any((r) => r['_work']?['phase'] == 'queued')) {
          interruptOnce = false;
          unawaited(q.pauseAll());
        }
      });
      await q.enqueue(name);
      for (var i = 0; i < 80; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await q.refresh();
        if (q.rows.single['_work']['phase'] == 'paused') break;
      }
      final work = q.rows.single['_work'] as Map;
      expect(sent, 0);
      expect(work['attempts'] ?? 0, 0);
      expect(work['code'], 'LIFECYCLE_PAUSED');
      await q.enqueue(name);
      for (var i = 0; i < 80 && sent == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sent, 1);
    } finally {
      q.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await f.close();
    }
  });
  test('17 G0 cold same-owner restore changes scope before protected HTTP, not account switch', () async {
    var scope = 'public', calls = 0;
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
      identityScope: () => scope,
      identityEpoch: () => 0,
      credential: () async {
        scope = 'account:server-verified-same-owner';
        return 'CONTROLLED_NO_REAL_TOKEN';
      },
      connection: (_, _, _, _) async {
        calls++;
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {'accepted': true},
          }),
        );
      },
    );
    expect((await api.call('catalog.list', {}))['accepted'], true);
    expect(calls, 1);
  });
}
