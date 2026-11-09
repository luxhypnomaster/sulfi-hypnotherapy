import 'session_plan.dart';
import 'content_revision.dart';

class PhaseType {
  const PhaseType(this.id, this.title, this.description);
  final String id, title, description;
}

const phaseTypes = [
  PhaseType(
    'preparation',
    'Подготовка',
    'Общие инструкции и подготовка к сессии.',
  ),
  PhaseType('induction', 'Индукция', 'Вход в состояние самогипноза.'),
  PhaseType('deepener', 'Углубление', 'Углубление расслабления и внимания.'),
  PhaseType(
    'safePlace',
    'Безопасное место',
    'Воображаемое опорное пространство.',
  ),
  PhaseType('work', 'Проработка', 'Работа по выбранной теме.'),
  PhaseType(
    'returnSafe',
    'Возвращение в безопасное место',
    'Возвращение к опорному пространству.',
  ),
  PhaseType('integration', 'Интеграция', 'Осмысление и закрепление опыта.'),
  PhaseType('progression', 'Прогрессия', 'Репетиция будущих действий.'),
  PhaseType('suggestions', 'Установки', 'Тематические и личные записи.'),
  PhaseType('exit', 'Выход', 'Завершение и ориентация в настоящем.'),
];

class PhaseInstance {
  PhaseInstance({
    required this.id,
    required this.typeId,
    required this.title,
    this.enabled = true,
    List<PhaseChild> children = const [],
  }) : children = List.unmodifiable(children);
  final String id, typeId, title;
  final bool enabled;
  final List<PhaseChild> children;
  PhaseInstance copyWith({
    String? title,
    bool? enabled,
    List<PhaseChild>? children,
  }) => PhaseInstance(
    id: id,
    typeId: typeId,
    title: title ?? this.title,
    enabled: enabled ?? this.enabled,
    children: children ?? this.children,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'typeId': typeId,
    'title': title,
    'enabled': enabled,
    'children': children.map((c) => c.toMap()).toList(),
  };
  factory PhaseInstance.fromMap(Map<String, dynamic> m) => PhaseInstance(
    id: m['id'],
    typeId: m['typeId'],
    title: m['title'],
    enabled: m['enabled'] ?? true,
    children: (m['children'] as List)
        .map((c) => PhaseChild.fromMap(Map<String, dynamic>.from(c)))
        .toList(),
  );
}

class PhaseChild {
  PhaseChild({
    required this.id,
    required this.title,
    this.description = '',
    this.definitionId,
    this.definitionVersion,
    this.baseFingerprint,
    this.detached = false,
    this.enabled = true,
    List<SessionStep> items = const [],
  }) : items = List.unmodifiable(items);
  final String id, title, description;
  final String? definitionId, baseFingerprint;
  final int? definitionVersion;
  final bool enabled;
  final bool detached;
  final List<SessionStep> items;
  bool get isModule => definitionId != null;
  String get fingerprint => items.map((s) => s.toMap().toString()).join('|');
  bool get modified => isModule && (detached || baseFingerprint != fingerprint);
  String get workingStatus =>
      isModule && !modified ? 'Постоянный' : 'Временный';
  PhaseChild copyWith({
    String? title,
    String? description,
    bool? enabled,
    List<SessionStep>? items,
  }) => PhaseChild(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    definitionId: definitionId,
    definitionVersion: definitionVersion,
    baseFingerprint: baseFingerprint,
    detached:
        detached ||
        (isModule &&
            ((title != null && title != this.title) ||
                (description != null && description != this.description) ||
                (items != null &&
                    items.map((s) => s.toMap().toString()).join('|') !=
                        fingerprint))),
    enabled: enabled ?? this.enabled,
    items: items ?? this.items,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    if (description.isNotEmpty) 'description': description,
    'definitionId': definitionId,
    'definitionVersion': definitionVersion,
    'baseFingerprint': baseFingerprint,
    if (detached) 'detached': true,
    'enabled': enabled,
    'items': items.map((s) => s.toMap()).toList(),
  };
  factory PhaseChild.fromMap(Map<String, dynamic> m) => PhaseChild(
    id: m['id'],
    title: m['title'],
    description: m['description'] ?? '',
    definitionId: m['definitionId'],
    definitionVersion: m['definitionVersion'],
    baseFingerprint: m['baseFingerprint'],
    detached: m['detached'] ?? false,
    enabled: m['enabled'] ?? true,
    items: (m['items'] as List)
        .map((s) => SessionStep.fromMap(Map<String, dynamic>.from(s)))
        .toList(),
  );
}

