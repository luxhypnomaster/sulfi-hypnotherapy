import 'dart:convert';

import 'modular_plan.dart';
import 'session_plan.dart';

/// Only editable execution semantics; occurrence IDs and descriptive text do not
/// identify a composition. Unknown source revisions must be handled by caller.
List<Object?> _steps(
  Iterable<SessionStep> steps,
  int? Function(SessionStep)? audioDuration,
) => [
  for (final s in steps)
    [
      s.kind.name,
      s.enabled,
      s.audioAssetId,
      s.delayBeforeSeconds,
      s.kind == StepKind.audio && audioDuration != null
          ? audioDuration(s)
          : s.durationMs,
    ],
];
String stepsComposition(
  Iterable<SessionStep> steps, {
  int? Function(SessionStep)? audioDuration,
}) => jsonEncode(_steps(steps, audioDuration));
String planComposition(
  SessionPlan plan, {
  int? Function(SessionStep)? audioDuration,
}) => jsonEncode([
  for (final p in modularize(plan).phases!)
    [
      p.typeId,
      p.enabled,
      for (final c in p.children)
        [c.isModule, c.definitionId, c.enabled, _steps(c.items, audioDuration)],
    ],
  plan.exitStepId == null
      ? null
      : plan.allSteps.indexWhere((s) => s.id == plan.exitStepId),
]);
