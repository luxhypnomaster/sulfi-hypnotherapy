import 'session_plan.dart';

enum StepFact { completed, skipped, interrupted, started, unknown, disabled }

/// Only recorded facts. Seek positions and percentages never imply completion
/// or skipping; old histories with no evidence stay unknown.
class HistoryFacts {
  HistoryFacts(this.run, this.events);
  final SessionRun run;
  final List<Map<String, dynamic>> events;
  StepFact step(SessionStep step) {
    final index = run.snapshot.plan.steps.indexWhere((s) => s.id == step.id);
    if (index < 0) return StepFact.disabled;
    final kinds = events
        .where((e) => e['stepIndex'] == index)
        .map((e) => e['eventType'])
        .toSet();
    if (run.completedStepIds.contains(step.id) ||
        kinds.contains('block_completed') ||
        kinds.contains('work_completed_early')) {
      return StepFact.completed;
    }
    if (run.skippedStepIds.contains(step.id) ||
        kinds.contains('block_skipped')) {
      return StepFact.skipped;
    }
    if (kinds.any(
      (k) => const {
        'interrupted',
        'process_interrupted',
        'audio_error',
        'execution_error',
      }.contains(k),
    )) {
      return StepFact.interrupted;
    }
    if (kinds.contains('block_started') || kinds.contains('delay_started')) {
      return StepFact.started;
    }
    return StepFact.unknown;
  }

  StepFact group(Iterable<SessionStep> steps) {
    final facts = steps.map(step).where((f) => f != StepFact.disabled).toList();
    if (facts.isNotEmpty && facts.every((f) => f == StepFact.completed)) {
      return StepFact.completed;
    }
    if (facts.contains(StepFact.interrupted)) return StepFact.interrupted;
    return StepFact.unknown;
  }

  int get completed => run.snapshot.plan.steps
      .where((s) => step(s) == StepFact.completed)
      .length;
}
