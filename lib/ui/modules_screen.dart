import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart' show newId;
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'module_editor.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
    required this.controller,
    required this.player,
    this.selecting = false,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final bool selecting;
  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  String query = '';
  Future<void> _create() async {
    final v = await askDetails(
      context,
      title: 'Новый модуль',
      nameLabel: 'Название модуля',
    );
    if (v == null) return;
    await widget.controller.modules.save(
      ModuleDefinition(id: newId(), title: v.name, description: v.description),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(ModuleDefinition module) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleEditor(
          controller: widget.controller,
          player: widget.player,
          module: module,
        ),
      ),
    );
    await widget.controller.modules.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: widget.selecting ? 'Все модули' : 'Каталог модулей',
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Поиск модулей'),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        TextButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Создать модуль'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final m in widget.controller.modules.entries.where(
                (m) =>
                    !m.archived &&
                    '${m.title} ${m.description} ${m.tags.join(' ')}'
                        .toLowerCase()
                        .contains(query),
              ))
                ListTile(
                  title: Text(m.title),
                  subtitle: Text(
                    m.items.isEmpty
                        ? 'Пустой модуль'
                        : '${m.items.length} элементов · ${m.description}',
                  ),
                  onTap: widget.selecting
                      ? () => Navigator.pop(context, m)
                      : () => _edit(m),
                  trailing: IconButton(
                    tooltip: 'Изменить определение модуля',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(m),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
