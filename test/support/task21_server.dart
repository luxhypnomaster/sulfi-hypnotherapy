import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_diary_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_media_store.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'task15_fixture.dart';

final endpoint21 = Uri.parse(
  'https://script.google.com/macros/s/AKfycbxTask21Fixture/exec',
);

/// Real loopback TCP and persistent Node SQLite; synthetic credentials only.
/// The injected DiaryRequest preserves production endpoint validation unchanged.
class Server21 {
  Server21(this.root, this.process, this.uri);
  final Directory root;
  final Process process;
  final Uri uri;
  final HttpClient http = HttpOverrides.runWithHttpOverrides(
    () => HttpClient(),
    _LoopbackHttpOverrides(),
  );
  bool _closed = false;
  static Future<Server21> open({
    String script = 'server/alchemist/test/support/runtime21-fixture.cjs',
  }) async {
    final root = await Directory.systemTemp.createTemp('task21-server-');
    final child = await Process.start(
      'node',
      [script, '${root.path}/sandbox.sqlite', endpoint21.toString()],
      environment: {'SULFI_TEST21_SANDBOX': '1'},
    );
    child.stderr.listen((_) {
      /* No secrets; Node SQLite experimental notice. */
    });
    final first = await child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    final port = jsonDecode(first)['port'] as int;
    return Server21(root, child, Uri.parse('http://127.0.0.1:$port'));
  }

  Future<DiaryResponse> connection(
    String method,
    Uri ignored,
    Map<String, String> headers,
    String? body,
  ) async {
    final r = await http.postUrl(uri);
    r.headers.contentType = ContentType.json;
    r.write(body);
    final s = await r.close().timeout(const Duration(seconds: 10));
    return DiaryResponse(s.statusCode, await s.transform(utf8.decoder).join());
  }

  Future<Map<String, dynamic>> call(
    String op,
    Map<String, dynamic> p, {
    String credential = 'fixture-owner',
  }) async {
    final r = await connection(
      'POST',
      uri,
      {},
      jsonEncode({
        'version': 1,
        'operation': op,
        'parameters': p,
        'credential': credential,
      }),
    );
    final v = jsonDecode(r.body);
    if (v['ok'] != true) {
      throw AlchemistFailure.server(
        v['status'] as int,
        v['error']['code'] as String,
      );
    }
    return Map<String, dynamic>.from(v['result']);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    http.close(force: true);
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(const Duration(seconds: 10));
    await root.delete(recursive: true);
  }
}

class App21 {
  App21(this.f, this.api, this.diary, this.c);
  final Fixture15 f;
  final AlchemistDiaryApi api;
  final DiaryController diary;
  final SessionController c;
  static Future<App21> open(
    Server21 server, {
    bool client = false,
    bool enabled = true,
    bool projectEnabled = false,
  }) async {
    final f = await Fixture15.open(client: client);
    final media = DiaryMediaStore(
      Directory('${f.root.path}/diary'),
      pick: (_) async => null,
      probe: (_) async => null,
    );
    final api = AlchemistDiaryApi(
      endpoint21,
      capsules: f.c.capsules!,
      media: media,
      connection: server.connection,
    );
    await api.authenticateReader(client ? 'fixture-client' : 'fixture-owner');
    final diary = DiaryController(
      AlchemistDiaryRepository(f.db, scope: () => api.readerScope),
      api: api,
      policy: f.c.policy,
      authorRepository: DiaryAuthorRepository(f.db),
      mediaStore: media,
    );
    await diary.load();
    final c = SessionController(
      repository: f.c.repository,
      library: f.c.library,
      modules: f.c.modules,
      capsules: f.c.capsules,
      diary: diary,
      metadataEnabled: enabled,
      project22Enabled: projectEnabled,
    );
    await c.reload();
    return App21(f, api, diary, c);
  }

  Future<void> drain({bool allowFailure = false}) async {
    await c.cloudQueue.runPending();
    for (var i = 0; i < 500; i++) {
      await c.cloudQueue.refresh();
      if (c.cloudQueue.rows.every(
        (r) => !const [
          'queued',
          'preparing',
          'running',
        ].contains(r['_work']['phase']),
      )) {
        if (!allowFailure &&
            c.cloudQueue.rows.any((r) => r['_work']['phase'] != 'complete')) {
          throw StateError(
            'CONTROLLED_JOB_FAILED ${c.cloudQueue.rows.map((r) => r['_work']['code']).toList()}',
          );
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('controlled queue drain');
  }

  Future<void> close() async {
    await c.flush();
    c.dispose();
    diary.dispose();
    await f.close();
  }
}

// Tests only: Flutter binding replaces HTTP with400; this private zone uses real
// loopback TCP. Production TLS, OAuth and HttpOverrides remain unchanged.
class _LoopbackHttpOverrides extends HttpOverrides {}
