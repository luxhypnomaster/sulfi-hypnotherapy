import 'dart:convert';
import 'dart:math';

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
  const StageGroup({required this.id, required this.name});
  final String id;
  final String name;
  Map<String, Object?> toMap() => {'id': id, 'name': name};
  factory StageGroup.fromMap(Map<String, dynamic> m) =>
      StageGroup(id: m['id'] as String, name: m['name'] as String);
}

class SessionStep {
  const SessionStep({
    required this.id,
    required this.kind,
    required this.title,
    this.audioAssetId,
    this.groupId,
    this.description = '',
    this.delayBeforeSeconds = 0,
    this.durationMs = 0,
  });
  final String id;
  final StepKind kind;
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
  }) => SessionStep(
    id: id ?? this.id,
    kind: kind,
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
  }) : steps = List.unmodifiable(steps),
       groups = List.unmodifiable(groups);
  final List<SessionStep> steps;
  final List<StageGroup> groups;
  final String? exitStepId;
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
  String groupName(String? id) =>
      groups.where((g) => g.id == id).firstOrNull?.name ?? 'Без раздела';
  SessionPlan copyWith({
    List<SessionStep>? steps,
    List<StageGroup>? groups,
    String? exitStepId,
    bool clearExit = false,
  }) => SessionPlan(
    steps: steps ?? this.steps,
    groups: groups ?? this.groups,
    exitStepId: clearExit ? null : exitStepId ?? this.exitStepId,
  );
  Map<String, Object?> toMap() => {
    'steps': steps.map((s) => s.toMap()).toList(),
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
  const CurrentSessionDraft({
    required this.plan,
    required this.updatedAt,
    this.baseTemplateId,
    this.baseTemplateVersion,
    this.baseTemplateName,
    this.baseFingerprint,
    this.topicText = '',
    this.notes = '',
  });
  final SessionPlan plan;
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
  }) => CurrentSessionDraft(
    plan: plan ?? this.plan,
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
  });
  final String id, name, phase;
  final int displayNumber, stepIndex, playheadMs, elapsedMs;
  final CurrentSessionDraft snapshot;
  final DateTime startedAt;
  final DateTime? endedAt;
  final RunStatus status;
  final String? userNotes;
  String get notes => userNotes ?? snapshot.notes;
  bool get active => status == RunStatus.running || status == RunStatus.paused;
  SessionRun checkpoint({
    RunStatus? status,
    int? stepIndex,
    String? phase,
    int? playheadMs,
    int? elapsedMs,
    DateTime? endedAt,
  }) => SessionRun(
    id: id,
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
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'displayNumber': displayNumber,
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
  };
  factory SessionRun.fromMap(Map<String, dynamic> m) => SessionRun(
    id: m['id'] as String,
    displayNumber: m['displayNumber'] as int,
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
  );
}

String formatLocalDate(DateTime date) {
  final d = date.toLocal();
  String n(int v) => v.toString().padLeft(2, '0');
  return '${n(d.day)}.${n(d.month)}.${n(d.year % 100)} · ${n(d.hour)}:${n(d.minute)}';
}
