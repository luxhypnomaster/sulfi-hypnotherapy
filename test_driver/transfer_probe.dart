// Disposable Android/real TCP test target. NO real Google account/token/GAS.
// Not imported by lib/main.dart; not included in either shipping candidate.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/library_repository.dart';
import 'package:sulfi_hypnotherapy/data/module_catalog.dart';
import 'package:sulfi_hypnotherapy/data/session_repository.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/audio_asset.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/services/access_policy.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_http.dart';
import 'package:sulfi_hypnotherapy/services/capsule_service.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/library_service.dart';
import 'package:sulfi_hypnotherapy/services/local_content_catalog.dart';
import 'package:sulfi_hypnotherapy/services/native_transfer_bridge.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';
import 'package:sulfi_hypnotherapy/services/transfer_worker.dart';

const fixtureEndpoint =
    'https://script.google.com/macros/s/CONTROLLED_NATIVE18_NO_GAS/exec';
Future<DiaryResponse> fixtureRequest(
  String method,
  Uri uri,
  Map<String, String> headers,
  String? body,
) async {
  return const AlchemistHttp().request(
    method,
    Uri.parse('http://10.0.2.2:4018'),
    {...headers, 'X-Controlled-Transfer18': 'fixture-only'},
    body,
  );
}

@pragma('vm:entry-point')
void transferMain() {
  unawaited(runTransferWorker(controlledConnection: fixtureRequest));
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Controlled18()));
}

class Controlled18 extends StatefulWidget {
  const Controlled18({super.key});
  @override
  State<Controlled18> createState() => _Controlled18State();
}

