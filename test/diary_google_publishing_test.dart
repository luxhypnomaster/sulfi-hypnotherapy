import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sulfi_hypnotherapy/data/app_database.dart';
import 'package:sulfi_hypnotherapy/data/diary_repository.dart';
import 'package:sulfi_hypnotherapy/models/diary_entry.dart';
import 'package:sulfi_hypnotherapy/services/apps_script_diary_transport.dart';
import 'package:sulfi_hypnotherapy/services/diary_api.dart';
import 'package:sulfi_hypnotherapy/services/diary_controller.dart';
import 'package:sulfi_hypnotherapy/services/diary_identity.dart';
import 'package:sulfi_hypnotherapy/ui/diary_screen.dart';

class FakeIdentity implements DiaryIdentity {
  String email = 'luxhypnomaster@gmail.com';
  int signIns = 0, signOuts = 0;
  Completer<DiaryIdentityResult>? pending;
  @override
  Future<DiaryIdentityResult> signIn() async {
    signIns++;
    return pending?.future ??
        DiaryIdentityResult(email: email, idToken: 'valid-sdk-identity');
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

DiaryEntry draft(
  String id, {
  int version = 0,
  String body = 'Приватный текст',
}) => DiaryEntry(
  id: id,
  message: 'Послание',
  body: body,
  version: version,
  createdAt: DateTime.utc(2026, 11, 4),
  updatedAt: DateTime.utc(2026, 11, 4),
);

class SpyAuthorRepository extends DiaryAuthorRepository {
  SpyAuthorRepository(super.database);
  final writes = <DiaryEntry>[];
  @override
  Future<void> save(DiaryEntry entry) {
    writes.add(entry);
    return super.save(entry);
  }
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late Directory dir;
  late FakeIdentity identity;
  late DiaryController controller;
  late Map<String, DiaryEntry> remote;
  bool offline = false;
  Completer<void>? cloudGate, cloudStarted;
  Future<DiaryResponse> server(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) async {
    if (offline) throw const SocketException('offline');
    if (uri.path.endsWith('/public/entries')) {
      return const DiaryResponse(
        200,
        '{"entries":[],"removedIds":[],"revision":"0","nextPage":null}',
      );
    }
    if (headers['Authorization'] != 'Bearer valid-sdk-identity') {
      return const DiaryResponse(403, '{}');
    }
    if (uri.path.endsWith('/author/me')) {
      return DiaryResponse(
        200,
        jsonEncode({
          'canPublish': true,
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        }),
      );
    }
    if (method == 'GET') {
      return DiaryResponse(
        200,
        jsonEncode({
          'entries': remote.values.map((e) => e.toMap()).toList(),
          'nextPage': null,
        }),
      );
    }
    cloudStarted?.complete();
    await cloudGate?.future;
    final input = jsonDecode(body!) as Map<String, dynamic>;
    final entry = DiaryEntry.fromMap(input['entry'] as Map<String, dynamic>);
    if ((remote[entry.id]?.version ?? 0) != input['expectedVersion']) {
      return const DiaryResponse(409, '{}');
    }
    final saved = entry.copyWith(version: entry.version + 1);
    remote[entry.id] = saved;
    return DiaryResponse(200, jsonEncode({'entry': saved.toMap()}));
  }

  setUp(() async {
    offline = false;
    cloudGate = null;
    cloudStarted = null;
    remote = {};
    identity = FakeIdentity();
    dir = await Directory.systemTemp.createTemp('sulfi_google_test');
    db = await openAppDatabase(
      '${dir.path}/library.sqlite',
      factory: databaseFactoryFfi,
    );
    controller = DiaryController(
      DiaryRepository(db),
      authorRepository: DiaryAuthorRepository(db),
      identity: identity,
      api: DiaryApi(
        Uri.parse('https://diary.example.test/v1'),
        request: server,
      ),
    );
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'ordinary startup never signs in or exposes persisted private drafts',
    () async {
      await DiaryAuthorRepository(db).save(draft('private'));
      await controller.load();
      await controller.sync();
      expect(identity.signIns, 0);
      expect(controller.authorWorkspace, false);
      expect(controller.drafts, isEmpty);
      await expectLater(
        controller.saveDraft(draft('forbidden')),
        throwsA(isA<DiaryApiException>()),
      );
      await expectLater(
        controller.authenticate('manually-copied-token'),
        throwsA(isA<DiaryApiException>()),
      );
    },
  );
  test('Google owner sign-in unlocks existing drafts and server permission; logout hides without deletion', () async {
    await DiaryAuthorRepository(db).save(draft('private'));
    await controller.signInAuthor();
    expect(controller.authorWorkspace, true);
    expect(controller.authenticated, true);
    expect(controller.drafts.single.id, 'private');
    await controller.logout();
    expect(controller.authorWorkspace, false);
    expect(controller.authenticated, false);
    expect(controller.drafts, isEmpty);
    expect((await DiaryAuthorRepository(db).entries()).length, 1);
  });
  test(
    'another Google account does not unlock author data or publish',
    () async {
      identity.email = 'reader@example.test';
      await expectLater(
        controller.signInAuthor(),
        throwsA(isA<DiaryApiException>()),
      );
      expect(controller.authorWorkspace, false);
      expect(identity.signOuts, 1);
      await expectLater(
        controller.publish(draft('a'), published: true),
        throwsA(isA<DiaryApiException>()),
      );
    },
  );
  test('offline server preserves verified local author workspace but grants no cloud permission', () async {
    offline = true;
    await controller.signInAuthor();
    await controller.saveDraft(draft('offline'));
    expect(controller.authorWorkspace, true);
    expect(controller.authenticated, false);
    expect(controller.drafts.single.id, 'offline');
    expect(controller.error, isNotNull);
  });
  test(
    'late Google result after logout cannot reopen private workspace',
    () async {
      identity.pending = Completer();
      final operation = controller.signInAuthor();
      await controller.logout();
      identity.pending!.complete(
        const DiaryIdentityResult(
          email: 'luxhypnomaster@gmail.com',
          idToken: 'valid-sdk-identity',
        ),
      );
      await operation;
      expect(controller.authorWorkspace, false);
      expect(controller.authenticated, false);
    },
  );
  test('cloud draft backup is explicit and versioned; restore does not overwrite local edits', () async {
    await controller.signInAuthor();
    await controller.saveDraft(draft('a'));
    await controller.saveToCloud(controller.drafts.single);
    expect(remote['a']!.version, 1);
    expect(controller.drafts.single.version, 1);
    await controller.saveDraft(
      draft('a', version: 1, body: 'Новые местные правки'),
    );
    remote['b'] = draft('b', version: 4, body: 'Текст с другого телефона');
    expect(await controller.restoreFromCloud(), 1);
    expect(
      controller.drafts.firstWhere((e) => e.id == 'a').body,
      'Новые местные правки',
    );
    expect(controller.drafts.firstWhere((e) => e.id == 'b').version, 4);
    expect(await DiaryRepository(db).published(), isEmpty);
  });
  test(
    'cloud conflict never replaces the local draft or reports success',
    () async {
      await controller.signInAuthor();
      await controller.saveDraft(draft('a'));
      remote['a'] = draft('a', version: 2, body: 'Другая версия');
      await expectLater(
        controller.saveToCloud(controller.drafts.single),
        throwsA(isA<DiaryApiException>()),
      );
      expect(controller.drafts.single.version, 0);
      expect(controller.drafts.single.body, 'Приватный текст');
    },
  );
  test(
    'unconfigured Google client fails before invoking the platform SDK',
    () async {
      await expectLater(
        GoogleDiaryIdentity(serverClientId: '').signIn(),
        throwsA(isA<DiaryApiException>()),
      );
    },
  );
  testWidgets(
    'one app shows Google author login but no editor or raw-token field to a reader',
    (tester) async {
      await tester.runAsync(() async {
        controller.dispose();
        controller = DiaryController(
          DiaryRepository(db),
          authorRepository: DiaryAuthorRepository(db),
          identity: identity,
        );
        await DiaryAuthorRepository(db).save(draft('private'));
        await controller.load();
      });
      await tester.pumpWidget(
        MaterialApp(home: DiaryScreen(diary: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Войти как автор через Google'), findsOneWidget);
      expect(find.text('Новая запись'), findsNothing);
      expect(find.text('Приватный текст'), findsNothing);
      expect(find.text('Временный токен от сервера'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Войти как автор через Google'));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });
      await tester.pumpAndSettle();
      expect(find.text('Новая запись'), findsOneWidget);
      await tester.tap(find.text('Новая запись'));
      await tester.pumpAndSettle();
      expect(find.byType(DiaryEditor), findsOneWidget);
      expect(find.text('Временный токен от сервера'), findsNothing);
      expect(find.text('Предпросмотр'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'backgrounding during cloud save cannot overwrite its confirmed version with stale autosave',
    (tester) async {
      late SpyAuthorRepository author;
      await tester.runAsync(() async {
        controller.dispose();
        author = SpyAuthorRepository(db);
        controller = DiaryController(
          DiaryRepository(db),
          authorRepository: author,
          identity: identity,
          api: DiaryApi(
            Uri.parse('https://diary.example.test/v1'),
            request: server,
          ),
        );
        await controller.signInAuthor();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: DiaryEditor(diary: controller, entry: draft('background')),
        ),
      );
      await tester.pumpAndSettle();
      cloudGate = Completer();
      cloudStarted = Completer();
      await tester.tap(find.text('Сохранить на Диск'));
      for (var i = 0; i < 50 && !cloudStarted!.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(cloudStarted!.isCompleted, true);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(
        author.writes.length,
        1,
        reason: 'the pre-upload local save is enough while fields are disabled',
      );
      cloudGate!.complete();
      for (var i = 0; i < 50 && controller.drafts.single.version != 1; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(controller.drafts.single.version, 1);
      expect(author.writes.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  group('Apps Script transport', () {
    final base = Uri.parse(
      'https://script.google.com/macros/s/DEPLOYMENT_ID/exec',
    );
    for (final invalid in [
      'https://script.google.com/d/project/edit',
      'http://script.google.com/macros/s/id/exec',
      'https://script.google.com/macros/s/id/dev',
      'https://script.google.com.evil.test/macros/s/id/exec',
    ]) {
      test(
        'rejects $invalid',
        () => expect(
          () => AppsScriptDiaryTransport(Uri.parse(invalid)),
          throwsA(isA<DiaryApiException>()),
        ),
      );
    }
    test('author operations use POST envelope; redirected content is fetched without credentials', () async {
      var calls = 0;
      final transport = AppsScriptDiaryTransport(
        base,
        connection: (method, uri, headers, body) async {
          calls++;
          expect(headers.containsKey('Authorization'), false);
          expect(uri.query.contains('sdk-token'), false);
          if (calls == 1) {
            expect(method, 'POST');
            expect(uri, base);
            final envelope = jsonDecode(body!);
            expect(envelope['method'], 'GET');
            expect(envelope['route'], 'author/me');
            expect(envelope['token'], 'sdk-token');
            return const DiaryResponse(
              302,
              '',
              headers: {
                'location': 'https://script.googleusercontent.com/macros/echo?content=opaque',
              },
            );
          }
          expect(method, 'GET');
          expect(body, isNull);
          return DiaryResponse(
            200,
            jsonEncode({
              'status': 200,
              'data': {
                'canPublish': true,
                'expiresAt': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 30))
                    .toIso8601String(),
              },
            }),
          );
        },
      );
      final session = await DiaryApi(
        base,
        request: transport.request,
      ).authenticate('sdk-token');
      expect(session.valid, true);
      expect(calls, 2);
    });
    test(
      'anonymous feed has no token and logical 403 remains a denied operation',
      () async {
        final transport = AppsScriptDiaryTransport(
          base,
          connection: (method, uri, headers, body) async {
            expect(method, 'GET');
            expect(body, isNull);
            expect(headers.containsKey('Authorization'), false);
            return const DiaryResponse(200, '{"status":403,"data":{}}');
          },
        );
        await expectLater(
          DiaryApi(base, request: transport.request).feed(),
          throwsA(isA<DiaryApiException>()),
        );
      },
    );
    for (final target in [
      'https://evil.test/collect',
      'https://accounts.google.com/login',
      'http://script.googleusercontent.com/echo',
      'https://user@script.googleusercontent.com/echo',
    ]) {
      test('never follows redirect to $target', () async {
        var calls = 0;
        final transport = AppsScriptDiaryTransport(
          base,
          connection: (m, u, h, b) async {
            calls++;
            return DiaryResponse(302, '', headers: {'location': target});
          },
        );
        await expectLater(
          DiaryApi(base, request: transport.request).authenticate('sdk-token'),
          throwsA(isA<DiaryApiException>()),
        );
        expect(calls, 1);
      });
    }
    test('redirect loops are bounded', () async {
      var calls = 0;
      final transport = AppsScriptDiaryTransport(
        base,
        connection: (m, u, h, b) async {
          calls++;
          return const DiaryResponse(
            302,
            '',
            headers: {
              'location': 'https://script.googleusercontent.com/macros/echo',
            },
          );
        },
      );
      await expectLater(
        DiaryApi(base, request: transport.request).feed(),
        throwsA(isA<DiaryApiException>()),
      );
      expect(calls, 4);
    });
  });
}
