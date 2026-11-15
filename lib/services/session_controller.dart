import 'package:crypto/crypto.dart';

import 'native_transfer_bridge.dart';
import 'alchemist_install.dart';

import 'dart:io';

import 'package:path/path.dart' as p;

import 'diary_api.dart';
import 'alchemist_announcement.dart';
import 'alchemist_work_queue.dart';
import 'alchemist_diary_api.dart';
import 'alchemist_identity_session.dart';
import 'alchemist_catalog.dart';
import 'alchemist_api.dart';

import 'dart:convert';
import 'dart:async';

import 'diary_controller.dart';

import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../data/module_catalog.dart';
import '../models/modular_plan.dart';
import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../models/execution_identity.dart';
import '../models/composition_identity.dart';
import '../models/content_revision.dart';
import '../data/content_revision_store.dart';
import 'library_service.dart';
import 'capsule_service.dart';
import 'access_policy.dart';
import 'history_attachments.dart';
import 'preview_player.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required this.repository,
    required this.library,
    ModuleCatalog? modules,
    this.diary,
    this.capsules,
    this.historyAttachments,
    this.preview,
    this.backgroundWorker = false,
  }) : modules = modules ?? ModuleCatalog(null, library.policy) {
    library.policy.addListener(_notify);
    if (!backgroundWorker &&
        capsules != null &&
        NativeTransferBridge.available) {
      diary?.beforeAccountLogout = NativeTransferBridge.revoke;
      final api = diary?.api;
      if (api is AlchemistDiaryApi) {
        api.enqueueReaderSync = _enqueueReaderSync;
        diary?.enqueueCloudOperation = (entry, published) async {
          await ensurePublicationIdentity();
          await api.enqueueDurablePublication(entry, published: published);
          await cloudQueue.enqueue('alchemist_diary_queue:${entry.id}');
        };
        diary?.enqueueCloudMutation = (entry, action) async {
          await ensurePublicationIdentity();
          await api.enqueueDurableMutation(entry, action);
          await cloudQueue.enqueue('alchemist_diary_queue:${entry.id}');
        };
        api.downloadInBackground = (descriptor, target) =>
            downloadAsset(descriptor, target: target);
      }
    }
    if (diary != null && diary!.onAccountLogout == null) {
      diary!.onAccountLogout = () {
        _catalogIdentity?.invalidate();
        _cloudQueue?.invalidateOwner();
        if (_cloudQueue != null) {
          unawaited(_cloudQueue!.pauseAll(reason: 'OWNER_CHANGED'));
        }
        if (preview != null) unawaited(preview!.stop());
      };
    }
  }
  final bool backgroundWorker;
  bool get nativeTransfers =>
      !backgroundWorker && NativeTransferBridge.available;
  AccessPolicy get policy => library.policy;
  SessionController? _editorSource;
  String? _editorBaseline;
  bool get isEditor => _editorSource != null;
  static String _draftToken(CurrentSessionDraft d) =>
      jsonEncode(d.toMap()..remove('updatedAt'));
  bool get hasEditorChanges =>
      isEditor && _draftToken(draft) != _editorBaseline;

  /// Isolated working copy. It shares the catalogue/library, never the current
  /// configuration or history writes. Opening an editor never interrupts a run.
  Future<SessionController> beginEditing() async {
    await flush();
    final editor = SessionController(
      repository: repository,
      library: library,
      modules: modules,
      diary: diary,
      historyAttachments: historyAttachments,
    );
    editor._editorSource = this;
    editor.draft = CurrentSessionDraft.fromMap(draft.toMap());
    editor._editorBaseline = _draftToken(draft);
    editor.assets = List.of(assets);
    editor.templates = List.of(templates);
    editor._templateRevisions.addAll(_templateRevisions);
    editor.runs = List.of(runs);
    editor.nextNumber = nextNumber;
    return editor;
  }

  Future<void> applyEditor() async {
    if (!isEditor) throw StateError('Не открыт редактор');
    await flush();
    final snapshot = CurrentSessionDraft.fromMap(draft.toMap());
    final expected = _editorBaseline;
    await _editorSource!._edit((current) {
      if (_draftToken(current) != expected) {
        throw const LibraryException(
          'Текущая конфигурация изменилась. Закройте редактор без применения и откройте его снова.',
        );
      }
      return snapshot;
    });
    _editorBaseline = _draftToken(snapshot);
    _notify();
  }

  final ModuleCatalog modules;
  final CapsuleService? capsules;
  final HistoryAttachments? historyAttachments;
  final PreviewPlayer? preview;
  final DiaryController? diary;
  final SessionRepository repository;
  AlchemistCatalog? _catalog;
  AlchemistIdentitySession? _catalogIdentity;
  Future<void> signInAlchemistReader() async {
    if (diary?.api?.supportsServerIdentity ?? false) {
      await diary!.signInAuthor();
      notifyListeners();
      return;
    }
    final identity = diary?.identity;
    if (identity == null) {
      throw const FormatException('Вход Google не настроен');
    }
    final token = await (_catalogIdentity ??= AlchemistIdentitySession(
      identity,
    )).token();
    await diary!.api?.authenticateReader(token);
    await diary!.load();
    await diary!.sync();
  }

  Future<void> signOutAlchemist() async {
    await diary?.logout();
    _catalogIdentity?.invalidate();
  }

  AlchemistApi alchemistApi({bool authenticated = true}) {
    final endpoint = (diary?.api?.supportsServerIdentity ?? false)
        ? diary!.api!.base.toString()
        : const String.fromEnvironment('SULFI_ALCHEMIST_API');
    if (endpoint.isEmpty) {
      throw const FormatException(
        'Облачный сервер ещё не подключён в этой сборке. Локальные данные доступны.',
      );
    }
    return AlchemistApi(
      Uri.parse(endpoint),
      connection: diary?.api is AlchemistDiaryApi
          ? (diary!.api as AlchemistDiaryApi).connection
          : null,
      identityScope: () => diary?.api?.readerScope ?? 'public',
      identityEpoch: () => diary?.api?.identityGeneration ?? 0,
      onUnauthorized: diary?.api?.refreshRejectedIdentity,
      onAuthenticationFailure: diary?.api?.rejectIdentity,
      credential: !authenticated
          ? () async {
              final api = diary?.api;
              if (api?.supportsServerIdentity == true &&
                  (api!.readerAuthenticated || api.readerScope != 'public')) {
                return api.verifiedIdentityToken();
              }
              return null;
            }
          : () async {
              if (diary?.api?.supportsServerIdentity ?? false) {
                return diary!.api!.verifiedIdentityToken();
              }
              final identity = diary?.identity;
              if (identity == null) {
                throw const FormatException('Вход Google ещё не настроен');
              }
              return (_catalogIdentity ??= AlchemistIdentitySession(
                identity,
              )).token();
            },
    );
  }

  AlchemistCatalog get catalog => _catalog ??= AlchemistCatalog(
    this,
    api:
        (diary?.api?.supportsServerIdentity ?? false) ||
            const String.fromEnvironment('SULFI_ALCHEMIST_API').isNotEmpty
        ? alchemistApi()
        : null,
  );
  Future<void> ensurePublicationIdentity() async {
    if (diary?.api?.supportsServerIdentity ?? false) {
      await diary!.restoreSignIn();
      await diary!.api!.verifiedIdentityToken();
      policy.applyVerifiedServerRole(diary!.api!.verifiedRole);
      if (!diary!.api!.readerAuthenticated ||
          diary!.api!.verifiedRole != 'MASTER' ||
          policy.clientEdition) {
        throw const DiaryApiException(
          'Сервер не разрешил публикацию для этого аккаунта.',
          DiaryFailure.blocked,
        );
      }
    }
  }

  AlchemistWorkQueue? _cloudQueue;
  String? get transferOwner =>
      catalog.api?.ownerBinding ?? (catalog.api == null ? null : 'public');
  Future<void> _authorizeTransfer() async {
    final rows = await capsules!.database.query(
      'app_settings',
      where: 'name=?',
      whereArgs: ['transfer_network_policy18'],
    );
    final networkPolicy = rows.isEmpty ? 'any' : rows.single['value'] as String;
    await NativeTransferBridge.authorize(
      catalog.api!,
      diary?.api,
      networkPolicy: networkPolicy,
    );
  }

  Future<void> applyTransferNetworkPolicy() async {
    if (!nativeTransfers) return;
    await _authorizeTransfer();
    await cloudQueue.refresh();
    if (cloudQueue.rows.any(
      (r) =>
          r['_work']?['executor'] == 'android18' &&
          const [
            'queued',
            'running',
            'preparing',
            'waiting_network',
            'waiting_policy',
          ].contains(r['_work']?['phase']),
    )) {
      await NativeTransferBridge.start();
    }
  }

  AlchemistWorkQueue get cloudQueue => _cloudQueue ??= AlchemistWorkQueue(
    db: capsules!.database,
    owner: () => transferOwner,
    prepareTask: prepareCloudTask,
    dispatch: nativeTransfers ? NativeTransferBridge.start : null,
    canAutoRecover: nativeTransfers
        ? () async {
            final status = await NativeTransferBridge.channel
                .invokeMapMethod<String, dynamic>('status');
            return status == null || status['needsUserStart'] != true;
          }
        : null,
    nativeControl: nativeTransfers
        ? (name, action) async {
            if (action == 'resume') await _authorizeTransfer();
            await NativeTransferBridge.control(name, action, transferOwner!);
          }
        : null,
    send: sendCloudTask,
    worker: backgroundWorker,
  );
  Future<void> prepareCloudTask(String name, Map<String, dynamic> row) async {
    if (name.startsWith('alchemist_download:') ||
        name.startsWith('alchemist_read_sync_queue:')) {
      return;
    }
    await ensurePublicationIdentity();
  }

  Future<void> sendCloudTask(
    String name,
    Map<String, dynamic> value,
    bool Function() stop,
    void Function(String) stage,
    void Function(int, int) progress,
  ) async {
    if (name.startsWith('alchemist_read_sync_queue:')) {
      final parameters = <String, dynamic>{
        for (final key in ['requestId', 'ifMatch', 'entries']) key: value[key],
      };
      final receipt = await catalog.api!.call('sync.push', parameters);
      await capsules!.database.transaction((tx) async {
        final rows = await tx.query(
          'app_settings',
          where: 'name=?',
          whereArgs: [name],
        );
        if (rows.isEmpty) return;
        final record = Map<String, dynamic>.from(
          jsonDecode(rows.single['value'] as String),
        );
        if (record['ownerBinding'] != transferOwner ||
            record['requestId'] != value['requestId']) {
          throw const FormatException('Очередь синхронизации изменилась');
        }
        record['_work'] = {
          ...Map<String, dynamic>.from(record['_work']),
          'receipt': receipt,
        };
        await tx.update(
          'app_settings',
          {'value': jsonEncode(record)},
          where: 'name=?',
          whereArgs: [name],
        );
      });
      stage('reader_synced');
      return;
    }
    if (name.startsWith('alchemist_download:')) {
      final d = Map<String, dynamic>.from(value['download']);
      stage('transferring');
      final install = AlchemistInstall(capsules!, catalog.api!);
      if (d['kind'] == 'install') {
        await install.install(
          Map<String, dynamic>.from(d['card']),
          interrupted: stop,
          progress: progress,
        );
      } else if (d['kind'] == 'media') {
        final descriptor = Map<String, dynamic>.from(d['descriptor']);
        final f = await install.downloadAsset(
          descriptor,
          interrupted: stop,
          progress: progress,
        );
        if (stop()) throw const FormatException('Передача приостановлена');
        if (d['target'] case final String target) {
          final allowed = p.join(library.directory.parent.path, 'diary_media');
          if (!p.isWithin(allowed, target)) {
            throw const FormatException('Путь медиа вне приватного хранилища');
          }
          final destination = File(target);
          await destination.parent.create(recursive: true);
          if (await destination.exists()) {
            if ((await sha256.bind(destination.openRead()).first).toString() !=
                descriptor['sha256']) {
              throw const FormatException(
                'Прежний файл не заменён: конфликт контрольной суммы',
              );
            }
          } else {
            final tmp = File('$target.transfer18.part');
            await f.copy(tmp.path);
            if (stop()) throw const FormatException('Передача приостановлена');
            await tmp.rename(target);
          }
        }
        d['localPath'] = f.path;
        await capsules!.database.transaction((tx) async {
          final current = await tx.query(
            'app_settings',
            where: 'name=?',
            whereArgs: [name],
          );
          if (current.isEmpty) {
            throw const FormatException('Задача отсутствует');
          }
          final record = Map<String, dynamic>.from(
            jsonDecode(current.single['value'] as String),
          );
          if (record['ownerBinding'] != transferOwner) {
            throw const FormatException('Аккаунт изменился');
          }
          record['download'] = d;
          await tx.update(
            'app_settings',
            {'value': jsonEncode(record)},
            where: 'name=?',
            whereArgs: [name],
          );
        });
      } else {
        throw const FormatException('Неизвестный вид загрузки');
      }
      stage('installed');
      return;
    }
    if (name.startsWith('alchemist_card:')) {
      if (value['requestedAction'] case final String action) {
        await catalog.transition(value, action);
        return;
      }
      await catalog.publish(
        value,
        interrupted: stop,
        onStage: stage,
        progress: progress,
      );
    } else {
      final api = diary?.api;
      if (api is! AlchemistDiaryApi) {
        throw const FormatException('Сервер не подключён');
      }
      final previous = api.beforePublication;
      api.beforePublication = (entry) => commitAnnouncementDependency(
        catalog,
        entry,
        interrupted: stop,
        onStage: stage,
        progress: progress,
      );
      try {
        await api.sendQueued(
          name,
          interrupted: stop,
          onStage: stage,
          progress: progress,
        );
      } finally {
        api.beforePublication = previous;
      }
      await diary!.load();
    }
  }

  Future<void> _enqueueReaderSync(String name) async {
    final owner = transferOwner;
    if (owner == null || owner == 'public') return;
    await capsules!.database.transaction((tx) async {
      final rows = await tx.query(
        'app_settings',
        where: 'name=?',
        whereArgs: [name],
      );
      if (rows.isEmpty) return;
      final record = Map<String, dynamic>.from(
        jsonDecode(rows.single['value'] as String),
      );
      if (record['ownerBinding'] != null && record['ownerBinding'] != owner) {
        throw const FormatException('Другой владелец синхронизации');
      }
      record['ownerBinding'] = owner;
      record.putIfAbsent('_work', () => initialQueuedWork(record, owner));
      await tx.update(
        'app_settings',
        {'value': jsonEncode(record)},
        where: 'name=?',
        whereArgs: [name],
      );
    });
    await cloudQueue.enqueue(name);
  }

  Future<String> installInBackground(Map<String, dynamic> card) async {
    final name =
        'alchemist_download:$transferOwner:install:${card['catalogItemId']}:${card['immutableRevisionId']}';
    await cloudQueue.enqueueDownload(name, {
      'kind': 'install',
      'card': card,
      'title': card['card']?['title'],
    });
    return name;
  }

  Future<File> downloadAsset(
    Map<String, dynamic> descriptor, {
    String? target,
  }) async {
    if (!nativeTransfers) {
      return AlchemistInstall(
        capsules!,
        catalog.api!,
      ).downloadAsset(descriptor);
    }
    final name =
        'alchemist_download:$transferOwner:media:${descriptor['assetRevisionId']}:${descriptor['sha256']}:${contentDigest({'target': target})}';
    await cloudQueue.enqueueDownload(name, {
      'kind': 'media',
      'descriptor': descriptor,
      'target': target,
      'title': 'Медиа дневника или обложка',
    });
    final until = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(until)) {
      await cloudQueue.refresh();
      final row = cloudQueue.rows.where((r) => r['_name'] == name).firstOrNull;
      if (row?['_work']?['phase'] == 'complete' &&
          row?['download']?['localPath'] is String) {
        return File(row!['download']['localPath']);
      }
      if (const [
        'failed',
        'failed_permanent',
        'cancelled',
        'waiting_auth',
      ].contains(row?['_work']?['phase'])) {
        throw const FormatException(
          'Откройте очередь передач: загрузка требует внимания',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    throw const FormatException(
      'Загрузка продолжается в Android. Состояние доступно в очереди передач.',
    );
  }

  final LibraryService library;
  CurrentSessionDraft draft = CurrentSessionDraft(
    plan: SessionPlan(steps: const []),
    updatedAt: DateTime.now().toUtc(),
  );
  List<SessionTemplate> templates = [];
  List<AudioAsset> assets = [];
  List<SessionRun> runs = [];
  int nextNumber = 1;
  bool saving = false;
  String? saveError;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  AudioAsset? asset(String? id) => assets.where((a) => a.id == id).firstOrNull;
  SessionTemplate? get baseTemplate =>
      templates.where((t) => t.id == draft.baseTemplateId).firstOrNull;

  // Audio length is measured library metadata, not an editable trim. A cache
  // refresh must not turn every occurrence into a composition edit.
  int? _comparisonAudioDuration(SessionStep step) =>
      asset(step.audioAssetId)?.durationMs ?? step.durationMs;
  bool moduleDiffersFromSource(PhaseChild instance) {
    if (!instance.isModule || instance.definitionVersion == null) return false;
    final source = modules.source(
      instance.definitionId!,
      instance.definitionVersion!,
      revision: instance.sourceRevision,
    );
    return source != null &&
        stepsComposition(
              source.items,
              audioDuration: _comparisonAudioDuration,
            ) !=
            stepsComposition(
              instance.items,
              audioDuration: _comparisonAudioDuration,
            );
  }

  final List<SessionTemplate> _templateRevisions = [];
  bool get templateDiffersFromSource {
    final matches = [..._templateRevisions, ...templates]
        .where(
          (t) =>
              t.id == draft.baseTemplateId &&
              t.version == draft.baseTemplateVersion,
        )
        .toList();
    final source =
        matches.isNotEmpty &&
            matches
                    .map(
                      (t) => planComposition(
                        t.plan,
                        audioDuration: _comparisonAudioDuration,
                      ),
                    )
                    .toSet()
                    .length ==
                1
        ? matches.first
        : null;
    return source != null &&
        draft.baseTemplateVersion == source.version &&
        planComposition(source.plan, audioDuration: _comparisonAudioDuration) !=
            planComposition(
              draft.plan,
              audioDuration: _comparisonAudioDuration,
            );
  }

  Future<void> initialize() async {
    if (!isEditor) await repository.interruptUnfinished();
    await reload();
  }

  Future<void> reload() async {
    await flush();
    await modules.load();
    assets = await library.repository.list();
    templates = await repository.templates();
    if (repository is SqliteSessionRepository) {
      _templateRevisions.clear();
      for (final r in await ContentRevisionStore(
        (repository as SqliteSessionRepository).database,
      ).list()) {
        if (r.key.content.type == ContentType.template) {
          _templateRevisions.add(SessionTemplate.fromMap(r.payload));
        }
      }
    }
    runs = await repository.history();
    nextNumber = await repository.nextNumber();
    if (isEditor) {
      final refreshed = draft.plan.allSteps.map((s) {
        final actual = asset(s.audioAssetId);
        return s.kind == StepKind.audio &&
                actual != null &&
                actual.durationMs != s.durationMs
            ? s.copyWith(durationMs: actual.durationMs)
            : s;
      }).toList();
      if (refreshed.any(
        (s) =>
            draft.plan.allSteps.firstWhere((v) => v.id == s.id).durationMs !=
            s.durationMs,
      )) {
        draft = draft.copyWith(plan: draft.plan.copyWith(steps: refreshed));
      }
      _notify();
      return;
    }
    final stored = await repository.loadDraft();
    if (stored != null) {
      draft = stored;
    } else {
      final base = templates.where((t) => t.isDefault).firstOrNull;
      var usable = base != null;
      if (base != null) {
        for (final s in base.plan.steps) {
          if (s.kind == StepKind.audio) {
            final a = asset(s.audioAssetId);
            if (a == null || !await library.fileFor(a).exists()) usable = false;
          }
        }
      }
      draft = usable && base != null
          ? CurrentSessionDraft.fromTemplate(base)
          : CurrentSessionDraft(
              plan: SessionPlan(steps: const []),
              updatedAt: DateTime.now().toUtc(),
            );
      await repository.saveDraft(draft);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> flush() => _tail;
  Future<void> _edit(CurrentSessionDraft Function(CurrentSessionDraft) change) {
    final result = _tail.then((_) async {
      saving = true;
      saveError = null;
      _notify();
      try {
        final next = change(draft);
        _validate(next.plan);
        if (!isEditor) await repository.saveDraft(next);
        draft = next;
      } catch (_) {
        saveError = 'Изменения не сохранены. Повторите действие.';
        rethrow;
      } finally {
        saving = false;
        _notify();
      }
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  void _validate(SessionPlan plan) {
    if (plan.allSteps.map((s) => s.id).toSet().length != plan.allSteps.length) {
      throw const LibraryException('Повторяется ID элемента.');
    }
    for (final s in plan.allSteps) {
      if (s.delayBeforeSeconds < 0 || s.delayBeforeSeconds > 5995) {
        throw const LibraryException(
          'Пауза должна быть от 00:00 до 99:55 с шагом 1 секунда.',
        );
      }
      if (s.durationMs != null && s.durationMs! < 0) {
        throw const LibraryException('Неверная длительность.');
      }
      if (s.kind == StepKind.audio && s.audioAssetId == null) {
        throw const LibraryException('Не выбран аудиофайл.');
      }
    }
  }

  Future<void> changePhases(
    List<PhaseInstance> Function(List<PhaseInstance>) change,
  ) => _edit(
    (d) => d.copyWith(
      plan: modularize(d.plan)
          .copyWith(phases: change(modularize(d.plan).phases!)),
    ),
  );
  Future<String> createPhase(String typeId) async {
    final type = phaseTypes.firstWhere((p) => p.id == typeId);
    final id = newId();
    await changePhases(
      (p) => [...p, PhaseInstance(id: id, typeId: typeId, title: type.title)],
    );
    return id;
  }

  Future<void> updatePhase(PhaseInstance phase) =>
      changePhases((p) => p.map((v) => v.id == phase.id ? phase : v).toList());
  Future<void> addModule(String phaseId, ModuleDefinition module) =>
      changePhases(
        (phases) => phases
            .map(
              (p) => p.id == phaseId
                  ? p.copyWith(
                      children: [...p.children, module.instantiate(p.id)],
                    )
                  : p,
            )
            .toList(),
      );
  Future<void> addLoose(String phaseId, SessionStep step, {String? childId}) =>
      changePhases(
        (phases) => phases
            .map(
              (p) => p.id != phaseId
                  ? p
                  : p.copyWith(
                      children: childId == null
                          ? [
                              ...p.children,
                              PhaseChild(
                                id: newId(),
                                title: step.title,
                                items: [
                                  step.copyWith(id: newId(), groupId: p.id),
                                ],
                              ),
                            ]
                          : p.children
                                .map(
                                  (c) => c.id == childId
                                      ? c.copyWith(
                                          items: [
                                            ...c.items,
                                            step.copyWith(
                                              id: newId(),
                                              groupId: p.id,
                                            ),
                                          ],
                                        )
                                      : c,
                                )
                                .toList(),
                    ),
            )
            .toList(),
      );
  Future<void> updateChild(String phaseId, PhaseChild child) => changePhases(
    (p) => p
        .map(
          (v) => v.id == phaseId
              ? v.copyWith(
                  children: v.children
                      .map((c) => c.id == child.id ? child : c)
                      .toList(),
                )
              : v,
        )
        .toList(),
  );
  Future<void> removeChild(String phaseId, String id) => changePhases(
    (p) => p
        .map(
          (v) => v.id == phaseId
              ? v.copyWith(
                  children: v.children.where((c) => c.id != id).toList(),
                )
              : v,
        )
        .toList(),
  );
  Future<void> setText({String? topic, String? notes}) =>
      _edit((d) => d.copyWith(topicText: topic, notes: notes));
  Future<void> addAudio(AudioAsset a, {String? afterId, String? groupId}) =>
      _edit((d) {
        final list = [...d.plan.steps];
        final index = afterId == null
            ? list.length
            : list.indexWhere((s) => s.id == afterId) + 1;
        final group = groupId == null
            ? d.plan.availableGroups
                  .where((g) => g.category == a.category)
                  .firstOrNull
            : d.plan.availableGroups.where((g) => g.id == groupId).firstOrNull;
        list.insert(
          index,
          SessionStep(
            id: newId(),
            kind: StepKind.audio,
            title: a.title,
            audioAssetId: a.id,
            description: a.description,
            durationMs: a.durationMs,
            groupId: group?.id ?? groupId,
          ),
        );
        return d.copyWith(
          plan: d.plan.copyWith(
            steps: list,
            groups: _registerGroup(d.plan, group),
          ),
        );
      });
  List<StageGroup> _registerGroup(SessionPlan plan, StageGroup? group) => [
    ...plan.groups,
    if (group != null && !plan.groups.any((g) => g.id == group.id)) group,
  ];
  Future<void> addBlock(StepKind kind, int? durationMs, {String? groupId}) =>
      _edit((d) {
        final group = d.plan.availableGroups
            .where(
              (g) => groupId == null
                  ? g.category == AudioCategory.work
                  : g.id == groupId,
            )
            .firstOrNull;
        return d.copyWith(
          plan: d.plan.copyWith(
            groups: _registerGroup(d.plan, group),
            steps: [
              ...d.plan.steps,
              SessionStep(
                id: newId(),
                kind: kind,
                title: kind.label,
                durationMs: durationMs,
                groupId: group?.id ?? groupId,
              ),
            ],
          ),
        );
      });
  Future<void> updateStep(SessionStep step) => _edit(
    (d) => d.copyWith(
      plan: d.plan.copyWith(
        steps: d.plan.allSteps.map((s) => s.id == step.id ? step : s).toList(),
      ),
    ),
  );
  Future<void> setDelay(String id, int seconds) => _edit(
    (d) => d.copyWith(
      plan: d.plan.copyWith(
        steps: d.plan.allSteps
            .map(
              (s) => s.id == id ? s.copyWith(delayBeforeSeconds: seconds) : s,
            )
            .toList(),
      ),
    ),
  );
  Future<void> remove(String id) => _edit(
    (d) => d.copyWith(
      plan: d.plan.copyWith(
        steps: d.plan.allSteps.where((s) => s.id != id).toList(),
        clearExit: d.plan.exitStepId == id,
      ),
    ),
  );
  Future<void> duplicate(String id) => _edit((d) {
    final list = [...d.plan.steps];
    final index = list.indexWhere((s) => s.id == id);
    if (index >= 0) list.insert(index + 1, list[index].copyWith(id: newId()));
    return d.copyWith(plan: d.plan.copyWith(steps: list));
  });
  Future<void> reorder(int oldIndex, int newIndex) => _edit((d) {
    final list = [...d.plan.steps];
    if (newIndex > oldIndex) newIndex--;
    list.insert(newIndex, list.removeAt(oldIndex));
    return d.copyWith(plan: d.plan.copyWith(steps: list));
  });
  Future<void> setGroup(String id, String? groupId) => _edit((d) {
    final group = d.plan.availableGroups
        .where((g) => g.id == groupId)
        .firstOrNull;
    return d.copyWith(
      plan: d.plan.copyWith(
        groups: _registerGroup(d.plan, group),
        steps: d.plan.steps
            .map(
              (s) => s.id == id
                  ? s.copyWith(groupId: groupId, ungroup: groupId == null)
                  : s,
            )
            .toList(),
      ),
    );
  });
  Future<void> addGroup(String name, {String description = ''}) => _edit((d) {
    final existing = d.plan.availableGroups
        .where((g) => g.name.toLowerCase() == name.trim().toLowerCase())
        .firstOrNull;
    final group =
        existing ??
        StageGroup(
          id: newId(),
          name: name.trim(),
          description: description.trim(),
        );
    return d.copyWith(
      plan: d.plan.copyWith(groups: _registerGroup(d.plan, group)),
    );
  });
  Future<void> setExit(String? stepId) => _edit(
    (d) => d.copyWith(
      plan: d.plan.copyWith(exitStepId: stepId, clearExit: stepId == null),
    ),
  );
  Future<SessionTemplate> saveAsTemplate(
    String name,
    String description, {
    SessionPlan? plan,
    SessionTemplate? parent,
  }) async {
    await flush();
    if (name.trim().isEmpty) {
      throw const LibraryException('Введите название программы.');
    }
    final now = DateTime.now().toUtc();
    final template = SessionTemplate(
      id: newId(),
      parentRevision: parent == null
          ? null
          : ContentRevisionStore.revisionForRow('session_templates', {
              'id': parent.id,
              'payload': jsonEncode(parent.toMap()),
            })!.key,
      name: name.trim(),
      description: description.trim(),
      plan: SessionPlan.fromMap((plan ?? draft.plan).toMap()),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveTemplate(template);
    templates = await repository.templates();
    if (repository is SqliteSessionRepository) {
      _templateRevisions.clear();
      for (final r in await ContentRevisionStore(
        (repository as SqliteSessionRepository).database,
      ).list()) {
        if (r.key.content.type == ContentType.template) {
          _templateRevisions.add(SessionTemplate.fromMap(r.payload));
        }
      }
    }
    _notify();
    return template;
  }

  Future<void> loadTemplate(SessionTemplate t) => _edit(
    (d) => CurrentSessionDraft.fromTemplate(
      t,
      topicText: d.topicText,
      notes: d.notes,
    ),
  );

  Future<void> overwriteBase() async {
    await flush();
    final old = baseTemplate;
    if (old == null) {
      throw const LibraryException('Исходная программа недоступна.');
    }
    if (!policy.canEditMaterial('template', old.id, old.origin)) {
      throw const LibraryException(
        'Общую программу изменяет только автор. Сохраните как новую.',
      );
    }
    final updated = SessionTemplate(
      id: old.id,
      name: old.name,
      description: old.description,
      plan: draft.plan,
      createdAt: old.createdAt,
      updatedAt: DateTime.now().toUtc(),
      version: old.version + 1,
      isDefault: old.isDefault,
      origin: old.origin,
      parentRevision: old.parentRevision,
      baseRevision: old.baseRevision,
      author: old.author,
    );
    await repository.saveTemplate(updated);
    templates = await repository.templates();
    if (repository is SqliteSessionRepository) {
      _templateRevisions.clear();
      for (final r in await ContentRevisionStore(
        (repository as SqliteSessionRepository).database,
      ).list()) {
        if (r.key.content.type == ContentType.template) {
          _templateRevisions.add(SessionTemplate.fromMap(r.payload));
        }
      }
    }
    await loadTemplate(updated);
  }

  Future<void> restore() async {
    final t = baseTemplate;
    if (t == null) {
      throw const LibraryException(
        'Исходная программа недоступна. Сохраните текущую конфигурацию как новую.',
      );
    }
    await loadTemplate(t);
  }

  Future<List<String>> replayIssues(SessionRun run) async {
    final issues = <String>[];
    for (final id
        in run.snapshot.plan.steps
            .where((s) => s.kind == StepKind.audio)
            .map((s) => s.audioAssetId)
            .toSet()) {
      final a = asset(id);
      final expected = run.snapshot.audioMetadata[id]?['contentHash'];
      if (a == null) {
        issues.add('Аудио $id удалено');
        continue;
      }
      try {
        final verified = await library.identify(a, verify: true);
        if (expected == null) {
          issues.add(
            '«${a.title}»: старая история без подтверждённой идентичности аудио',
          );
        } else if (verified.contentHash != expected) {
          issues.add('«${a.title}»: содержимое отличается от исходной сессии');
        }
      } catch (_) {
        issues.add('«${a.title}»: файл недоступен или повреждён');
      }
    }
    return issues;
  }

  Future<void> useRun(SessionRun run, {bool rebuild = false}) async {
    if (!rebuild) {
      final issues = await replayIssues(run);
      if (issues.isNotEmpty) throw LibraryException(issues.join('\n'));
    }
    final t = templates
        .where((t) => t.id == run.snapshot.baseTemplateId)
        .firstOrNull;
    final metadata = <String, dynamic>{};
    final unavailable = <String>[];
    if (rebuild) {
      for (final step in run.snapshot.plan.steps.where(
        (s) => s.kind == StepKind.audio,
      )) {
        final a = asset(step.audioAssetId);
        try {
          if (a == null ||
              run.snapshot.audioMetadata[a.id]?['contentHash'] == null ||
              (await library.identify(a, verify: true)).contentHash !=
                  run.snapshot.audioMetadata[a.id]?['contentHash']) {
            unavailable.add(step.id);
          }
        } catch (_) {
          unavailable.add(step.id);
        }
      }
    }
    if (t != null) {
      for (final id
          in t.plan.steps
              .map((s) => s.audioAssetId)
              .whereType<String>()
              .toSet()) {
        final a = asset(id);
        if (a != null) {
          try {
            metadata[id] = {
              'contentHash': (await library.identify(a)).contentHash,
            };
          } catch (_) {
            /* Missing changed-template audio implies archival fallback. */
          }
        }
      }
    }
    final matching =
        !rebuild &&
        t != null &&
        run.snapshot.executionFingerprint != null &&
        executionFingerprint(t.plan, metadata) ==
            run.snapshot.executionFingerprint;
    await _edit(
      (d) => matching
          ? CurrentSessionDraft.fromTemplate(
              t,
              topicText: run.snapshot.topicText,
              notes: run.notes,
            ).copyWith(audioMetadata: run.snapshot.audioMetadata)
          : CurrentSessionDraft(
              plan: archivalPlan(run.snapshot.plan),
              updatedAt: DateTime.now().toUtc(),
              topicText: run.snapshot.topicText,
              notes: run.notes,
              archiveName: run.snapshot.baseTemplateName ?? run.name,
              unavailableStepIds: unavailable,
              audioMetadata: run.snapshot.audioMetadata,
            ),
    );
  }

  Future<void> clearPlan() => _edit(
    (d) => CurrentSessionDraft(
      plan: SessionPlan(steps: const []),
      updatedAt: DateTime.now().toUtc(),
      topicText: d.topicText,
      notes: d.notes,
    ),
  );
  Future<CurrentSessionDraft> snapshotForStart() async {
    await flush();
    if (saveError != null) {
      throw const LibraryException(
        'Есть несохранённые изменения. Повторите сохранение перед запуском.',
      );
    }
    if (draft.plan.steps.isEmpty) {
      throw const LibraryException(
        'Добавьте хотя бы один трек или интервал в структуру.',
      );
    }
    final frozen = <SessionStep>[];
    final verified = <String, AudioAsset>{};
    final activeIds = draft.plan.steps.map((s) => s.id).toSet();
    for (final s in draft.plan.allSteps) {
      if (activeIds.contains(s.id) && draft.unavailableStepIds.contains(s.id)) {
        throw LibraryException(
          '«${s.title}»: замените или удалите недоступный архивный трек.',
        );
      }
      if (s.kind == StepKind.voiceRecording && activeIds.contains(s.id)) {
        throw const LibraryException(
          'Запись во время сессии будет доступна на следующем этапе. Замените этот элемент тишиной или самостоятельной работой.',
        );
      }
      if (s.kind == StepKind.audio) {
        final a = asset(s.audioAssetId);
        if ((a == null || !await library.fileFor(a).exists()) &&
            activeIds.contains(s.id)) {
          throw LibraryException(
            'Файл «${s.title}» недоступен. Замените его в структуре.',
          );
        }
        if (a != null && activeIds.contains(s.id)) {
          final identified = verified[a.id] ??= await library.identify(
            a,
            verify: true,
          );
          final expected = draft.audioMetadata[a.id]?['contentHash'];
          if (expected != null && expected != identified.contentHash) {
            throw LibraryException(
              'Для «${a.title}» изменились байты. Замените или удалите этот трек.',
            );
          }
        }
        frozen.add(
          a == null
              ? s
              : s.copyWith(
                  title: s.title,
                  description: s.description.isEmpty
                      ? a.description
                      : s.description,
                  durationMs: a.durationMs,
                ),
        );
      } else {
        frozen.add(s);
      }
    }
    assets = await library.repository.list();
    final metadata = <String, dynamic>{
      for (final a in assets.where(
        (a) => frozen.any((s) => s.audioAssetId == a.id),
      ))
        a.id: {
          'title': a.title,
          'durationMs': a.durationMs,
          'format': a.format,
          'contentHash': a.contentHash,
        },
    };
    return CurrentSessionDraft.fromMap({
      ...draft
          .copyWith(
            plan: draft.plan.copyWith(steps: frozen),
            audioMetadata: metadata,
          )
          .toMap(),
      'executionFingerprint': executionFingerprint(
        draft.plan.copyWith(steps: frozen),
        metadata,
      ),
    });
  }

  @override
  void dispose() {
    library.policy.removeListener(_notify);
    _cloudQueue?.dispose();
    _disposed = true;
    super.dispose();
  }
}
