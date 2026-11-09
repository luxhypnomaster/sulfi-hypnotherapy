import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/content_revision_store.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';

import 'support/task15_fixture.dart';

void main() {
  test('G3 retained revision bytes survive startup; same-ID byte replacement still blocked pending complete readers', () async {
    final f = await Fixture15.open();
    try {
      await f.c.library.save((await f.c.library.prepareImport())!);
      await f.c.reload();
      final a = f.c.assets.single;
      await f.c.addAudio(a);
      final run = await f.c.repository.startRun(await f.c.snapshotForStart());
      await f.c.repository.checkpoint(
        run.checkpoint(status: RunStatus.interrupted),
      );
      final history = (await f.c.repository.history()).single.toMap();
      final original = await f.c.library.fileFor(a).readAsBytes();
      final bytes = [...original, 0, 0, 0, 9, 102, 114, 101, 101, 77];
      final file = File(
        '${f.c.library.directory.path}/asset_retained_revision.m4a',
      );
      await file.writeAsBytes(bytes);
      final b = AudioAsset.fromMap({
        ...a.toMap(),
        'filePath': 'asset_retained_revision.m4a',
        'contentHash': sha256.convert(bytes).toString(),
        'fileSizeBytes': bytes.length,
        'baseRevision': 2,
      });
      await expectLater(f.c.library.save(b), throwsStateError);
      final revision = ContentRevisionStore.revisionForRow(
        'audio_assets',
        b.toMap(),
      )!;
      await ContentRevisionStore(f.db).put(revision);
      await f.c.library.initialize();
      expect(
        await file.exists(),
        true,
        reason: 'retained revision references bytes B even though current row is still A',
      );
      expect(await file.readAsBytes(), bytes);
      await f.c.reload();
      expect(
        f.c.asset(a.id)!.contentHash,
        a.contentHash,
        reason: 'BLOCKER: current runtime still only resolves A; no false claim that B is playable',
      );
      expect((await f.c.repository.history()).single.toMap(), history);
      expect(await f.c.library.fileFor(a).readAsBytes(), original);
    } finally {
      await f.close();
    }
  });
  test('G3 missing content bytes excludes metadata-only edits; physical copies and staging are separate', () async {
    final a = await Fixture15.open(), b = await Fixture15.open();
    try {
      await a.c.library.save((await a.c.library.prepareImport())!);
      await a.c.reload();
      final asset = a.c.assets.single;
      final first = await a.c.capsules!.export(trackId: asset.id);
      final preview = await b.c.capsules!.inspect(first);
      await b.c.capsules!.restore(preview);
      await preview.close();
      await a.c.library.save(asset.edited('Только метаданные', asset.category));
      final zip = await a.c.capsules!.export(trackId: asset.id);
      final local = await LocalCatalogSource.open(b.c.capsules!, zip);
      final plan = await local.plan(local.revisions.single.key);
      expect(plan.newBytes, 0);
      expect(plan.missingDigests, isEmpty);
      await local.close();
    } finally {
      await a.close();
      await b.close();
    }
  });
}
