import 'dart:convert';
import 'dart:async';

import 'diary_controller.dart';

import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../data/module_catalog.dart';
import '../models/modular_plan.dart';
import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import 'library_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required this.repository,
    required this.library,
    ModuleCatalog? modules,
    this.diary,
  }) : modules = modules ?? ModuleCatalog();
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
    );
    editor._editorSource = this;
    editor.draft = CurrentSessionDraft.fromMap(draft.toMap());
    editor._editorBaseline = _draftToken(draft);
    editor.assets = List.of(assets);
    editor.templates = List.of(templates);
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
  final DiaryController? diary;
  final SessionRepository repository;
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

  Future<void> initialize() async {
    if (!isEditor) await repository.interruptUnfinished();
    await reload();
  }

  Future<void> reload() async {
    await flush();
    await modules.load();
    assets = await library.repository.list();
    templates = await repository.templates();
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
  }) async {
    await flush();
    if (name.trim().isEmpty) {
      throw const LibraryException('Введите название шаблона.');
    }
    final now = DateTime.now().toUtc();
    final template = SessionTemplate(
      id: newId(),
      name: name.trim(),
      description: description.trim(),
      plan: SessionPlan.fromMap((plan ?? draft.plan).toMap()),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveTemplate(template);
    templates = await repository.templates();
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
      throw const LibraryException('Исходный шаблон недоступен.');
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
    );
    await repository.saveTemplate(updated);
    templates = await repository.templates();
    await loadTemplate(updated);
  }

  Future<void> restore() async {
    final t = baseTemplate;
    if (t == null) {
      throw const LibraryException(
        'Исходный шаблон недоступен. Сохраните текущую конфигурацию как новый.',
      );
    }
    await loadTemplate(t);
  }

  Future<void> useRun(SessionRun run) => _edit(
    (d) => CurrentSessionDraft(
      plan: SessionPlan.fromMap(run.snapshot.plan.toMap()),
      updatedAt: DateTime.now().toUtc(),
      topicText: run.snapshot.topicText,
      notes: run.notes,
    ),
  );
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
    final activeIds = draft.plan.steps.map((s) => s.id).toSet();
    for (final s in draft.plan.allSteps) {
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
    return draft.copyWith(
      plan: draft.plan.copyWith(steps: frozen),
      audioMetadata: {
        for (final a in assets.where(
          (a) => frozen.any((s) => s.audioAssetId == a.id),
        ))
          a.id: {
            'title': a.title,
            'durationMs': a.durationMs,
            'format': a.format,
          },
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
