// Opt-in measured REAL loopback TCP; neither live GAS nor Wi-Fi benchmark.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_http.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_media_transfer.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_install.dart';

import 'support/task15_fixture.dart';

void main() {
  test(
    '18 measured 1/15/50MiB actual TCP upload verification and checked download',
    () async {
      final reuse = Platform.environment['TASK18_PERF_KEEPALIVE'] == '1';
      final process = await Process.start(
        'node',
        ['scripts/task18/fixture_server.mjs'],
        environment: {'PROBE18_PORT': '0', 'PROBE18_LATENCY_MS': '0'},
      );
      final errors = <String>[];
      process.stderr.transform(utf8.decoder).listen(errors.add);
      final port = int.parse(
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first,
      );
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      final f = await Fixture15.open();
      final c = await Fixture15.open(client: true);
      final results = <Map<String, dynamic>>[];
      final counts = <String, int>{}, times = <String, int>{};
      final api = AlchemistApi(
        Uri.parse('https://script.google.com/macros/s/CONTROLLED_PERF18/exec'),
        identityScope: () => 'account:controlled-perf',
        credential: () async => 'CONTROLLED_OWNER_18_${'x' * 180}',
        connection: (method, _, headers, body) async {
          final op = jsonDecode(body!)['operation'] as String;
          final clock = Stopwatch()..start();
          final result = await AlchemistHttp(reuseConnections: reuse).request(
            method,
            Uri.parse('http://127.0.0.1:$port'),
            {...headers, 'X-Controlled-Transfer18': 'fixture-only'},
            body,
          );
          counts[op] = (counts[op] ?? 0) + 1;
          times[op] = (times[op] ?? 0) + clock.elapsedMicroseconds;
          return result;
        },
      );
      try {
        for (final mib in [1, 15, 50]) {
          counts.clear();
          times.clear();
          final file = File('${f.root.path}/synthetic-$mib.raw');
          final data = Uint8List(mib * 1024 * 1024);
          // Deterministic synthetic binary fixture, no recording/synthetic voice.
          for (var i = 0; i < data.length; i += 4096) {
            data[i] = (i ~/ 4096) % 251;
          }
          await file.writeAsBytes(data, flush: true);
          final hash = sha256.convert(data).toString();
          final clock = Stopwatch()..start();
          final receipt = await AlchemistMediaTransfer(f.db, api).upload(
            file,
            logicalId: 'perf-$mib',
            revisionId: hash,
            mime: 'audio/wav',
          );
          final uploadUs = clock.elapsedMicroseconds;
          expect(receipt['sha256'], hash);
          expect(receipt['byteLength'], data.length);
          final uploadCalls = Map<String, int>.from(counts),
              uploadTime = Map<String, int>.from(times);
          counts.clear();
          times.clear();
          clock.reset();
          final descriptor = await api.call('media.getDescriptor', {
            'assetRevisionId': receipt['assetRevisionId'],
          });
          final downloaded = await AlchemistInstall(
            c.c.capsules!,
            api,
          ).downloadAsset(descriptor);
          final downloadUs = clock.elapsedMicroseconds;
          expect(
            (await sha256.bind(downloaded.openRead()).first).toString(),
            hash,
          );
          expect(await downloaded.length(), data.length);
          expect(uploadCalls['media.uploadChunk'], data.length ~/ 262144);
          results.add({
            'MiB': mib,
            'bytes': data.length,
            'sha256': hash,
            'uploadIncludingLocalHashAndVerifyUs': uploadUs,
            'downloadIncludingHashAndFinalReceiptUs': downloadUs,
            'uploadRpcCount': uploadCalls,
            'uploadRpcElapsedUs': uploadTime,
            'downloadRpcCount': Map<String, int>.from(counts),
            'downloadRpcElapsedUs': Map<String, int>.from(times),
            'status': 'PASS_CONTROLLED_TCP',
          });
        }
        final output = Platform.environment['TASK18_PERF_OUTPUT'];
        if (output != null) {
          await File(output).writeAsString(
            '${const JsonEncoder.withIndent('  ').convert({'httpConnectionReuse': reuse, 'classification': 'CONTROLLED_REAL_LOOPBACK_TCP_PRODUCTION_JS_DOMAIN', 'GAS': 'NOT_RUN', 'WiFi': 'NOT_RUN', 'Google': 'NOT_RUN', 'clock': 'Stopwatch microseconds', 'fileSizes': 'MiB (1024*1024), not decimal MB', 'results': results, 'speedImprovementClaim': 'NONE; baseline only, no before/after live comparison'})}\n',
          );
        }
        expect(results.length, 3);
        expect(errors, isEmpty);
      } finally {
        process.kill();
        HttpOverrides.global = previous;
        await c.close();
        await f.close();
      }
    },
    skip: Platform.environment['TASK18_PERF_OUTPUT'] == null
        ? 'Opt-in measured benchmark, not repeated in every unit CI'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
