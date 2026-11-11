import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

void main() {
  test('new GAS envelope follows content redirect without forwarding owner identity', () async {
    var requests = 0;
    final endpoint = Uri.parse(
      'https://script.google.com/macros/s/verified-fixture/exec',
    );
    final api = AlchemistApi(
      endpoint,
      credential: () async => 'SYNTHETIC_ID_TOKEN',
      connection: (method, uri, headers, body) async {
        requests++;
        if (requests == 1) {
          expect(method, 'POST');
          expect(uri, endpoint);
          expect(uri.query, '');
          expect(headers.containsKey('Authorization'), false);
          final value = jsonDecode(body!);
          expect(value['credential'], 'SYNTHETIC_ID_TOKEN');
          expect(value['version'], 1);
          expect(value['operation'], 'catalog.list');
          return const DiaryResponse(
            302,
            '',
            headers: {
              'location':
                  'https://script.googleusercontent.com/result?opaque=fixture',
            },
          );
        }
        expect(method, 'GET');
        expect(body, null);
        expect(headers.containsKey('Authorization'), false);
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {'items': []},
          }),
        );
      },
    );
    expect(await api.call('catalog.list', {}), {'items': []});
    expect(requests, 2);
  });
  test('logical deny, HTML and credential redirect fail closed', () async {
    final endpoint = Uri.parse(
      'https://script.google.com/macros/s/fixture/exec',
    );
    for (final response in [
      const DiaryResponse(200, '<html>login</html>'),
      const DiaryResponse(
        200,
        '{"ok":false,"status":403,"error":{"code":"AUTHOR_REQUIRED"}}',
      ),
      const DiaryResponse(
        302,
        '',
        headers: {'location': 'https://accounts.google.com/login'},
      ),
    ]) {
      final api = AlchemistApi(
        endpoint,
        connection: (_, _, _, _) async => response,
      );
      await expectLater(
        api.call('catalog.publish', {}),
        throwsA(isA<DiaryApiException>()),
      );
    }
    expect(
      () => AlchemistApi(Uri.parse('https://drive.google.com/private')),
      throwsFormatException,
    );
  });
}
