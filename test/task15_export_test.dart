import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/export_file_name.dart';
import 'package:sulfi_hypnotherapy/services/device_files.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/ui/library_screen.dart';

import 'support/task15_fixture.dart';
import 'support/task15_harness.dart';

Future<ModuleDefinition> seed15(Fixture15 f) async {
  final base = await File('test/fixtures/android_aac_isom.m4a').readAsBytes();
  final steps = <SessionStep>[];
  for (var i = 1; i <= 3; i++) {
    final data = [
      ...base,
      0,
      0,
      0,
      9,
      102,
      114,
      101,
      101,
      i,
    ]; // distinct valid MP4 free atoms
    final name = 'asset_export_$i.m4a';
    await File('${f.c.library.directory.path}/$name').writeAsBytes(data);
    final asset = AudioAsset(
      id: 'audio-$i',
      title: 'Аудио $i',
      filePath: name,
      durationMs: 65000,
      format: 'm4a',
      createdAt: DateTime.utc(2026),
      category: AudioCategory.induction,
      fileSizeBytes: data.length,
      contentHash: sha256.convert(data).toString(),
      section: LibrarySection.personal,
      origin: 'personal',
    );
    await f.c.library.save(asset);
    steps.add(
      SessionStep(
        id: 'track-$i',
        kind: StepKind.audio,
        title: asset.title,
        audioAssetId: asset.id,
        durationMs: 65000,
      ),
    );
    if (i < 3) {
      steps.add(
        SessionStep(
          id: 'pause-$i',
          kind: StepKind.silence,
          title: 'Пауза',
          durationMs: (i + 5) * 1000,
        ),
      );
    }
  }
  final m = ModuleDefinition(
    id: 'portable-module',
    title: 'Глубокое расслабление',
    items: steps,
  );
  await f.c.modules.save(m);
  await f.c.reload();
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'G2 NFC transliteration, safe bounded ASCII names and backup separation',
    () {
      final date = DateTime(2026, 11, 9);
      expect(
        exportFileName(localDate: date, title: 'Глубокое расслабление'),
        'Sulfi_exp_Glubokoe_rasslablenie_09.11.26.zip',
      );
      expect(
        exportFileName(localDate: date, title: 'Е\u0308ж И\u0306ога'),
        'Sulfi_exp_Yozh_Yoga_09.11.26.zip',
      );
      expect(
        exportFileName(localDate: date, title: 'café.zip.zip'),
        'Sulfi_exp_cafe_09.11.26.zip',
      );
      expect(
        exportFileName(localDate: date, title: '💥\u0000../'),
        'Sulfi_exp_Untitled_09.11.26.zip',
      );
      expect(exportFileName(localDate: date), 'Sulfi_backup_09.11.26.zip');
      final rng = Random(15);
      for (var i = 0; i < 300; i++) {
        final title = String.fromCharCodes(
          List.generate(rng.nextInt(500), (_) => rng.nextInt(0x110000)),
        );
        final name = exportFileName(localDate: date, title: title);
        expect(name, matches(r'^Sulfi_exp_[A-Za-z0-9_]+_09\.11\.26\.zip$'));
        expect(name.length, lessThan(130));
        expect(p.basename(name), name);
        expect(name, isNot(contains('..')));
      }
    },
  );
  test('G2 local date, UTC manifest and three audio/two pauses roundtrip without unrelated content', () async {
    final a = await Fixture15.open(), b = await Fixture15.open();
    try {
      final m = await seed15(a);
      final localDate = DateTime(2026, 11, 9, 23, 59);
      if (Platform.environment['TZ'] == 'America/New_York') {
        expect(localDate.toUtc().day, 10);
      }
      final service = CapsuleService(
        database: a.db,
        library: a.c.library,
        diaryDirectory: a.c.capsules!.diaryDirectory,
        workspace: a.c.capsules!.workspace,
        clock: () => localDate,
      );
      final zip = await service.export(moduleId: m.id);
      expect(
        p.basename(zip.path),
        'Sulfi_exp_Glubokoe_rasslablenie_09.11.26.zip',
      );
      final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.content),
      );
      expect(manifest['originalTitle'], m.title);
      expect(manifest['exportedAt'], localDate.toUtc().toIso8601String());
      expect(manifest['scope'], 'module');
      expect(manifest['databaseSchema'], 9);
      expect(
        archive.files.where((f) => f.isFile && f.name.startsWith('blobs/')),
        hasLength(3),
      );
      expect(manifest['records']['session_runs'], isEmpty);
      expect(manifest['records']['diary_author'], isEmpty);
      final source = await LocalCatalogSource.open(b.c.capsules!, zip);
      final root = source.revisions.singleWhere(
        (r) => r.key.content.type == ContentType.module,
      );
      final plan = await source.plan(root.key);
      expect(plan.missingDigests, hasLength(3));
      await source.install(plan);
      await b.c.reload();
      expect(b.c.modules.entries.single.items.map((s) => s.kind), [
        StepKind.audio,
        StepKind.silence,
        StepKind.audio,
        StepKind.silence,
        StepKind.audio,
      ]);
      expect(b.c.modules.entries.single.items.map((s) => s.durationMs), [
        65000,
        6000,
        65000,
        7000,
        65000,
      ]);
      expect(
        b.c.assets.map((v) => v.contentHash).toSet(),
        a.c.assets.map((v) => v.contentHash).toSet(),
      );
      expect((await source.plan(root.key)).newBytes, 0);
      await source.install(await source.plan(root.key));
      expect(await b.c.library.directory.list().length, 3);
      final backup = await service.export();
      expect(p.basename(backup.path), 'Sulfi_backup_09.11.26.zip');
      final again = await service.export(moduleId: m.id);
      expect(p.basename(again.path), p.basename(zip.path));
      expect(again.path, isNot(zip.path));
      expect(await zip.exists(), true);
      await source.close();
      await a.c.modules.save(
        ModuleDefinition(
          id: m.id,
          title: m.title,
          version: 2,
          items: [
            ...m.items,
            const SessionStep(
              id: 'extra',
              kind: StepKind.silence,
              title: 'Пауза',
              durationMs: 1000,
            ),
          ],
        ),
      );
      final changed = await service.export(moduleId: m.id);
      final conflict = await LocalCatalogSource.open(b.c.capsules!, changed);
      await expectLater(
        conflict.install(
          await conflict.plan(
            conflict.revisions
                .singleWhere((r) => r.key.content.type == ContentType.module)
                .key,
          ),
        ),
        throwsFormatException,
      );
      await b.c.modules.load();
      expect(b.c.modules.entries.single.version, 1);
      expect(await b.c.library.directory.list().length, 3);
      await conflict.close();
    } finally {
      await a.close();
      await b.close();
    }
  });
  test('G2 SAF forwards human filenames; fake document provider suffixes duplicates', () async {
    final a = await Fixture15.open();
    final documents = await Directory.systemTemp.createTemp('task15-saf');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    try {
      final m = await seed15(a);
      final service = CapsuleService(
        database: a.db,
        library: a.c.library,
        diaryDirectory: a.c.capsules!.diaryDirectory,
        workspace: a.c.capsules!.workspace,
        clock: () => DateTime(2026, 11, 9),
      );
      final first = await service.export(moduleId: m.id),
          second = await service.export(moduleId: m.id);
      messenger.setMockMethodCallHandler(DeviceFiles.channel, (call) async {
        expect(call.method, 'saveZip');
        final input = File(call.arguments['path']);
        final name = p.basename(input.path);
        expect(name, 'Sulfi_exp_Glubokoe_rasslablenie_09.11.26.zip');
        var destination = File(p.join(documents.path, name));
        var suffix = 2;
        while (await destination.exists()) {
          destination = File(
            p.join(
              documents.path,
              '${p.basenameWithoutExtension(name)}-${suffix++}.zip',
            ),
          );
        }
        await input.copy(destination.path);
        return true;
      });
      expect(await DeviceFiles.save(first.path), true);
      expect(await DeviceFiles.save(second.path), true);
      expect(
        (await documents.list().toList())
            .map((x) => p.basename(x.path))
            .toSet(),
        {
          'Sulfi_exp_Glubokoe_rasslablenie_09.11.26.zip',
          'Sulfi_exp_Glubokoe_rasslablenie_09.11.26-2.zip',
        },
      );
      expect(await first.exists(), true);
      expect(await second.exists(), true);
    } finally {
      messenger.setMockMethodCallHandler(DeviceFiles.channel, null);
      await a.close();
      await documents.delete(recursive: true);
    }
  });
  testWidgets(
    'G2 visible Import ZIP routes through shared catalog into empty profile and existing preview',
    (t) async {
      final a = (await t.runAsync(() => Fixture15.open()))!,
          b = (await t.runAsync(() => Fixture15.open()))!;
      try {
        final m = (await t.runAsync(() => seed15(a)))!;
        final zip = (await t.runAsync(
          () => a.c.capsules!.export(moduleId: m.id),
        ))!;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('ru.sulfi/device_files'),
              (call) async => call.method == 'openZip' ? zip.path : false,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('ru.sulfi/device_files'),
                null,
              ),
        );
        await show15(
          t,
          b,
          LibraryScreen(
            library: b.c.library,
            player: b.player,
            controller: b.c,
          ),
        );
        await t.tap(find.byTooltip('О приложении и данных'));
        await io15(t);
        await t.ensureVisible(find.text('Импортировать ZIP'));
        await t.tap(find.text('Импортировать ZIP'));
        await io15(t);
        for (var i = 0; i < 80 && find.text(m.title).evaluate().isEmpty; i++) {
          await io15(t);
        }
        expect(b.c.assets, isEmpty);
        await t.ensureVisible(find.text(m.title));
        await t.tap(find.text(m.title));
        await io15(t);
        await capture15(t, 'g2-import-preview');
        await t.tap(find.widgetWithText(FilledButton, 'Установить'));
        await io15(t);
        for (
          var i = 0;
          i < 80 && find.text('Установлено').evaluate().isEmpty;
          i++
        ) {
          await io15(t);
        }
        expect(find.text('Установлено'), findsOneWidget);
        expect(
          find.textContaining('Шаблоны и модули → Модули'),
          findsOneWidget,
        );
        expect(b.c.assets, hasLength(3));
        expect(b.c.modules.entries.single.items, hasLength(5));
        await capture15(t, 'g2-import-installed');
        final asset = b.c.assets.first;
        await b.player.toggle(asset, b.c.library.fileFor(asset));
        expect(b.player.playing, true);
        expect(
          await t.runAsync(() => b.c.library.fileFor(asset).exists()),
          true,
        );
        await b.player.stop();
        await t.pumpWidget(const SizedBox());
        await io15(t);
      } finally {
        await t.runAsync(a.close);
        await t.runAsync(b.close);
      }
    },
  );
}
