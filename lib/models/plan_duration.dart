import 'modular_plan.dart';
import 'audio_asset.dart';
import 'session_plan.dart';

/// Uses executable items and original milliseconds, exactly like SessionPlan.
class PlanDuration {
  const PlanDuration(this.knownMs, this.estimated);
  final int knownMs;
  final bool estimated;
  factory PlanDuration.steps(Iterable<SessionStep> steps) {
    var ms = 0;
    var unknown = false;
    for (final s in steps.where((s) => s.enabled)) {
      ms += s.estimatedMs;
      unknown = unknown || s.durationMs == null;
    }
    return PlanDuration(ms, unknown);
  }
  factory PlanDuration.phase(PhaseInstance p) => PlanDuration.steps([
    if (p.enabled)
      for (final c in p.children)
        if (c.enabled) ...c.items,
  ]);
  factory PlanDuration.child(PhaseChild c) =>
      PlanDuration.steps(c.enabled ? c.items : const []);
  factory PlanDuration.plan(SessionPlan p) => PlanDuration.steps(p.steps);
  String get label => '${estimated ? '≥' : ''}${formatDuration(knownMs)}';
  String get semantics => estimated
      ? 'Не менее ${formatDuration(knownMs)}. Полная длительность неизвестна.'
      : formatDuration(knownMs);
}

String structureCount(int n, String one, String few, String many) {
  final form = n % 100 >= 11 && n % 100 <= 14
      ? many
      : n % 10 == 1
      ? one
      : n % 10 >= 2 && n % 10 <= 4
      ? few
      : many;
  return '$n $form';
}

String structureSummary(SessionPlan source) {
  final plan = modularize(source), phases = plan.phases!;
  final tracks = plan.allSteps.where((s) => s.kind == StepKind.audio).length;
  final pauses = plan.allSteps
      .where((s) => s.kind == StepKind.silence || s.kind == StepKind.freeWork)
      .length;
  final recording = plan.allSteps
      .where((s) => s.kind == StepKind.voiceRecording)
      .length;
  return [
    structureCount(phases.length, 'фаза', 'фазы', 'фаз'),
    structureCount(
      phases.expand((p) => p.children).where((c) => c.isModule).length,
      'модуль',
      'модуля',
      'модулей',
    ),
    structureCount(tracks, 'трек', 'трека', 'треков'),
    structureCount(pauses, 'пауза', 'паузы', 'пауз'),
    if (recording > 0) structureCount(recording, 'запись', 'записи', 'записей'),
    PlanDuration.plan(plan).label,
  ].join(' • ');
}
