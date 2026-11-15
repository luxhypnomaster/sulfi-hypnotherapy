import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';

import 'support/task15_fixture.dart';

void main() {
  test('18 process death after transition receipt reuses original request, not another mutation', () async {
    final f = await Fixture15.open();
    final calls = <Map<String, dynamic>>[];
    final api = AlchemistApi(
      Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
      identityScope: () => 'account:controlled',
      credential: () async => 'CONTROLLED_NOT_GOOGLE',
      connection: (_, _, _, body) async {
        final request = Map<String, dynamic>.from(jsonDecode(body!));
        calls.add(request);
        return DiaryResponse(
          200,
          jsonEncode({
            'ok': true,
            'status': 200,
            'result': {
              'etag': 'after',
              'publicationState': 'withdrawn',
              'catalogItemId': 'fixed-item',
            },
          }),
        );
      },
    );
    final draft = <String, dynamic>{
      'catalogItemId': 'fixed-item',
      'ownerBinding': api.ownerBinding,
      'etag': 'before',
      'requestedAction': 'withdraw',
      'pending': {
        'operation': 'catalog.withdraw',
        'parameters': {
          'requestId': 'original-request',
          'catalogItemId': 'fixed-item',
          'ifMatch': 'before',
        },
      },
    };
    try {
      final catalog = AlchemistCatalog(f.c, api: api);
      await catalog.transition(draft, 'withdraw');
      expect(calls.length, 1);
      expect(calls.single['parameters']['requestId'], 'original-request');
      expect(draft['status'], 'withdrawn');
      expect(draft['pending'], isNull);
      // An executor can die after local receipt but before marking _work complete.
      await catalog.transition(draft, 'withdraw');
      expect(calls.length, 1);
      expect(draft['lastReceipt']['requestId'], 'original-request');
    } finally {
      await f.close();
    }
  });
}