class _Controlled18State extends State<Controlled18> {
  SessionController? c;
  Timer? timer;
  String message = 'CONTROLLED NATIVE18 · Google NOT_RUN';
  bool busy = false;
  AudioSelection? nextSelection;
  Future<void> initialize() async {
    if (c != null) return;
    final root = await getApplicationSupportDirectory();
    final repo = await SqliteLibraryRepository.open(
      p.join(root.path, 'library.sqlite'),
    );
    final policy = AccessPolicy(database: repo.database);
    await policy.load();
    Future<Duration?> codecProbe(String path) async {
      final ms = await NativeTransferBridge.channel.invokeMethod<int>(
        'probeAudio',
        {'path': path},
      );
      return ms == null ? null : Duration(milliseconds: ms);
    }

    final media = DiaryMediaStore(
      Directory(p.join(root.path, 'diary_media')),
      pick: (_) async => null,
      probe: codecProbe,
    );
    final library = LibraryService(
      repository: repo,
      policy: policy,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => nextSelection,
      probe: (path) async => Duration(
        milliseconds: (await NativeTransferBridge.channel.invokeMethod<int>(
          'probeAudio',
          {'path': path},
        ))!,
      ),
    );
    await library.initialize();
    final capsules = CapsuleService(
      database: repo.database,
      library: library,
      diaryDirectory: media.directory,
      workspace: Directory(p.join(root.path, 'fixture_workspace')),
    );
    final api = AlchemistDiaryApi(
      Uri.parse(fixtureEndpoint),
      capsules: capsules,
      media: media,
      connection: fixtureRequest,
    );
    final actor = policy.clientEdition ? 'CLIENT' : 'OWNER';
    await api.authenticateReader('CONTROLLED_${actor}_18_${'x' * 180}');
    policy.applyVerifiedServerRole(api.verifiedRole);
    final diary = DiaryController(
      AlchemistDiaryRepository(repo.database, scope: () => api.readerScope),
      api: api,
      policy: policy,
      mediaStore: media,
      authorRepository: DiaryAuthorRepository(repo.database),
    );
    c = SessionController(
      repository: SqliteSessionRepository(repo.database, policy),
      library: library,
      modules: ModuleCatalog(repo.database, policy),
      diary: diary,
      capsules: capsules,
    );
    await c!.initialize();
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || c == null) return;
      await c!.cloudQueue.refresh();
      if (mounted) setState(() {});
    });
  }

  Future<void> seed() async {
    final ctrl = c!;
    if ((await ctrl.library.repository.list()).isNotEmpty) return;
    final steps = <SessionStep>[];
    final bytes = const int.fromEnvironment(
      'PROBE18_BYTES',
      defaultValue: 15 * 1024 * 1024,
    );
    for (var i = 0; i < 3; i++) {
      final dataBytes = ((bytes ~/ 3 - 44) ~/ 2) * 2 + i * 2;
      final header = ByteData(44);
      void text(int offset, String value) {
        for (var j = 0; j < value.length; j++) {
          header.setUint8(offset + j, value.codeUnitAt(j));
        }
      }

      text(0, 'RIFF');
      header.setUint32(4, dataBytes + 36, Endian.little);
      text(8, 'WAVEfmt ');
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, 1, Endian.little);
      header.setUint32(24, 8000, Endian.little);
      header.setUint32(28, 16000, Endian.little);
      header.setUint16(32, 2, Endian.little);
      header.setUint16(34, 16, Endian.little);
      text(36, 'data');
      header.setUint32(40, dataBytes, Endian.little);
      final name = 'controlled-$i.wav';
      final input = Directory(
        p.join(ctrl.library.directory.parent.path, 'fixture_input'),
      );
      await input.create(recursive: true);
      final file = File(p.join(input.path, name));
      final output = await file.open(mode: FileMode.write);
      await output.writeFrom(header.buffer.asUint8List());
      final zeros = Uint8List(65536);
      var left = dataBytes;
      while (left > 0) {
        final length = left.clamp(0, zeros.length);
        await output.writeFrom(zeros, 0, length);
        left -= length;
      }
      await output.flush();
      await output.close();
      nextSelection = (name: name, path: file.path);
      final a = (await ctrl.library.prepareImport())!;
      final asset = AudioAsset.fromMap({
        ...a.toMap(),
        'title': 'CONTROLLED18 audio ${i + 1}',
      });
      await ctrl.library.save(asset);
      steps.add(
        SessionStep(
          id: newId(),
          kind: StepKind.audio,
          title: asset.title,
          audioAssetId: asset.id,
          durationMs: asset.durationMs,
        ),
      );
    }
    final module = ModuleDefinition(
      id: 'controlled_module18',
      title: 'CONTROLLED18 module',
      items: steps,
    );
    await ctrl.modules.save(module);
    final plan = SessionPlan(
      steps: const [],
      phases: [
        PhaseInstance(
          id: 'phase18',
          typeId: 'induction',
          title: 'CONTROLLED phase',
          children: [module.instantiate('phase18')],
        ),
      ],
    );
    await ctrl.repository.saveTemplate(
      SessionTemplate(
        id: 'controlled_program18',
        name: 'CONTROLLED18 program',
        plan: plan,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await ctrl.reload();
  }

  Future<void> action(bool upload, {bool destroy = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await initialize();
      if (upload) {
        await seed();
        final index = await LocalCatalogSource.currentIndex(c!.capsules!);
        final root = index.singleWhere(
          (r) =>
              r.key.content.type == ContentType.template &&
              r.key.content.id == 'controlled_program18',
        );
        final draft = await c!.catalog.prepare(root);
        draft['card']['shortAnnotation'] =
            'CONTROLLED synthetic PCM, no voice or Google';
        draft['card']['visibility'] = 'public';
        await c!.catalog.save(draft, enqueue: true);
        await c!.cloudQueue.enqueue('alchemist_card:${draft['catalogItemId']}');
      } else {
        final page = await c!.catalog.api!.call('catalog.list', {'limit': 50});
        final card = (page['items'] as List)
            .map((x) => Map<String, dynamic>.from(x))
            .singleWhere(
              (x) => x['logicalContentId'] == 'controlled_program18',
            );
        final detail = await c!.catalog.api!.call('catalog.get', {
          'catalogItemId': card['catalogItemId'],
        });
        await c!.installInBackground(detail);
      }
      setState(
        () => message =
            'NATIVE JOB ENQUEUED · ${upload ? 'UPLOAD' : 'DOWNLOAD'} · NO REAL GOOGLE',
      );
      if (destroy) {
        await const MethodChannel('ru.sulfi/controlled18')
            .invokeMethod('destroyUi');
      }
    } catch (e) {
      if (mounted) setState(() => message = AlchemistFailure.from(e).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inventory() async {
    await initialize();
    await c!.reload();
    await c!.cloudQueue.refresh();
    final assets = await c!.library.repository.list();
    var valid = 0;
    for (final a in assets) {
      final file = c!.library.fileFor(a);
      if (await file.exists() &&
          (await sha256.bind(file.openRead()).first).toString() ==
              a.contentHash) {
        valid++;
      }
    }
    if (mounted) {
      setState(
        () => message =
            'NATIVE INVENTORY ${assets.length} AUDIO / $valid HASH / ${c!.modules.entries.length} MODULE / ${c!.templates.length} PROGRAM',
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CONTROLLED18 · not Google QA')),
    body: SingleChildScrollView(
      child: Column(
        children: [
          Text(message),
          FilledButton(
            onPressed: busy ? null : () => action(true, destroy: true),
            child: const Text('UPLOAD AND DESTROY UI'),
          ),
          FilledButton(
            onPressed: busy ? null : () => action(false, destroy: true),
            child: const Text('DOWNLOAD AND DESTROY UI'),
          ),
          TextButton(onPressed: inventory, child: const Text('READ INVENTORY')),
          for (final row in c?.cloudQueue.rows ?? <Map<String, dynamic>>[])
            Text(
              '${row['_work']?['phase']} ${row['_work']?['bytes']} / ${row['_work']?['totalBytes']}',
            ),
        ],
      ),
    ),
  );
}
