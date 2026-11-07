import 'package:flutter/material.dart';

import '../data/module_catalog.dart';
import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../models/audio_asset.dart';

class ModuleChoice {
  String? id;
  String name = '', description = '';
}

class ModuleAssignment extends StatefulWidget {
  const ModuleAssignment({
    super.key,
    required this.catalog,
    required this.choice,
    this.compact = false,
  });
  final ModuleCatalog catalog;
  final ModuleChoice choice;
  final bool compact;
  @override
  State<ModuleAssignment> createState() => _ModuleAssignmentState();
}

class _ModuleAssignmentState extends State<ModuleAssignment> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: widget.choice.id ?? 'none',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Добавить в модуль',
          isDense: widget.compact,
        ),
        items: [
          const DropdownMenuItem(
            value: 'none',
            child: Text('Оставить только в библиотеке'),
          ),
          const DropdownMenuItem(
            value: 'new',
            child: Text('Создать новый модуль'),
          ),
          for (final m in widget.catalog.entries.where(
            (m) => !m.archived && m.origin == 'personal',
          ))
            DropdownMenuItem(value: m.id, child: Text(m.title)),
        ],
        onChanged: (v) =>
            setState(() => widget.choice.id = v == 'none' ? null : v),
      ),
      if (widget.choice.id == 'new')
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Название нового модуля',
          ),
          onChanged: (v) => widget.choice.name = v,
          validator: (v) =>
              widget.choice.id == 'new' && (v ?? '').trim().isEmpty
              ? 'Введите название модуля'
              : null,
        ),
    ],
  );
}

Future<void> attachAudioToModule(
  ModuleCatalog catalog,
  ModuleChoice choice,
  AudioAsset asset,
) async {
  if (choice.id == null) return;
  var id = choice.id!;
  if (id == 'new') {
    if (choice.name.trim().isEmpty) {
      throw ArgumentError('Введите название модуля');
    }
    id = newId();
    await catalog.save(
      ModuleDefinition(
        id: id,
        title: choice.name.trim(),
        description: choice.description,
      ),
    );
  }
  await catalog.attach(
    id,
    SessionStep(
      id: newId(),
      kind: StepKind.audio,
      title: asset.title,
      audioAssetId: asset.id,
      description: asset.description,
      durationMs: asset.durationMs,
    ),
  );
}
