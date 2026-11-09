import 'package:flutter_test/flutter_test.dart';
import 'package:sulfi_hypnotherapy/models/composition_identity.dart';
import 'package:sulfi_hypnotherapy/models/modular_plan.dart';
import 'package:sulfi_hypnotherapy/models/session_plan.dart';
import 'package:sulfi_hypnotherapy/services/session_controller.dart';

import 'support/fakes.dart';

void main() {
  test(
    'composition: actual change, Undo, occurrence IDs and unknown revision',
    () async {
      final c = SessionController(
        repository: MemorySessionRepository(),
        library: MemoryLibrary(MemoryRepository()),
      );
      final m = ModuleDefinition(
        id: 'm',
        title: 'Источник',
        items: const [
          SessionStep(
            id: 's',
            kind: StepKind.silence,
            title: 'Пауза',
            durationMs: 1000,
          ),
          SessionStep(
            id: 'a',
            kind: StepKind.audio,
            title: 'Трек',
            audioAssetId: 'a',
            durationMs: 2000,
          ),
        ],
      );
      await c.modules.save(m);
      final copy = m.instantiate('p');
      expect(c.moduleDiffersFromSource(copy), false);
      final changed = copy.copyWith(items: copy.items.reversed.toList());
      expect(c.moduleDiffersFromSource(changed), true);
      final undo = changed.copyWith(items: copy.items);
      expect(undo.modified, true); // Legacy sticky flag must not drive UI.
      expect(c.moduleDiffersFromSource(undo), false);
      expect(
        c.moduleDiffersFromSource(copy.copyWith(title: 'Описание')),
        false,
      );
      final unknown = PhaseChild(
        id: 'old',
        title: 'Legacy',
        definitionId: 'm',
        definitionVersion: 99,
        items: changed.items,
      );
      expect(c.moduleDiffersFromSource(unknown), false);
      final p = SessionPlan(
        steps: const [],
        phases: [
          PhaseInstance(
            id: 'p',
            typeId: 'induction',
            title: 'Фаза',
            children: [copy],
          ),
        ],
      );
      final now = DateTime.utc(2026);
      final template = SessionTemplate(
        id: 't',
        name: 'Шаблон',
        plan: p,
        createdAt: now,
        updatedAt: now,
      );
      c.templates = [template];
      c.draft = CurrentSessionDraft.fromTemplate(template);
      expect(c.templateDiffersFromSource, false);
      final changedPlan = p.copyWith(
        phases: [
          p.phases!.single.copyWith(children: [changed]),
        ],
      );
      c.draft = c.draft.copyWith(plan: changedPlan);
      expect(c.templateDiffersFromSource, true);
      c.draft = c.draft.copyWith(plan: p);
      expect(c.templateDiffersFromSource, false);
      expect(stepsComposition(m.items), stepsComposition(copy.items));
      await c.modules.save(
        ModuleDefinition(id: m.id, title: 'v2', version: 2, items: const []),
      );
      expect(c.moduleDiffersFromSource(changed), true);
      expect(c.moduleDiffersFromSource(undo), false);
      c.dispose();
    },
  );
}
