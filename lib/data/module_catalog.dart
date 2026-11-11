import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/modular_plan.dart';
import 'content_revision_store.dart';
import '../models/content_revision.dart';
import '../models/composition_identity.dart';
import '../models/session_plan.dart';
import '../services/access_policy.dart';

class ModuleCatalog {
  ModuleCatalog([this.database, AccessPolicy? policy])
    : policy = policy ?? AccessPolicy();
  final AccessPolicy policy;
  final Database? database;
  final Map<String, ModuleDefinition> _memory = {};
  List<ModuleDefinition> entries = [];
  final List<ModuleDefinition> _revisions = [];
  ModuleDefinition? source(String id, int version, {RevisionKey? revision}) {
    if (revision != null) {
      if (revision.content.type != ContentType.module ||
          revision.content.id != id) {
        return null;
      }
      return [..._revisions, ...entries]
          .where(
            (m) =>
                m.id == id &&
                m.revisionKey.token == revision.token &&
                m.revisionKey.digest == revision.digest,
          )
          .firstOrNull;
    }
    final matches = [
      ..._revisions,
      ...entries,
    ].where((m) => m.id == id && m.version == version).toList();
    return matches.isNotEmpty &&
            matches.map((m) => stepsComposition(m.items)).toSet().length == 1
        ? matches.first
        : null;
  }

  Future<void> load() async {
    if (database != null) {
      _revisions.clear();
      for (final r in await ContentRevisionStore(database!).list()) {
        if (r.key.content.type == ContentType.module) {
          _revisions.add(ModuleDefinition.fromMap(r.payload));
        }
      }
    }
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
    await load();
    final previousModule = entries.where((m) => m.id == module.id).firstOrNull;
    if (previousModule != null) {
      policy.requireMaterial(
        'module',
        previousModule.id,
        previousModule.origin,
      );
    }
    policy.requireMaterial('module', module.id, module.origin);
    if (module.title.trim().isEmpty) {
      throw ArgumentError('Введите название модуля');
    }
    if (database == null) {
      if (previousModule != null) _revisions.add(previousModule);
      _revisions.add(module);
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
        for (final row in previous) {
          await ContentRevisionStore.retainRow(tx, 'module_definitions', row);
        }
        await ContentRevisionStore.retainRow(tx, 'module_definitions', {
          'id': module.id,
          'payload': jsonEncode(module.toMap()),
        });
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
              if (table == 'session_templates' &&
                  !policy.canEditMaterial(
                    'template',
                    row['id'] as String,
                    m['origin'] as String? ?? 'personal',
                  )) {
                continue;
              }
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
                          sourceRevision: fresh.sourceRevision,
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
                if (table == 'session_templates') {
                  await ContentRevisionStore.retainRow(tx, table, row);
                  await ContentRevisionStore.retainRow(tx, table, {
                    'id': row['id'],
                    'payload': jsonEncode(m),
                  });
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
    policy.requireMaterial('module', m.id, m.origin);
    await save(
      ModuleDefinition(
        id: m.id,
        title: m.title,
        description: m.description,
        tags: m.tags,
        recommendedPhaseIds: m.recommendedPhaseIds,
        version: m.version + 1,
        origin: m.origin,
        parentRevision: m.parentRevision,
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
    await load();
    for (final m in entries) {
      policy.requireMaterial('module', m.id, m.origin);
    }
    _memory.clear();
    await database?.delete('module_definitions');
    entries = [];
  }
}
