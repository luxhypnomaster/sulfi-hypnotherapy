import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_http.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

void main() {
  test(
    'Drive wait has bounded timeout; redirect and response size stay guarded',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await request.drain<void>();
        if (request.uri.path == '/slow') {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"ok":true}');
        } else if (request.uri.path == '/large') {
          request.response.add(List<int>.filled(2 * 1024 * 1024 + 1, 32));
        } else {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/should-not-follow');
        }
        try {
          await request.response.close();
        } on IOException catch (_) {
          // Expected when the bounded reader closes a timed-out/oversized body.
        }
      });
      final base = Uri.parse('http://127.0.0.1:${server.port}');
      try {
        expect(
          const AlchemistHttp().responseTimeout,
          const Duration(seconds: 90),
        );
        final result = await const AlchemistHttp().request(
          'POST',
          base.resolve('/slow'),
          {},
          '{}',
        );
        expect(result.body, '{"ok":true}');
        expect(result.headers['content-type'], 'application/json');
        await expectLater(
          const AlchemistHttp(responseTimeout: Duration(milliseconds: 10))
              .request('POST', base.resolve('/slow'), {}, '{}'),
          throwsA(isA<TimeoutException>()),
        );
        final redirect = await const AlchemistHttp().request(
          'POST',
          base.resolve('/redirect'),
          {},
          '{}',
        );
        expect(redirect.status, 302);
        expect(redirect.headers['location'], '/should-not-follow');
        await expectLater(
          const AlchemistHttp().request(
            'GET',
            base.resolve('/large'),
            {},
            null,
          ),
          throwsA(isA<DiaryApiException>()),
        );
      } finally {
        await server.close(force: true);
      }
    },
  );
}
