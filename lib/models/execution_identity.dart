import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'modular_plan.dart';
import 'session_plan.dart';

/// v1: executable order and media identity, independent of instance IDs,
/// presentation titles, descriptions, categories and map insertion order.
String executionFingerprint(SessionPlan plan, Map<String, dynamic> audio) {
  final phases = modularize(plan).phases!.where((p) => p.enabled);
  final canonical = <Object?>[
    'sulfi-execution-v1',
    for (final phase in phases)
      [
        phase.typeId,
        phase.title,
        for (final child in phase.children.where((c) => c.enabled))
          for (final step in child.items.where((s) => s.enabled))
            [
              step.kind.name,
              step.delayBeforeSeconds,
              step.durationMs,
              if (step.kind == StepKind.audio)
                [
                  step.audioAssetId,
                  audio[step.audioAssetId]?['contentHash'] ?? 'unverified',
                ],
            ],
      ],
  ];
  return 'v1:${sha256.convert(utf8.encode(jsonEncode(canonical)))}';
}

SessionPlan archivalPlan(SessionPlan plan) => SessionPlan(
  steps: const [],
  phases: [
    for (final p in modularize(plan).phases!)
      PhaseInstance(
        id: p.id,
        typeId: p.typeId,
        title: p.title,
        enabled: p.enabled,
        children: [
          for (final child in p.children)
            for (final step in child.items)
              PhaseChild(
                id: 'archive-${step.id}',
                title: step.title,
                enabled: child.enabled,
                items: [step],
              ),
        ],
      ),
  ],
);
