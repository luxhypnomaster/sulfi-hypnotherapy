import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../data/alchemist_diary_repository.dart';
import '../data/diary_repository.dart';
import '../data/library_repository.dart';
import '../data/module_catalog.dart';
import '../data/session_repository.dart';
import 'access_policy.dart';
import 'alchemist_diary_api.dart';
import 'alchemist_errors.dart';
import 'alchemist_work_queue.dart';
import 'capsule_service.dart';
import 'diary_controller.dart';
import 'diary_api.dart';
import 'diary_media_store.dart';
import 'library_service.dart';
import 'native_transfer_bridge.dart';
import 'session_controller.dart';

/// Only the Android JobService/dataSync Service starts this separate engine.
/// No Activity, player, microphone, picker, or Google interactive SDK is needed.
Future<void> runTransferWorker({DiaryRequest? controlledConnection}) async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = NativeTransferBridge.channel;
  Database? database;
  SessionController? controller;
  AlchemistWorkQueue? queue;
  String? epoch, owner;
  bool stopped = false, draining = false, wake = false;
  String? stopReason;
  String pauseReason() =>
      const ['OWNER_CHANGED', 'WAITING_NETWORK'].contains(stopReason)
      ? stopReason!
      : 'WAITING_POLICY';
  var observedDispatch = -1;
  Future<Map<String, dynamic>> lease() async {
    try {
      final m = await channel.invokeMapMethod<String, dynamic>('lease', {
        'epoch': epoch,
      });
      if (m == null || owner != null && m['ownerBinding'] != owner) {
        throw const FormatException('Authority changed');
      }
      final network = await channel.invokeMapMethod<String, dynamic>('network');
      if (m['networkPolicy'] == 'unmetered' && network?['metered'] == true) {
        throw const AlchemistFailure(
          'Ожидает безлимитную сеть.',
          0,
          'WAITING_POLICY',
          DiaryFailure.blocked,
          true,
        );
      }
      return m;
    } on AlchemistFailure {
      rethrow;
    } catch (_) {
      throw const AlchemistFailure(
        'Подтвердите исходный Google-аккаунт.',
        401,
        'WAITING_AUTH',
        DiaryFailure.authorization,
      );
    }
  }

  Future<void> controls() async {
    if (queue == null || owner == null) return;
    final actions =
        await channel.invokeListMethod<dynamic>('controls', {
          'ownerBinding': owner,
        }) ??
        [];
    for (final raw in actions) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['action'] != 'pause' && m['action'] != 'cancel') continue;
      final row = queue!.rows.where((r) => r['_name'] == m['name']).firstOrNull;
      if (row == null ||
          const ['complete', 'cancelled'].contains(row['_work']?['phase'])) {
        continue;
      }
      await queue.pause(m['name'], cancel: m['action'] == 'cancel');
    }
  }

  Future<void> drain() async {
    if (draining) {
      wake = true;
      return;
    }
    draining = true;
    try {
      do {
        wake = false;
        observedDispatch = (await lease())['dispatchSeq'] as int? ?? -1;
        await controls();
        await queue!.recoverNativeIntents();
        await queue!.runPending();
      } while (wake && !stopped);
    } finally {
      draining = false;
    }
  }

  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') {
      stopped = true;
      stopReason =
          (call.arguments as Map?)?['reason'] as String? ?? 'WAITING_POLICY';
      await queue?.pauseAll(reason: pauseReason());
    } else if (call.method == 'control') {
      final m = Map<String, dynamic>.from(call.arguments as Map);
      if (m['action'] == 'pause' || m['action'] == 'cancel') {
        await queue?.pause(m['name'], cancel: m['action'] == 'cancel');
      } else {
        wake = true;
      }
    } else if (call.method == 'wake') {
      wake = true;
    }
  });

  Timer? heartbeat;
  int? retryAfter;
  String completion = 'COMPLETED';
  try {
    // This hint grants no network authority; it only scopes a durable waiting
    // status when an expired/inaccessible lease fails before whoami.
    owner =
        (await channel.invokeMapMethod<String, dynamic>(
              'authorityHint',
            ))?['ownerBinding']
            as String?;
    final paths = await channel.invokeMapMethod<String, dynamic>('paths');
    final root = Directory(paths!['support'] as String);
    final path = p.join(root.path, 'library.sqlite');
    // Never first-create or migrate storage from a background callback.
    if (!await File(path).exists()) {
      throw const FormatException('Прежняя база недоступна');
    }
    database = await openAppDatabase(
      path,
      independentConnection: true,
      allowMigrations: false,
    );
    final version = Sqflite.firstIntValue(
      await database.rawQuery('PRAGMA user_version'),
    );
    if (version != 9) {
      throw const FormatException('Требуется обычное обновление приложения');
    }
    final authority = await lease();
    epoch = authority['epoch'];
    owner = authority['ownerBinding'];
    final policy = AccessPolicy(database: database);
    await policy.load();
    final repository = SqliteLibraryRepository(database);
    final library = LibraryService(
      repository: repository,
      policy: policy,
      directory: Directory(p.join(root.path, 'audio')),
      pick: () async => null,
      probe: (path) async {
        final ms = await channel.invokeMethod<int>('probeAudio', {
          'path': path,
        });
        return ms == null ? null : Duration(milliseconds: ms);
      },
    );
    final media = DiaryMediaStore(
      Directory(p.join(root.path, 'diary_media')),
      pick: (_) async => null,
      probe: library.probe,
    );
    Future<({int width, int height, int durationMs})> videoProbe(
      File file,
    ) async {
      final m = await channel.invokeMapMethod<String, dynamic>('probeVideo', {
        'path': file.path,
      });
      if (m == null ||
          m['width'] is! int ||
          m['height'] is! int ||
          m['durationMs'] is! int) {
        throw const FormatException('Видео не проверено');
      }
      return (
        width: m['width'] as int,
        height: m['height'] as int,
        durationMs: m['durationMs'] as int,
      );
    }

    final capsules = CapsuleService(
      database: database,
      library: library,
      diaryDirectory: media.directory,
      workspace: Directory(p.join(root.path, 'transfer_workspace18')),
      videoProbe: videoProbe,
      availableBytes: () async =>
          (await channel.invokeMethod<int>('freeBytes'))!,
    );
    final api = _WorkerDiaryApi(
      Uri.parse(authority['endpoint']),
      capsules: capsules,
      media: media,
      readLease: lease,
      connection: controlledConnection,
    );
    if (authority['scope'] != 'public') {
      await api.authenticateReader(authority['token']);
      await lease();
      if (api.readerScope != authority['scope'] ||
          api.author.ownerBinding != owner ||
          api.verifiedRole != authority['role']) {
        throw const AlchemistFailure(
          'Сервер не подтвердил владельца задачи.',
          401,
          'ACCOUNT_CHANGED',
        );
      }
      policy.applyVerifiedServerRole(api.verifiedRole);
    }
    final diary = DiaryController(
      AlchemistDiaryRepository(database, scope: () => api.readerScope),
      api: api,
      policy: policy,
      authorRepository: DiaryAuthorRepository(database),
      mediaStore: media,
    );
    controller = SessionController(
      repository: SqliteSessionRepository(database, policy),
      library: library,
      modules: ModuleCatalog(database, policy),
      diary: diary,
      capsules: capsules,
      backgroundWorker: true,
    );
    // reload, NOT initialize: never interrupt a user's active audio session.
    await controller.reload();
    queue = AlchemistWorkQueue(
      db: database,
      owner: () => owner,
      worker: true,
      externalStop: () => stopped,
      prepareTask: (name, row) async {
        await lease();
        if (name.startsWith('alchemist_read_sync_queue:') &&
            !const ['MASTER', 'CLIENT'].contains(api.verifiedRole)) {
          throw const AlchemistFailure(
            'Для синхронизации нужен исходный Google-аккаунт.',
            401,
            'WAITING_AUTH',
          );
        }
        if (!name.startsWith('alchemist_download:') &&
            !name.startsWith('alchemist_read_sync_queue:') &&
            (api.verifiedRole != 'MASTER' || policy.clientEdition)) {
          throw const AlchemistFailure(
            'Нет прав для отправки.',
            403,
            'ROLE_REQUIRED',
          );
        }
      },
      send: controller.sendCloudTask,
    );
    Future<void> notice() async {
      await queue?.refresh();
      final row = queue?.rows
          .where(
            (r) =>
                const ['preparing', 'running'].contains(r['_work']?['phase']),
          )
          .firstOrNull;
      if (row == null) return;
      final w = row['_work'] as Map;
      await channel.invokeMethod('progress', {
        'name': row['_name'],
        'title':
            row['card']?['title'] ??
            row['entry']?['title'] ??
            row['download']?['title'] ??
            'Передача Сульфи',
        'label': alchemistStageLabel(w['stage']),
        'bytes': w['bytes'],
        'totalBytes': w['totalBytes'],
      });
    }

    heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(notice().catchError((Object _) {}));
    });
    if (stopped) {
      await queue.pauseAll(reason: pauseReason());
    }
    await drain();
    await queue.refresh();
    final waiting = queue.rows.where(
      (r) =>
          r['_work']?['executor'] == 'android18' &&
          r['_work']?['autoResume'] == true &&
          (const [
                'queued',
                'running',
                'preparing',
                'waiting_network',
                'waiting_policy',
              ].contains(r['_work']?['phase']) ||
              r['_work']?['phase'] == 'paused' &&
                  const [
                    'WAITING_POLICY',
                    'WAITING_NETWORK',
                  ].contains(r['_work']?['pauseReason'])),
    );
    if (waiting.isNotEmpty && stopReason != 'OWNER_CHANGED') {
      retryAfter = waiting
          .map(
            (r) =>
                ((r['_work']?['retryAtMs'] as int? ?? 0) -
                        DateTime.now().millisecondsSinceEpoch)
                    .clamp(30000, 900000),
          )
          .reduce((a, b) => a < b ? a : b);
    }
    if (queue.rows.any((r) => r['_work']?['phase'] == 'waiting_auth')) {
      completion = 'WAITING_AUTH';
    } else if (queue.rows.any(
      (r) => alchemistCanonicalState(r['_work']) == 'WAITING_NETWORK',
    )) {
      completion = 'WAITING_NETWORK';
    } else if (queue.rows.any(
      (r) => alchemistCanonicalState(r['_work']) == 'WAITING_POLICY',
    )) {
      completion = 'WAITING_POLICY';
    }
  } catch (e) {
    completion = e is AlchemistFailure && e.status == 401
        ? 'WAITING_AUTH'
        : 'WAITING_POLICY';
    final failure = AlchemistFailure.from(e);
    if (failure.retryable) retryAfter = 60000;
    if (queue == null && database != null && owner != null) {
      final waitingQueue = AlchemistWorkQueue(
        db: database,
        owner: () => owner,
        worker: true,
        send: (_, _, _, _, _) async {},
      );
      try {
        await waitingQueue.refresh();
        // Failed startup must never rewrite old USER_PAUSED or another owner.
        for (final row in waitingQueue.rows) {
          final w = row['_work'] as Map;
          if (w['executor'] == 'android18' &&
              w['autoResume'] == true &&
              const ['queued', 'preparing', 'running'].contains(w['phase'])) {
            await waitingQueue.pause(row['_name'], reason: completion);
          }
        }
      } finally {
        waitingQueue.dispose();
      }
    }
    // No personal payload/error text/credential is logged. Existing files stay.
  } finally {
    heartbeat?.cancel();
    queue?.dispose();
    controller?.dispose();
    await database?.close();
    channel.setMethodCallHandler(null);
    await channel.invokeMethod('done', {
      'state': completion,
      'retryAfterMs': retryAfter,
      'observedDispatch': observedDispatch,
      'startupFailure': queue == null,
    });
  }
}

class _WorkerDiaryApi extends AlchemistDiaryApi {
  _WorkerDiaryApi(
    super.base, {
    required super.capsules,
    required super.media,
    required this.readLease,
    super.connection,
  });
  final Future<Map<String, dynamic>> Function() readLease;
  String? _last;
  @override
  Future<String?> verifiedIdentityToken() async {
    final lease = await readLease();
    final token = lease['token'] as String?;
    if (lease['scope'] == 'public') return null;
    if (token == null) {
      throw const AlchemistFailure('Нужен Google-вход.', 401, 'WAITING_AUTH');
    }
    if (_last != token) {
      await super.authenticateReader(token);
      _last = token;
    }
    return token;
  }

  @override
  Future<bool> restoreIdentity() async {
    await verifiedIdentityToken();
    return readerAuthenticated;
  }
}
