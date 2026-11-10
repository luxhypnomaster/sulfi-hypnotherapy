import 'package:flutter/material.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/ui/diary_reader.dart';

import 'support/task15_harness.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/data/alchemist_diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/diary_read_state.dart';

import 'support/task15_fixture.dart';

class ScopeApi16 extends DiaryApi {
  ScopeApi16() : super(Uri.parse('https://scope.example'));
  String scope = 'google:one';
  @override
  String get readerScope => scope;
  @override
  void clearSession() {
    scope = 'public';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'logout immediately hides an already open restricted reader without deleting the cached record',
    (t) async {
      final f = (await t.runAsync(() => Fixture15.open(client: true)))!;
      final api = ScopeApi16();
      // Bind this explicit fixture identity; no live sign-in is claimed.
      final repo = AlchemistDiaryRepository(f.db, scope: () => api.readerScope);
      final reader = DiaryController(repo, api: api);
      try {
        final now = DateTime.utc(2026),
            entry = DiaryEntry(
              id: 'private-reader',
              title: 'Личная запись',
              message: 'Послание',
              body: 'Личное сообщение',
              createdAt: now,
              updatedAt: now,
              publishedAt: now,
              status: DiaryStatus.published,
              extra: {'_alchemistScope': 'google:one'},
            );
        await t.runAsync(() => repo.cache([entry], {}, 'one'));
        await t.runAsync(reader.load);
        await show15(t, f, DiaryReader(entry: entry, diary: reader));
        await io15(t);
        expect(find.text('Личное сообщение'), findsOneWidget);
        await t.runAsync(reader.logout);
        await io15(t);
        expect(find.text('Личное сообщение'), findsNothing);
        expect(
          find.text('Войдите в аккаунт, которому доступна эта запись.'),
          findsOneWidget,
        );
        expect(
          (await t.runAsync(
            () => f.db.query(
              'app_settings',
              where: 'name LIKE ?',
              whereArgs: ['alchemist_private_entry:%'],
            ),
          ))!.length,
          1,
        );
        await t.pumpWidget(const SizedBox());
      } finally {
        reader.dispose();
        await t.runAsync(f.close);
      }
    },
  );
  test('private diary caches and read status stay per verified account; logout preserves but hides private data', () async {
    final f = await Fixture15.open();
    String scope = 'google:one';
    try {
      final repo = AlchemistDiaryRepository(f.db, scope: () => scope),
          now = DateTime.utc(2026);
      DiaryEntry entry(String id, String owner) => DiaryEntry(
        id: id,
        title: id,
        message: 'message',
        body: 'body',
        createdAt: now,
        updatedAt: now,
        publishedAt: now,
        status: DiaryStatus.published,
        version: 1,
        extra: {'_alchemistScope': owner},
      );
      final public = entry('public', 'public'),
          private = entry('private', 'google:one');
      await repo.cache([public, private], {}, 'one');
      expect(
        (await repo.published()).map((e) => e.id),
        containsAll(['public', 'private']),
      );
      final reads = DiaryReadStore(f.db, readerId: scope);
      await reads.load();
      await reads.progress(private, textEnd: true, page: 3);
      expect(reads.isRead(private), isTrue);
      scope = 'google:two';
      await reads.switchReader(scope);
      expect((await repo.published()).map((e) => e.id), ['public']);
      expect(reads.isRead(private), isFalse);
      await repo.cache([entry('other', 'google:two')], {}, 'two');
      scope = 'public';
      expect((await repo.published()).map((e) => e.id), ['public']);
      scope = 'google:one';
      await reads.switchReader(scope);
      expect(
        (await repo.published()).map((e) => e.id),
        containsAll(['public', 'private']),
      );
      expect(reads.state(private)['page'], 3);
      expect(await repo.revision(), 'one');
      expect(
        (await f.db.query(
          'app_settings',
          where: 'name LIKE ?',
          whereArgs: ['alchemist_private_entry:%'],
        )).length,
        2,
      );
    } finally {
      await f.close();
    }
  });
}
