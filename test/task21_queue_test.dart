import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';

import 'support/task15_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('21 control metadata overtakes waiting files, never preempts active file or alters its bytes/owner', () async {
    final f = await Fixture15.open(), gate = Completer<void>();
    final events = <String>[];
    final q = AlchemistWorkQueue(
      db: f.db,
      owner: () => 'owner',
      dispatch: () async {},
      send: (name, _, stop, _, _) async {
        expect(stop(), false);
        events.add('start:$name');
        if (name.endsWith(':file1')) await gate.future;
        events.add('end:$name');
      },
    );
    const one = 'alchemist_download:owner:file1',
        two = 'alchemist_download:owner:file2',
        meta = 'alchemist_download:owner:metadata';
    try {
      await q.enqueueDownload(one, {
        'kind': 'media',
        'checkpoint': {'offset': 8192, 'sha256': 'old-confirmed-sha'},
      });
      final run = q.runPending();
      for (var i = 0; i < 200 && !events.contains('start:$one'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(events, ['start:$one']);
      await q.enqueueDownload(two, {'kind': 'media'});
      await q.enqueueDownload(meta, {
        'kind': 'catalogSnapshot20',
        'scope': 'client:public',
      });
      await q.runPending();
      expect(events, ['start:$one']);
      gate.complete();
      await run;
      expect(events, [
        'start:$one',
        'end:$one',
        'start:$meta',
        'end:$meta',
        'start:$two',
        'end:$two',
      ]);
      final row = jsonDecode(
        (await f.db.query(
              'app_settings',
              where: 'name=?',
              whereArgs: [one],
            )).single['value']
            as String,
      );
      expect(row['ownerBinding'], 'owner');
      expect(row['download']['checkpoint']['offset'], 8192);
      final m = jsonDecode(
        (await f.db.query(
              'app_settings',
              where: 'name=?',
              whereArgs: [meta],
            )).single['value']
            as String,
      );
      expect(m['_work']['attempts'], 1);
      expect(m['_work']['stage'], 'catalog_checked');
    } finally {
      if (!gate.isCompleted) gate.complete();
      q.dispose();
      await f.close();
    }
  });
}
