import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_api.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_catalog.dart';
import 'package:sulfi_hypnotherapy/services/alchemist_errors.dart';
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
  test(
    '18 editing UI cannot replace the immutable queued publication payload',
    () async {
      final f = await Fixture15.open();
      final api = AlchemistApi(
        Uri.parse('https://script.google.com/macros/s/CONTROLLED/exec'),
        identityScope: () => 'account:controlled',
        credential: () async => 'CONTROLLED_NOT_GOOGLE',
      );
      final catalog = AlchemistCatalog(f.c, api: api);
      final original = <String, dynamic>{
        'catalogItemId': 'unchanged18',
        'ownerBinding': api.ownerBinding,
        'card': {'title': 'Original queued revision'},
      };
      try {
        await catalog.save(original, enqueue: true);
        final before = (await f.db.query(
          'app_settings',
          where: 'name=?',
          whereArgs: ['alchemist_card:unchanged18'],
        )).single['value'];
        final edited = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(original)),
        );
        edited['card']['title'] = 'New unsent editor revision';
        await expectLater(
          catalog.save(edited),
          throwsA(
            isA<AlchemistFailure>().having(
              (e) => e.code,
              'code',
              'REVISION_IN_FLIGHT',
            ),
          ),
        );
        expect(
          (await f.db.query(
            'app_settings',
            where: 'name=?',
            whereArgs: ['alchemist_card:unchanged18'],
          )).single['value'],
          before,
        );
        expect(edited['card']['title'], 'New unsent editor revision');
      } finally {
        await f.close();
      }
    },
  );
}
