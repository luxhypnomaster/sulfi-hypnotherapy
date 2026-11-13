import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';

import 'support/task15_fixture.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  for (final phase in ['before', 'after']) {
    test('G3 real subprocess SIGKILL $phase commit, reopen, reconcile and retry', () async {
      final a = await Fixture15.open(), b = await Fixture15.open();
      Database? reopened;
      Process? child;
      var bClosed = false, killed = false, exited = false;
      int? workerPid;
      final output = StringBuffer();
      try {
        final module = await seed15(a);
        final zip = await a.c.capsules!.export(moduleId: module.id);
        await b.c.library.save((await b.c.library.prepareImport())!);
        await b.c.reload();
        final old = b.c.assets.single;
        await b.c.addAudio(old);
        final run = await b.c.repository.startRun(await b.c.snapshotForStart());
        await b.c.repository.checkpoint(
          run.checkpoint(status: RunStatus.interrupted),
        );
        final tables = [...CapsuleService.tables, 'app_settings', 'diary_sync'];
        final before = {for (final t in tables) t: await b.db.query(t)};
        final original = await b.c.library.fileFor(old).readAsBytes();
        await b.c.flush();
        b.c.dispose();
        await b.player.close();
        await b.db.close();
        bClosed = true;
        final marker = File('${b.root.path}/kill-$phase.json'),
            nonce = '${DateTime.now().microsecondsSinceEpoch}-$phase';
        final sdk = File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .parent
            .parent
            .parent;
        child = await Process.start('${sdk.path}/bin/flutter', [
          'test',
          '--no-pub',
          'tool/task15_crash_worker_test.dart',
          '--reporter',
          'expanded',
          '--dart-define=TASK15_CRASH_ROOT=${b.root.path}',
          '--dart-define=TASK15_CRASH_ZIP=${zip.path}',
          '--dart-define=TASK15_CRASH_MARKER=${marker.path}',
          '--dart-define=TASK15_CRASH_NONCE=$nonce',
          '--dart-define=TASK15_CRASH_PHASE=$phase',
        ], workingDirectory: Directory.current.path);
        child.stdout.transform(utf8.decoder).listen(output.write);
        child.stderr.transform(utf8.decoder).listen(output.write);
        child.exitCode.then((_) => exited = true);
        Map<String, dynamic>? checkpoint;
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline) && !exited) {
          if (await marker.exists()) {
            try {
              checkpoint = jsonDecode(await marker.readAsString());
              break;
            } catch (_) {}
          }
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        if (checkpoint == null) {
          throw StateError('Worker failed before checkpoint: $output');
        }
        expect(checkpoint['nonce'], nonce);
        expect(checkpoint['phase'], phase);
        workerPid = checkpoint['pid'];
        expect(workerPid, isNot(pid));
        expect(Process.killPid(workerPid!, ProcessSignal.sigkill), true);
        killed = true;
        expect(
          await child.exitCode.timeout(const Duration(seconds: 30)),
          isNot(0),
        );
        reopened = await openAppDatabase(
          '${b.root.path}/db',
          factory: databaseFactoryFfi,
        );
        final library = LibraryService(
          repository: SqliteLibraryRepository(reopened),
          directory: Directory('${b.root.path}/audio'),
          pick: () async => null,
          probe: (_) async => const Duration(seconds: 65),
        );
        await library.initialize();
        await CapsuleService.cleanWorkspace(
          Directory('${b.root.path}/capsules'),
        );
        for (final t in [
          'session_runs',
          'run_events',
          'current_draft',
          'app_settings',
          'diary_sync',
        ]) {
          expect(await reopened.query(t), before[t], reason: t);
        }
        if (phase == 'before') {
          for (final t in tables) {
            expect(await reopened.query(t), before[t], reason: t);
          }
          // Startup keeps uncommitted import bytes; metadata rollback still exact.
          expect(await library.directory.list().length, 4);
        } else {
          expect(await library.repository.list(), hasLength(4));
          expect(await reopened.query('module_definitions'), hasLength(1));
          expect(await library.directory.list().length, 4);
        }
        expect(await library.fileFor(old).readAsBytes(), original);
        final service = CapsuleService(
          database: reopened,
          library: library,
          diaryDirectory: Directory('${b.root.path}/diary'),
          workspace: Directory('${b.root.path}/capsules'),
        );
        final preview = await service.inspect(zip);
        expect(preview.alreadyImported, phase == 'after');
        await service.restore(preview);
        await preview.close();
        expect(await library.repository.list(), hasLength(4));
        // Before-commit abandoned bytes remain, plus the verified retry copies.
        expect(
          await library.directory.list().length,
          phase == 'before' ? 7 : 4,
        );
        for (final asset in await library.repository.list()) {
          expect(await library.fileFor(asset).exists(), true);
        }
      } finally {
        if (child != null && !exited) {
          if (workerPid != null && !killed) {
            Process.killPid(workerPid, ProcessSignal.sigkill);
          }
          child.kill(ProcessSignal.sigterm);
          try {
            await child.exitCode.timeout(const Duration(seconds: 10));
          } catch (_) {}
        }
        await reopened?.close();
        if (!bClosed) {
          await b.close();
        } else {
          await b.root.delete(recursive: true);
        }
        await a.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
