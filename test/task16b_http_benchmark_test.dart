import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_http.dart';

void main() {
  test('G2 measured loopback connection reuse; bounds retained; not live GAS latency', () async {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final ports = <int>{};
    var requests = 0;
    server.listen((r) async {
      ports.add(r.connectionInfo!.remotePort);
      requests++;
      await r.drain<void>();
      r.response.headers.contentType = ContentType.json;
      r.response.write('{"ok":true,"status":200,"result":{}}');
      await r.response.close();
    });
    final result = <String, dynamic>{
      'measurement': 'REAL_LOOPBACK_HTTP_ONLY',
      'liveGas': 'NOT_RUN',
      'dnsTlsAuth': 'NOT_ISOLATED',
      'physicalWifiMobile': 'NOT_RUN',
    };
    try {
      for (final reuse in [false, true]) {
        ports.clear();
        final samples = <int>[];
        final http = AlchemistHttp(reuseConnections: reuse);
        for (var n = 0; n < 20; n++) {
          final watch = Stopwatch()..start();
          final r = await http.request(
            'POST',
            Uri.parse('http://127.0.0.1:${server.port}'),
            {'content-type': 'application/json'},
            '{"operation":"catalog.get","traceId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}',
          );
          expect(r.status, 200);
          samples.add(watch.elapsedMicroseconds);
        }
        samples.sort();
        result[reuse ? 'pooled' : 'baseline'] = {
          'requests': 20,
          'tcpConnections': ports.length,
          'p50Micros': samples[10],
          'p95Micros': samples[18],
          'rawMicros': samples,
        };
        expect(ports.length, reuse ? 1 : 20);
      }
      expect(requests, 40);
      const path = String.fromEnvironment('SULFI_PERFORMANCE_OUTPUT');
      if (path.isNotEmpty) {
        await File(path).writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(result)}\n',
        );
      }
    } finally {
      await server.close(force: true);
      HttpOverrides.global = overrides;
    }
  });
}
