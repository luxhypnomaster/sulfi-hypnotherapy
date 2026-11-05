import 'modular_plan.dart';
import 'session_plan.dart';

enum StructureLevel { phase, module, item, loose, addModuleItem, addPhaseChild }

class StructureRow {
  const StructureRow(this.id, this.level, this.phase, {this.child, this.step});
  final String id;
  final StructureLevel level;
  final PhaseInstance phase;
  final PhaseChild? child;
  final SessionStep? step;
}

List<StructureRow> structureRows(
  List<PhaseInstance> phases,
  Set<String> collapsed,
) => [
  for (final p in phases) ...[
    StructureRow(p.id, StructureLevel.phase, p),
    if (!collapsed.contains(p.id)) ...[
      for (final child in p.children) ...[
        if (child.isModule)
          StructureRow(child.id, StructureLevel.module, p, child: child),
        if (!child.isModule || !collapsed.contains(child.id)) ...[
          for (final step in child.items)
            StructureRow(
              step.id,
              child.isModule ? StructureLevel.item : StructureLevel.loose,
              p,
              child: child,
              step: step,
            ),
          if (child.isModule)
            StructureRow(
              'add-${child.id}',
              StructureLevel.addModuleItem,
              p,
              child: child,
            ),
        ],
      ],
      StructureRow('add-${p.id}', StructureLevel.addPhaseChild, p),
    ],
  ],
];

/// The newIndex here is already adjusted by Flutter's onReorderItem.
/// A drop outside a parent never reparents an object or loses a descendant.
List<PhaseInstance> reorderStructure(
  List<PhaseInstance> phases,
  List<StructureRow> rows,
  int from,
  int to,
) {
  if (from < 0 || from >= rows.length || from == to) return phases;
  final source = rows[from];
  if ([
    StructureLevel.addModuleItem,
    StructureLevel.addPhaseChild,
  ].contains(source.level)) {
    return phases;
  }
  final raw = (to > from ? to + 1 : to).clamp(0, rows.length);
  final destination = rows[raw.clamp(0, rows.length - 1)];
  final before = rows.take(raw);
  if (source.level == StructureLevel.phase) {
    final next = phases.toList()..removeWhere((p) => p.id == source.phase.id);
    final index = before
        .where(
          (r) =>
              r.level == StructureLevel.phase && r.phase.id != source.phase.id,
        )
        .length
        .clamp(0, next.length);
    next.insert(index, source.phase);
    return next;
  }
  final previous = raw > 0 ? rows[raw - 1] : null;
  if (destination.phase.id != source.phase.id &&
      !(previous?.level == StructureLevel.addPhaseChild &&
          previous?.phase.id == source.phase.id)) {
    return phases;
  }
  if (source.level == StructureLevel.item) {
    if (destination.child?.id != source.child!.id &&
        !(previous?.level == StructureLevel.addModuleItem &&
            previous?.child?.id == source.child!.id)) {
      return phases;
    }
    final next = source.child!.items.toList()
      ..removeWhere((s) => s.id == source.step!.id);
    final index = before
        .where(
          (r) =>
              r.level == StructureLevel.item &&
              r.child?.id == source.child!.id &&
              r.step!.id != source.step!.id,
        )
        .length
        .clamp(0, next.length);
    next.insert(index, source.step!);
    return phases
        .map(
          (p) => p.id == source.phase.id
              ? p.copyWith(
                  children: p.children
                      .map(
                        (c) => c.id == source.child!.id
                            ? c.copyWith(items: next)
                            : c,
                      )
                      .toList(),
                )
              : p,
        )
        .toList();
  }
  final next = source.phase.children.toList()
    ..removeWhere((c) => c.id == source.child!.id);
  final preceding = before
      .where(
        (r) =>
            r.phase.id == source.phase.id &&
            (r.level == StructureLevel.module ||
                r.level == StructureLevel.loose) &&
            r.child!.id != source.child!.id,
      )
      .map((r) => r.child!.id)
      .toSet();
  next.insert(preceding.length.clamp(0, next.length), source.child!);
  return phases
      .map((p) => p.id == source.phase.id ? p.copyWith(children: next) : p)
      .toList();
}
