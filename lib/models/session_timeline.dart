import 'modular_plan.dart';
import 'session_plan.dart';

enum NavigationUnit { track, module, phase }

class TimelineEntry {
  const TimelineEntry(this.step, this.phase, this.child, this.index);
  final SessionStep step;
  final PhaseInstance phase;
  final PhaseChild child;
  final int index;
  String? get moduleId => child.isModule ? child.id : null;
}

/// Stable occurrence IDs, never labels or source AudioAsset IDs, define navigation.
class SessionTimeline {
  SessionTimeline(SessionPlan plan) {
    final tree = modularize(plan);
    final list = <TimelineEntry>[];
    for (final phase in tree.phases!.where((p) => p.enabled)) {
      for (final child in phase.children.where((c) => c.enabled)) {
        for (final step in child.items.where((s) => s.enabled)) {
          list.add(TimelineEntry(step, phase, child, list.length));
        }
      }
    }
    entries = List.unmodifiable(list);
  }
  late final List<TimelineEntry> entries;
  List<PhaseInstance> get phases => [
    for (final id in entries.map((e) => e.phase.id).toSet())
      entries.firstWhere((e) => e.phase.id == id).phase,
  ];

  int? target(int current, NavigationUnit unit, bool forward) {
    if (current < 0 || current >= entries.length) return null;
    if (unit == NavigationUnit.track) {
      final candidates = entries.where(
        (e) =>
            e.step.kind == StepKind.audio &&
            (forward ? e.index > current : e.index < current),
      );
      return (forward ? candidates.firstOrNull : candidates.lastOrNull)?.index;
    }
    final starts = <TimelineEntry>[];
    final seen = <String>{};
    for (final e in entries) {
      final id = unit == NavigationUnit.phase ? e.phase.id : e.moduleId;
      if (id != null && seen.add(id)) starts.add(e);
    }
    final here = entries[current];
    final id = unit == NavigationUnit.phase ? here.phase.id : here.moduleId;
    final position = starts.indexWhere(
      (e) => (unit == NavigationUnit.phase ? e.phase.id : e.moduleId) == id,
    );
    if (position < 0) {
      final next = starts.where(
        (e) => forward ? e.index > current : e.index < current,
      );
      return (forward ? next.firstOrNull : next.lastOrNull)?.index;
    }
    final next = position + (forward ? 1 : -1);
    return next < 0 || next >= starts.length ? null : starts[next].index;
  }
}

class SessionForecast {
  const SessionForecast(
    this.elapsedMs,
    this.remainingMs, {
    this.finished = false,
  });
  final bool finished;
  final int elapsedMs;
  final int? remainingMs;
  int? get totalMs => remainingMs == null ? null : elapsedMs + remainingMs!;
  double? get progress => finished
      ? 1
      : totalMs == null || totalMs! <= 0
      ? null
      : (elapsedMs / totalMs!).clamp(0.0, 1.0);
  double? get liquidFraction => progress == null ? null : 1 - progress!;
}
