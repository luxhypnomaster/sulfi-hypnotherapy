import 'dart:convert';
import 'dart:math';

import 'audio_asset.dart';
import 'modular_plan.dart';

String newId() {
  final random = Random.secure();
  return List.generate(
    4,
    (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
  ).join();
}

enum StepKind {
  audio('Аудио'),
  silence('Тишина'),
  freeWork('Самостоятельная работа'),
  voiceRecording('Запись речи');

  const StepKind(this.label);
  final String label;
}

class StageGroup {
  const StageGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.category,
  });
  final String id, name, description;
  final AudioCategory? category;
  // Omit absent additions to preserve existing template fingerprints byte for byte.
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (category != null) 'category': category!.name,
  };
  factory StageGroup.fromMap(Map<String, dynamic> m) => StageGroup(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String? ?? '',
    category: m['category'] == null
        ? null
        : AudioCategory.values.byName(m['category'] as String),
  );
}

const defaultStageGroups = [
  StageGroup(
    id: 'stage-preparation',
    name: 'Подготовка',
    category: AudioCategory.preparation,
    description:
        'Предварительные объяснения и инструкции перед началом сессии.',
  ),
  StageGroup(
    id: 'stage-induction',
    name: 'Погружение',
    category: AudioCategory.induction,
    description: 'Настройка внимания и переход к состоянию самогипноза.',
  ),
  StageGroup(
    id: 'stage-deepener',
    name: 'Углубление',
    category: AudioCategory.deepener,
    description: 'Углубление расслабления и сосредоточенности.',
  ),
  StageGroup(
    id: 'stage-work',
    name: 'Терапевтическое задание',
    category: AudioCategory.work,
    description: 'Основная работа по выбранной теме: инструкции, установки и самостоятельное задание.',
  ),
  StageGroup(
    id: 'stage-integration',
    name: 'Интеграция',
    category: AudioCategory.integration,
    description: 'Осмысление опыта и закрепление выбранных изменений.',
  ),
  StageGroup(
    id: 'stage-exit',
    name: 'Выход',
    category: AudioCategory.exit,
    description:
        'Завершение сессии и возвращение внимания к окружающей обстановке.',
  ),
];

class SessionStep {
  const SessionStep({
    required this.id,
    required this.kind,
    required this.title,
    this.audioAssetId,
    this.groupId,
    this.description = '',
    this.enabled = true,
    this.delayBeforeSeconds = 0,
    this.durationMs = 0,
  });
  final String id;
  final StepKind kind;
  final bool enabled;
  final String title;
  final String? audioAssetId;
  final String? groupId;
  final String description;
  final int delayBeforeSeconds;
  // null means user-controlled duration. Never include delay in this field.
  final int? durationMs;
  int get estimatedMs => delayBeforeSeconds * 1000 + (durationMs ?? 0);

  SessionStep copyWith({
    String? id,
    String? title,
    String? audioAssetId,
    String? groupId,
    String? description,
    int? delayBeforeSeconds,
    int? durationMs,
    bool indefinite = false,
    bool ungroup = false,
    bool? enabled,
  }) => SessionStep(
    id: id ?? this.id,
    kind: kind,
    enabled: enabled ?? this.enabled,
    title: title ?? this.title,
    audioAssetId: audioAssetId ?? this.audioAssetId,
    groupId: ungroup ? null : groupId ?? this.groupId,
    description: description ?? this.description,
    delayBeforeSeconds: delayBeforeSeconds ?? this.delayBeforeSeconds,
    durationMs: indefinite ? null : durationMs ?? this.durationMs,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    if (!enabled) 'enabled': false,
    'title': title,
    'audioAssetId': audioAssetId,
    'groupId': groupId,
    'description': description,
    'delayBeforeSeconds': delayBeforeSeconds,
    'durationMs': durationMs,
  };
  factory SessionStep.fromMap(Map<String, dynamic> m) => SessionStep(
    id: m['id'] as String,
    kind: StepKind.values.byName(m['kind'] as String),
    enabled: m['enabled'] as bool? ?? true,
    title: m['title'] as String,
    audioAssetId: m['audioAssetId'] as String?,
    groupId: m['groupId'] as String?,
    description: m['description'] as String? ?? '',
    delayBeforeSeconds: m['delayBeforeSeconds'] as int? ?? 0,
    durationMs: m['durationMs'] as int?,
  );
}

