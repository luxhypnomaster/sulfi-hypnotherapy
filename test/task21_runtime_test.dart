import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/vitrine_config.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/metadata_gateway.dart';
import 'package:sulfi_hypnotherapy/services/catalog_snapshot_sync.dart';
import 'package:sulfi_hypnotherapy/services/vitrine_settings.dart';

import 'support/task21_server.dart';
import 'task15_export_test.dart' show seed15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('21 actual runtime factory handshake + six queue refresh + cold/equal HEAD and no media transfer', () async {
    final server = await Server21.open();
    addTearDown(server.close);
    final app = await App21.open(server);
    try {
      await server.call('control.seed', {'version': 1});
      final runtime = app.c.metadata!;
      var changes = 0;
      runtime.sync.addListener(() => changes++);
      await Future.wait(
        List.generate(6, (_) => runtime.refresh(app.c.cloudQueue)),
      );
      await app.drain();
      expect(runtime.gateway.ready, true);
      expect(changes, 1);
      expect(
        (await runtime.cachedCards())!.single['card']['title'],
        'Синтетический модуль',
      );
      final counts = (await server.call('control.state', {}))['counts'];
      expect(counts['catalog.head'], 1);
      expect(counts['catalog.snapshot'], 1);
      expect(counts['metadata.capabilities'], 1);
      await runtime.refresh(app.c.cloudQueue);
      await app.drain();
      expect(changes, 1);
      final next = (await server.call('control.state', {}))['counts'];
      expect(next['catalog.snapshot'], 1);
      expect(
        next.keys.where((k) => (k as String).startsWith('media.')),
        isEmpty,
      );
      final cold = CatalogSnapshotSync(
        db: app.f.db,
        transport: runtime.gateway,
        owner: () => app.c.transferOwner,
      );
      expect(
        (await cold.lastGood('master:public'))!['head']['catalogRevision'],
        1,
      );
      cold.dispose();
    } finally {
      await app.close();
      await server.close();
    }
  });
  test('21 STAGING MASTER draft -> prepare/commit -> CLIENT verified separate config; lost response no duplicate', () async {
    final server = await Server21.open();
    addTearDown(server.close);
    final master = await App21.open(server),
        client = await App21.open(server, client: true);
    try {
      await server.call('control.seed', {'version': 1});
      final m = master.c.metadata!, c = client.c.metadata!;
      final oldSettings = VitrineSettingsStore(
        master.f.db,
        account: () => master.api.readerScope,
        canEdit: () => true,
      );
      await oldSettings.save(const VitrineConfig(entrySeconds: 9));
      expect(
        (await m.settings.load())['saved']['entrySeconds'],
        9,
        reason: 'preserve Task20 local saved settings namespace',
      );
      await m.gateway.negotiate();
      final settings = m.settings;
      await settings.save(const VitrineConfig(entrySeconds: 11));
      expect((await settings.load()).containsKey('published'), false);
      await server.call('control.mode', {'mode': 'lostConfigOnce'});
      await expectLater(settings.publish(), throwsA(isA<Exception>()));
      expect((await settings.load()).containsKey('published'), false);
      await settings.publish();
      expect((await settings.load())['publishedRevision'], 1);
      await c.refresh(client.c.cloudQueue);
      await client.drain();
      expect(client.diary.homeConfig.entrySeconds, 11);
      final state = await server.call('control.state', {});
      expect(state['catalogHead']['catalogRevision'], 1);
      expect(state['configHead']['configRevision'], 1);
      expect(c.gateway.canPublish, false);
      await expectLater(
        c.gateway.publish(
          requestId: 'bad',
          expectedRevision: 1,
          config: const VitrineConfig().toMap(),
        ),
        throwsA(isA<Exception>()),
      );
      expect(master.c.transferOwner, isNot(client.c.transferOwner));
      final foreign = CatalogSnapshotSync(
        db: master.f.db,
        transport: m.gateway,
        owner: () => client.c.transferOwner,
      );
      expect(await foreign.lastGood('master:public'), null);
      foreign.dispose();
    } finally {
      await master.close();
      await client.close();
      await server.close();
    }
  });
  test('21 offline/corrupt/403 keep lastGood and existing personal database/media rows intact', () async {
    final server = await Server21.open();
    addTearDown(server.close);
    final app = await App21.open(server);
    try {
      await seed15(app.f);
      final db = app.f.db;
      final names = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT IN ('app_settings','sqlite_sequence') ORDER BY name",
      )).map((r) => r['name'] as String).toList();
      Future<String> tables() async =>
          canonicalContent({for (final n in names) n: await db.query(n)});
      final before = await tables();
      final media = <String, String>{};
      for (final file
          in app.f.c.library.directory.listSync().whereType<File>()) {
        media[file.path] = contentDigest(await file.readAsBytes());
      }
      await server.call('control.seed', {'version': 1});
      final runtime = app.c.metadata!;
      await runtime.refresh(app.c.cloudQueue);
      await app.drain();
      final good = await runtime.sync.lastGood('master:public');
      await server.call('control.seed', {'version': 2});
      await server.call('control.mode', {'mode': 'corrupt'});
      await runtime.refresh(app.c.cloudQueue);
      await app.drain(allowFailure: true);
      expect(await runtime.sync.lastGood('master:public'), good);
      await server.call('control.mode', {'mode': 'offline'});
      final row = {
        'ownerBinding': app.c.transferOwner,
        'download': {'scope': 'master:public'},
      };
      await expectLater(
        runtime.execute(row, () => false),
        throwsA(isA<AlchemistFailure>().having((e) => e.status, 'status', 503)),
      );
      expect(await runtime.sync.lastGood('master:public'), good);
      await server.call('control.mode', {'mode': 'denied'});
      await expectLater(
        runtime.execute(row, () => false),
        throwsA(isA<AlchemistFailure>().having((e) => e.status, 'status', 403)),
      );
      expect(await tables(), before);
      for (final e in media.entries) {
        expect(contentDigest(await File(e.key).readAsBytes()), e.value);
      }
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
    } finally {
      await app.close();
      await server.close();
    }
  });
  test('21 disabled/default or unsupported handshake uses no new endpoints, stale bindings rejected', () async {
    final server = await Server21.open();
    addTearDown(server.close);
    final app = await App21.open(server, enabled: false);
    try {
      expect(app.c.metadata, null);
      final state = await server.call('control.state', {});
      expect(state['counts']['metadata.capabilities'], null);
    } finally {
      await app.close();
      await server.close();
    }
    final s = await Server21.open();
    addTearDown(s.close);
    final a = await App21.open(s);
    try {
      await s.call('control.mode', {'mode': 'unsupported'});
      expect(await a.c.metadata!.refresh(a.c.cloudQueue), false);
      expect(a.c.metadata!.gateway.state, 'legacy');
      expect(a.c.cloudQueue.rows, isEmpty);
      await s.call('control.mode', {'mode': 'wrongPrincipal'});
      expect(await a.c.metadata!.gateway.negotiate(force: true), false);
      expect(a.c.metadata!.gateway.ready, false);
    } finally {
      await a.close();
      await s.close();
    }
  });
  test('21 transient capability failure has bounded retry, no permanent unsupported state', () async {
    final server = await Server21.open();
    addTearDown(server.close);
    final app = await App21.open(server);
    var now = DateTime.now();
    final source = app.c.metadata!.gateway;
    final gateway = MetadataGateway(
      rpc: source.rpc,
      owner: source.owner,
      epoch: source.epoch,
      scope: source.scope,
      clock: () => now,
    );
    try {
      await server.call('control.mode', {'mode': 'offline'});
      expect(await gateway.negotiate(), false);
      expect(gateway.state, 'error');
      await expectLater(
        gateway.head(source.scope),
        throwsA(
          isA<AlchemistFailure>().having((e) => e.retryable, 'retryable', true),
        ),
      );
      expect(
        (await server.call(
          'control.state',
          {},
        ))['counts']['metadata.capabilities'],
        1,
      );
      await server.call('control.mode', {'mode': 'ready'});
      now = now.add(const Duration(seconds: 21));
      expect(await gateway.negotiate(), true);
      expect(
        (await server.call(
          'control.state',
          {},
        ))['counts']['metadata.capabilities'],
        2,
      );
    } finally {
      gateway.dispose();
      await app.close();
    }
  });
}
