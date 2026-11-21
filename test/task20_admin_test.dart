import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/content_revision.dart';
import 'package:sulfi_hypnotherapy/models/vitrine_config.dart';
import 'package:sulfi_hypnotherapy/services/vitrine_settings.dart';

import 'support/task15_fixture.dart';

// Controlled response/receipt adapter, never a live role or production server.
class Admin20 implements VitrineAdminTransport {
  bool deny = false, lose = false, corrupt = false;
  int calls = 0, commits = 0;
  Completer<void>? gate;
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> publish({
    required String requestId,
    required int expectedRevision,
    required Map<String, dynamic> config,
  }) async {
    calls++;
    await gate?.future;
    if (deny) throw const FormatException('SERVER_ROLE_DENIED');
    final receipt = receipts.putIfAbsent(requestId, () {
      if (expectedRevision != commits) {
        throw const FormatException('REVISION_CONFLICT');
      }
      return {
        'requestId': requestId,
        'configHash': contentDigest(config),
        'configRevision': ++commits,
      };
    });
    if (lose) {
      lose = false;
      throw TimeoutException('controlled lost response');
    }
    return {...receipt, if (corrupt) 'configHash': 'bad'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('20 admin lost response retry reuses request, no duplicate commit; saved draft != published', () async {
    final f = await Fixture15.open(), a = Admin20()..lose = true;
    final s = VitrineSettingsStore(
      f.db,
      account: () => 'A',
      canEdit: () => true,
      admin: a,
    );
    try {
      await s.save(const VitrineConfig(entrySeconds: 8));
      await expectLater(s.publish(), throwsA(isA<TimeoutException>()));
      expect((await s.load()).containsKey('published'), false);
      await s.publish();
      expect(a.calls, 2);
      expect(a.commits, 1);
      expect((await s.load())['publishedRevision'], 1);
      await s.publish();
      expect(a.calls, 2);
    } finally {
      await f.close();
    }
  });
  test('20 admin deny and invalid receipt cannot fabricate publication; owner switch prevents apply', () async {
    final f = await Fixture15.open(), a = Admin20()..deny = true;
    String? account = 'A';
    final s = VitrineSettingsStore(
      f.db,
      account: () => account,
      canEdit: () => true,
      admin: a,
    );
    try {
      await s.save(const VitrineConfig());
      await expectLater(s.publish(), throwsFormatException);
      expect((await s.load()).containsKey('published'), false);
      a.deny = false;
      a.corrupt = true;
      await expectLater(s.publish(), throwsFormatException);
      expect((await s.load()).containsKey('published'), false);
      a.corrupt = false;
      a.gate = Completer<void>();
      final attempt = s.publish();
      for (var i = 0; i < 50 && a.calls < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      account = 'B';
      a.gate!.complete();
      await expectLater(attempt, throwsFormatException);
      expect(await s.load(), isEmpty);
      account = 'A';
      expect((await s.load()).containsKey('published'), false);
    } finally {
      await f.close();
    }
  });
  test(
    '20 pending publish preserves new saved edits and coalesces repeated taps',
    () async {
      final f = await Fixture15.open(), a = Admin20()..gate = Completer<void>();
      final s = VitrineSettingsStore(
        f.db,
        account: () => 'A',
        canEdit: () => true,
        admin: a,
      );
      try {
        await s.save(const VitrineConfig(entrySeconds: 8));
        final p = s.publish(), p2 = s.publish();
        for (var i = 0; i < 50 && a.calls < 1; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        await s.save(const VitrineConfig(entrySeconds: 11));
        a.gate!.complete();
        await Future.wait([p, p2]);
        final value = await s.load();
        expect(value['saved']['entrySeconds'], 11);
        expect(value['published']['entrySeconds'], 8);
        expect(a.commits, 1);
      } finally {
        await f.close();
      }
    },
  );
}