// Immutable snapshots: editing one document cannot mutate another's lists.
class SessionPlan {
  SessionPlan({
    required List<SessionStep> steps,
    List<StageGroup> groups = const [],
    this.exitStepId,
    List<PhaseInstance>? phases,
  }) : _steps = List.unmodifiable(steps),
       phases = phases == null ? null : List.unmodifiable(phases),
       groups = List.unmodifiable(groups);
  final List<SessionStep> _steps;
  final List<PhaseInstance>? phases;
  List<SessionStep> get allSteps => List.unmodifiable(
    phases == null
        ? _steps
        : [
            for (final p in phases!)
              for (final c in p.children) ...c.items,
          ],
  );
  List<SessionStep> get steps => List.unmodifiable(
    phases == null
        ? List.unmodifiable(_steps.where((s) => s.enabled))
        : [
            for (final p in phases!)
              if (p.enabled)
                for (final c in p.children)
                  if (c.enabled)
                    for (final s in c.items)
                      if (s.enabled) s,
          ],
  );
  final List<StageGroup> groups;
  final String? exitStepId;
  bool get hasExitAudio => phases == null
      ? steps.any((s) => s.id == exitStepId && s.kind == StepKind.audio)
      : phases!.any(
          (p) =>
              p.enabled &&
              p.typeId == 'exit' &&
              p.children.any(
                (c) =>
                    c.enabled &&
                    c.items.any((s) => s.enabled && s.kind == StepKind.audio),
              ),
        );
  int get totalMs => steps.fold(0, (sum, s) => sum + s.estimatedMs);
  int get delayMs =>
      steps.fold(0, (sum, s) => sum + s.delayBeforeSeconds * 1000);
  int get audioMs => steps
      .where((s) => s.kind == StepKind.audio)
      .fold(0, (sum, s) => sum + (s.durationMs ?? 0));
  int get workMs => steps
      .where((s) => s.kind != StepKind.audio)
      .fold(0, (sum, s) => sum + (s.durationMs ?? 0));
  bool get estimated => steps.any((s) => s.durationMs == null);
  // Built-in empty sections are a view catalog, not a mutation of saved plans.
  List<StageGroup> get availableGroups {
    final result = <StageGroup>[];
    final matched = <String>{};
    for (final builtin in defaultStageGroups) {
      final stored = groups
          .where((g) => g.id == builtin.id || g.name == builtin.name)
          .firstOrNull;
      if (stored == null) {
        result.add(builtin);
      } else {
        matched.add(stored.id);
        result.add(
          StageGroup(
            id: stored.id,
            name: stored.name,
            description: stored.description.isEmpty
                ? builtin.description
                : stored.description,
            category: stored.category ?? builtin.category,
          ),
        );
      }
    }
    result.addAll(groups.where((g) => !matched.contains(g.id)));
    return List.unmodifiable(result);
  }

