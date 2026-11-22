import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_work_queue.dart';

import 'support/task21_server.dart';
import 'task22_runtime_test.dart' show script22;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('22 real metadata HTTP overtakes pending15MiB at dispatch boundary; active task/file checkpoint preserved', () async {
    final s = await Server21.open(script: script22);
    addTearDown(s.close);
    final app = await App21.open(s, projectEnabled: true),
        gate = Completer<void>();
    final file = File('${app.f.root.path}/synthetic15MiB.bin');
    await file.writeAsBytes(List<int>.filled(15 * 1024 * 1024, 17));
    final hash = (await sha256.bind(file.openRead()).first).toString(),
        events = <String>[];
    final queue = AlchemistWorkQueue(
      db: app.f.db,
      owner: () => app.c.transferOwner,
      dispatch: () async {},
      send: (name, row, stop, stage, progress) async {
        final kind = row['download']['kind'];
        events.add('start:$kind');
        if (kind == 'active15MiB') {
          await gate.future;
        }
        if (kind == 'projectMetadata22') {
          await app.c.project22!.execute(row, stop);
        }
        events.add('end:$kind');
      },
    );
    try {
      await queue.enqueueDownload(
        'alchemist_download:${app.c.transferOwner}:1',
        {
          'kind': 'active15MiB',
          'byteLength': await file.length(),
          'offset': 8192,
        },
      );
      final running = queue.runPending();
      for (var i = 0; i < 300 && !events.contains('start:active15MiB'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await queue.enqueueDownload(
        'alchemist_download:${app.c.transferOwner}:2',
        {'kind': 'waiting15MiB', 'byteLength': await file.length()},
      );
      await app.c.project22!.refresh(queue);
      expect(events, ['start:active15MiB']);
      gate.complete();
      await running;
      expect(events, [
        'start:active15MiB',
        'end:active15MiB',
        'start:projectMetadata22',
        'end:projectMetadata22',
        'start:waiting15MiB',
        'end:waiting15MiB',
      ]);
      expect((await sha256.bind(file.openRead()).first).toString(), hash);
      expect(
        (await s.call('control.state', {}))['counts']['project.overview'],
        1,
      );
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
      queue.dispose();
      await app.close();
    }
  });
}
