import 'dart:convert';

import 'modular_plan.dart';
import 'session_plan.dart';

/// Only editable execution semantics; occurrence IDs and descriptive text do not
/// identify a composition. Unknown source revisions must be handled by caller.
List<Object?> _steps(Iterable<SessionStep> steps) => [
  for (final s in steps)
    [
      s.kind.name,
      s.enabled,
      s.audioAssetId,
      s.delayBeforeSeconds,
      s.durationMs,
    ],
];
String stepsComposition(Iterable<SessionStep> steps) =>
    jsonEncode(_steps(steps));
String planComposition(SessionPlan plan) => jsonEncode([
  for (final p in modularize(plan).phases!)
    [
      p.typeId,
      p.enabled,
      for (final c in p.children)
        [c.isModule, c.definitionId, c.enabled, _steps(c.items)],
    ],
  plan.exitStepId == null
      ? null
      : plan.allSteps.indexWhere((s) => s.id == plan.exitStepId),
]);
