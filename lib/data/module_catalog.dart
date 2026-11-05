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

  Future<void> save(ModuleDefinition module) async {
    if (module.title.trim().isEmpty) {
      throw ArgumentError('Введите название модуля');
    }
    if (database == null) {
      _memory[module.id] = module;
    } else {
      await database!.insert('module_definitions', {
        'id': module.id,
        'payload': jsonEncode(module.toMap()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await load();
  }

  Future<void> attach(String moduleId, SessionStep item) async {
    await load();
    final m = entries.firstWhere((m) => m.id == moduleId);
    await save(
      ModuleDefinition(
        id: m.id,
        title: m.title,
        description: m.description,
        tags: m.tags,
        recommendedPhaseIds: m.recommendedPhaseIds,
        version: m.version + 1,
        items: [
          ...m.items,
          item.copyWith(id: newId(), ungroup: true),
        ],
      ),
    );
  }

  Future<List<String>> references(String assetId) async {
    await load();
    return entries
        .where((m) => m.items.any((s) => s.audioAssetId == assetId))
        .map((m) => 'модуль «${m.title}»')
        .toList();
  }

  Future<void> clear() async {
    _memory.clear();
    await database?.delete('module_definitions');
    entries = [];
  }
}
