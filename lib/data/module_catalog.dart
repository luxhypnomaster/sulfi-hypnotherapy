import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart';

class ModuleCatalog {
  ModuleCatalog([this.database]);
  final Database? database;
  final Map<String, ModuleDefinition> _memory = {};
  List<ModuleDefinition> entries = [];
  Future<void> load() async {
    entries = database == null
        ? _memory.values.toList()
        : (await database!.query('module_definitions'))
              .map(
                (r) => ModuleDefinition.fromMap(
                  jsonDecode(r['payload'] as String),
                ),
              )
              .toList();
  }

  Future<void> save(ModuleDefinition module, {int? expectedVersion}) async {
    if (module.title.trim().isEmpty) {
      throw ArgumentError('Введите название модуля');
    }
    if (database == null) {
      _memory[module.id] = module;
    } else {
      await database!.transaction((tx) async {
        final previous = await tx.query(
          'module_definitions',
          where: 'id=?',
          whereArgs: [module.id],
        );
        final old = previous.isEmpty
            ? null
            : ModuleDefinition.fromMap(
                jsonDecode(previous.single['payload'] as String),
              );
        if (expectedVersion != null &&
            (expectedVersion == 0
                ? old != null
                : old?.version != expectedVersion)) {
          throw StateError('Определение изменилось. Откройте редактор заново.');
        }
        // Supplied revisions and personal copies have distinct origins and IDs.
        if (old != null && old.origin != module.origin) {
          throw StateError(
            'Происхождение определения нельзя менять при сохранении',
          );
        }
        await tx.insert('module_definitions', {
          'id': module.id,
          'payload': jsonEncode(module.toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        if (old != null && module.version != old.version && !module.archived) {
          for (final table in ['current_draft', 'session_templates']) {
            for (final row in await tx.query(table)) {
              final m = Map<String, dynamic>.from(
                jsonDecode(row['payload'] as String),
              );
              final plan = SessionPlan.fromMap(
                Map<String, dynamic>.from(m['plan']),
              );
              var changed = false;
              final next = plan.phases
                  ?.map(
                    (phase) => phase.copyWith(
                      children: phase.children.map((child) {
                        if (child.definitionId != module.id ||
                            child.modified ||
                            child.title != old.title ||
                            child.description != old.description) {
                          return child;
                        }
                        changed = true;
                        final fresh = module.instantiate(phase.id);
                        return PhaseChild(
                          id: child.id,
                          title: fresh.title,
                          description: fresh.description,
                          definitionId: fresh.definitionId,
                          definitionVersion: fresh.definitionVersion,
                          baseFingerprint: fresh.baseFingerprint,
                          enabled: child.enabled,
                          items: fresh.items,
                        );
                      }).toList(),
                    ),
                  )
                  .toList();
              if (changed) {
                m['plan'] = plan.copyWith(phases: next).toMap();
                // Keep the old current-draft baseFingerprint: its accepted
                // yellow pencil must reveal the changed working composition.
                m['updatedAt'] = DateTime.now().toUtc().toIso8601String();
                if (table == 'session_templates') {
                  m['version'] = (m['version'] as int) + 1;
                }
                await tx.update(
                  table,
                  {'payload': jsonEncode(m)},
                  where: 'id=?',
                  whereArgs: [row['id']],
                );
              }
            }
          }
        }
      });
    }
    await load();
  }

  Future<void> attach(String moduleId, SessionStep item) async {
    await load();
    final m = entries.firstWhere((m) => m.id == moduleId);
    if (m.origin == 'supplied') {
      throw StateError(
        'Общий модуль редактируется в авторском редакторе. Создайте личный вариант.',
      );
    }
    await save(
      ModuleDefinition(
        id: m.id,
        title: m.title,
        description: m.description,
        tags: m.tags,
        recommendedPhaseIds: m.recommendedPhaseIds,
        version: m.version + 1,
        origin: m.origin,
        baseRevision: m.baseRevision,
        author: m.author,
        items: [
          ...m.items,
          item.copyWith(id: newId(), ungroup: true),
        ],
      ),
      expectedVersion: m.version,
    );
  }

  Future<List<String>> references(String assetId) async {
    await load();
    return entries
        .where(
          (m) => !m.archived && m.items.any((s) => s.audioAssetId == assetId),
        )
        .map((m) => 'модуль «${m.title}»')
        .toList();
  }

  Future<void> clear() async {
    _memory.clear();
    await database?.delete('module_definitions');
    entries = [];
  }
}