class ModuleDefinition {
  ModuleDefinition({
    required this.id,
    required this.title,
    this.description = '',
    this.tags = const [],
    this.recommendedPhaseIds = const [],
    this.version = 1,
    this.archived = false,
    this.origin = 'personal',
    this.baseRevision = 1,
    this.author,
    this.parentRevision,
    List<SessionStep> items = const [],
    DateTime? updatedAt,
  }) : items = List.unmodifiable(items),
       updatedAt = updatedAt ?? DateTime.now().toUtc();
  final String id, title, description;
  final List<String> tags, recommendedPhaseIds;
  final int version;
  final bool archived;
  final String origin;
  final int baseRevision;
  final String? author;
  final RevisionKey? parentRevision;
  final List<SessionStep> items;
  final DateTime updatedAt;
  PhaseChild instantiate(String phaseId) {
    final cloned = items
        .map((s) => s.copyWith(id: newId(), groupId: phaseId))
        .toList();
    final child = PhaseChild(
      id: newId(),
      title: title,
      description: description,
      definitionId: id,
      definitionVersion: version,
      items: cloned,
    );
    return PhaseChild(
      id: child.id,
      title: title,
      description: description,
      definitionId: id,
      definitionVersion: version,
      items: cloned,
      baseFingerprint: child.fingerprint,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'tags': tags,
    'recommendedPhaseIds': recommendedPhaseIds,
    'version': version,
    'archived': archived,
    'source': 'localUser',
    'origin': origin,
    'baseRevision': baseRevision,
    'author': author,
    if (parentRevision != null) 'parentRevision': parentRevision!.toMap(),
    'updatedAt': updatedAt.toIso8601String(),
    'items': items.map((s) => s.toMap()).toList(),
  };
  factory ModuleDefinition.fromMap(Map<String, dynamic> m) => ModuleDefinition(
    id: m['id'],
    title: m['title'],
    description: m['description'] ?? '',
    tags: List<String>.from(m['tags'] ?? []),
    recommendedPhaseIds: List<String>.from(m['recommendedPhaseIds'] ?? []),
    version: m['version'] ?? 1,
    archived: m['archived'] ?? false,
    origin: m['origin'] ?? 'personal',
    baseRevision: m['baseRevision'] ?? 1,
    author: m['author'],
    parentRevision: m['parentRevision'] == null
        ? null
        : RevisionKey.fromMap(Map<String, dynamic>.from(m['parentRevision'])),
    updatedAt: DateTime.parse(m['updatedAt']),
    items: (m['items'] as List)
        .map((s) => SessionStep.fromMap(Map<String, dynamic>.from(s)))
        .toList(),
  );
}

/// Deterministic adapter: only contiguous legacy groups coalesce. Never sort.
SessionPlan modularize(SessionPlan plan) {
  if (plan.phases != null) return plan;
  final phases = <PhaseInstance>[];
  for (final step in plan.allSteps) {
    final group = plan.groups.where((g) => g.id == step.groupId).firstOrNull;
    final type = group?.category?.name ?? 'legacy';
    final title = group?.name ?? 'Нераспределённые';
    final prior = phases.lastOrNull;
    final same =
        prior != null &&
        prior.id.startsWith('legacy-${step.groupId ?? 'none'}-');
    final id = same ? prior.id : 'legacy-${step.groupId ?? 'none'}-${step.id}';
    final child = PhaseChild(
      id: 'item-${step.id}',
      title: step.title,
      items: [step.copyWith(groupId: id)],
    );
    if (same) {
      phases[phases.length - 1] = prior.copyWith(
        children: [...prior.children, child],
      );
    } else {
      phases.add(
        PhaseInstance(id: id, typeId: type, title: title, children: [child]),
      );
    }
  }
  return plan.copyWith(phases: phases);
}