  String groupName(String? id) =>
      phases?.where((p) => p.id == id).firstOrNull?.title ??
      availableGroups.where((g) => g.id == id).firstOrNull?.name ??
      'Без раздела';
  SessionPlan copyWith({
    List<SessionStep>? steps,
    List<StageGroup>? groups,
    String? exitStepId,
    bool clearExit = false,
    List<PhaseInstance>? phases,
  }) => SessionPlan(
    steps: steps ?? _steps,
    phases:
        phases ??
        (steps == null
            ? this.phases
            : this.phases
                  ?.map(
                    (p) => p.copyWith(
                      children: p.children
                          .map(
                            (c) => c.copyWith(
                              items: [
                                for (final old in c.items)
                                  if (steps.any((s) => s.id == old.id))
                                    steps.firstWhere((s) => s.id == old.id),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList()),
    groups: groups ?? this.groups,
    exitStepId: clearExit ? null : exitStepId ?? this.exitStepId,
  );
  Map<String, Object?> toMap() => {
    'steps': allSteps.map((s) => s.toMap()).toList(),
    if (phases != null) 'phases': phases!.map((p) => p.toMap()).toList(),
    'groups': groups.map((g) => g.toMap()).toList(),
    'exitStepId': exitStepId,
  };
  String get fingerprint => jsonEncode(toMap());
  factory SessionPlan.fromMap(Map<String, dynamic> m) => SessionPlan(
    steps: (m['steps'] as List)
        .map((s) => SessionStep.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList(),
    groups: ((m['groups'] as List?) ?? [])
        .map((g) => StageGroup.fromMap(Map<String, dynamic>.from(g as Map)))
        .toList(),
    phases: (m['phases'] as List?)
        ?.map((p) => PhaseInstance.fromMap(Map<String, dynamic>.from(p)))
        .toList(),
    exitStepId: m['exitStepId'] as String?,
  );
}

class SessionTemplate {
  const SessionTemplate({
    required this.id,
    required this.name,
    required this.plan,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.version = 1,
    this.isDefault = false,
  });
  final String id, name, description;
  final SessionPlan plan;
  final int version;
  final bool isDefault;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'plan': plan.toMap(),
    'version': version,
    'isDefault': isDefault,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
  factory SessionTemplate.fromMap(Map<String, dynamic> m) => SessionTemplate(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String,
    plan: SessionPlan.fromMap(Map<String, dynamic>.from(m['plan'] as Map)),
    version: m['version'] as int,
    isDefault: m['isDefault'] as bool,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );
}

class CurrentSessionDraft {
  CurrentSessionDraft({
    required this.plan,
    required this.updatedAt,
    this.baseTemplateId,
    this.baseTemplateVersion,
    this.baseTemplateName,
    this.baseFingerprint,
    this.topicText = '',
    this.notes = '',
    Map<String, dynamic> audioMetadata = const {},
  }) : audioMetadata = Map.unmodifiable({
         for (final e in audioMetadata.entries)
           e.key: Map.unmodifiable(Map<String, dynamic>.from(e.value)),
       });
  final SessionPlan plan;
  final Map<String, dynamic> audioMetadata;
  final String? baseTemplateId, baseTemplateName, baseFingerprint;
  final int? baseTemplateVersion;
  final String topicText, notes;
  final DateTime updatedAt;
  bool get modified =>
      plan.fingerprint !=
      (baseFingerprint ?? SessionPlan(steps: const []).fingerprint);
  CurrentSessionDraft copyWith({
    SessionPlan? plan,
    String? topicText,
    String? notes,
    Map<String, dynamic>? audioMetadata,
  }) => CurrentSessionDraft(
    plan: plan ?? this.plan,
    audioMetadata: audioMetadata ?? this.audioMetadata,
    updatedAt: DateTime.now().toUtc(),
    baseTemplateId: baseTemplateId,
    baseTemplateVersion: baseTemplateVersion,
    baseTemplateName: baseTemplateName,
    baseFingerprint: baseFingerprint,
    topicText: topicText ?? this.topicText,
    notes: notes ?? this.notes,
  );
  factory CurrentSessionDraft.fromTemplate(
    SessionTemplate template, {
    String topicText = '',
    String notes = '',
  }) => CurrentSessionDraft(
    plan: SessionPlan.fromMap(template.plan.toMap()),
    updatedAt: DateTime.now().toUtc(),
    baseTemplateId: template.id,
    baseTemplateVersion: template.version,
    baseTemplateName: template.name,
    baseFingerprint: template.plan.fingerprint,
    topicText: topicText,
    notes: notes,
  );
  Map<String, Object?> toMap() => {
    'plan': plan.toMap(),
    if (audioMetadata.isNotEmpty) 'audioMetadata': audioMetadata,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'baseTemplateId': baseTemplateId,
    'baseTemplateVersion': baseTemplateVersion,
    'baseTemplateName': baseTemplateName,
    'baseFingerprint': baseFingerprint,
    'topicText': topicText,
    'notes': notes,
  };
  factory CurrentSessionDraft.fromMap(Map<String, dynamic> m) =>
      CurrentSessionDraft(
        plan: SessionPlan.fromMap(Map<String, dynamic>.from(m['plan'] as Map)),
        audioMetadata: Map<String, dynamic>.from(m['audioMetadata'] ?? {}),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
        baseTemplateId: m['baseTemplateId'] as String?,
        baseTemplateVersion: m['baseTemplateVersion'] as int?,
        baseTemplateName: m['baseTemplateName'] as String?,
        baseFingerprint: m['baseFingerprint'] as String?,
        topicText: m['topicText'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
      );
}

enum RunStatus {
  running('В процессе'),
  paused('Пауза'),
  completed('Завершена'),
  exitingEarly('Переход к выходу'),
  completedEarlyWithExit('Завершена досрочно с выходом'),
  interrupted('Прервана'),
  error('Ошибка');

  const RunStatus(this.label);
  final String label;
}

class SessionRun {
  const SessionRun({
    required this.id,
    required this.displayNumber,
    required this.name,
    required this.snapshot,
    required this.startedAt,
    required this.status,
    this.endedAt,
    this.stepIndex = 0,
    this.phase = 'delay',
    this.playheadMs = 0,
    this.elapsedMs = 0,
    this.userNotes,
    this.lastCheckpointAt,
    this.endEstimated = false,
    this.startedUtcOffsetMinutes,
    this.skippedStepIds = const [],
  });
  final String id, name, phase;
  final int displayNumber, stepIndex, playheadMs, elapsedMs;
  final CurrentSessionDraft snapshot;
  final DateTime startedAt;
  final DateTime? endedAt, lastCheckpointAt;
  final bool endEstimated;
  final int? startedUtcOffsetMinutes;
  final List<String> skippedStepIds;
  final RunStatus status;
  final String? userNotes;
  String get notes => userNotes ?? snapshot.notes;
  bool get active =>
      status == RunStatus.running ||
      status == RunStatus.paused ||
      status == RunStatus.exitingEarly;
  SessionRun checkpoint({
    RunStatus? status,
    int? stepIndex,
    String? phase,
    int? playheadMs,
    int? elapsedMs,
    DateTime? endedAt,
    bool? endEstimated,
    List<String>? skippedStepIds,
  }) => SessionRun(
    id: id,
    startedUtcOffsetMinutes: startedUtcOffsetMinutes,
    skippedStepIds: skippedStepIds ?? this.skippedStepIds,
    displayNumber: displayNumber,
    name: name,
    snapshot: snapshot,
    startedAt: startedAt,
    status: status ?? this.status,
    stepIndex: stepIndex ?? this.stepIndex,
    phase: phase ?? this.phase,
    playheadMs: playheadMs ?? this.playheadMs,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    endedAt: endedAt ?? this.endedAt,
    userNotes: userNotes,
    lastCheckpointAt: lastCheckpointAt,
    endEstimated: endEstimated ?? this.endEstimated,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'displayNumber': displayNumber,
    'startedUtcOffsetMinutes': startedUtcOffsetMinutes,
    'skippedStepIds': skippedStepIds,
    'name': name,
    'snapshot': snapshot.toMap(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt?.toUtc().toIso8601String(),
    'status': status.name,
    'stepIndex': stepIndex,
    'phase': phase,
    'playheadMs': playheadMs,
    'elapsedMs': elapsedMs,
    'userNotes': userNotes,
    'lastCheckpointAt': lastCheckpointAt?.toUtc().toIso8601String(),
    'endEstimated': endEstimated,
  };
  factory SessionRun.fromMap(Map<String, dynamic> m) => SessionRun(
    id: m['id'] as String,
    displayNumber: m['displayNumber'] as int,
    startedUtcOffsetMinutes: m['startedUtcOffsetMinutes'] as int?,
    skippedStepIds: List<String>.from(m['skippedStepIds'] ?? []),
    name: m['name'] as String,
    snapshot: CurrentSessionDraft.fromMap(
      Map<String, dynamic>.from(m['snapshot'] as Map),
    ),
    startedAt: DateTime.parse(m['startedAt'] as String),
    endedAt: m['endedAt'] == null
        ? null
        : DateTime.parse(m['endedAt'] as String),
    status: RunStatus.values.byName(m['status'] as String),
    stepIndex: m['stepIndex'] as int,
    phase: m['phase'] as String,
    playheadMs: m['playheadMs'] as int,
    elapsedMs: m['elapsedMs'] as int,
    userNotes: m['userNotes'] as String?,
    lastCheckpointAt: m['lastCheckpointAt'] == null
        ? null
        : DateTime.parse(m['lastCheckpointAt'] as String),
    endEstimated: m['endEstimated'] as bool? ?? false,
  );
}

String formatLocalDate(DateTime date) {
  final d = date.toLocal();
  String n(int v) => v.toString().padLeft(2, '0');
  return '${n(d.day)}.${n(d.month)}.${n(d.year % 100)} · ${n(d.hour)}:${n(d.minute)}';
}
