import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart' show newId;
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'module_editor.dart';
import 'session_actions.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
    required this.controller,
    required this.player,
    this.selecting = false,
    this.embedded = false,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final bool selecting, embedded;
  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  String query = '';
  bool busy = false;
  Future<void> _create() =>
      _edit(ModuleDefinition(id: newId(), title: ''), creating: true);

  Future<void> _edit(ModuleDefinition module, {bool creating = false}) async {
    if (busy) return;
    setState(() => busy = true);
    await showActionError(context, () async {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ModuleEditor(
            controller: widget.controller,
            player: widget.player,
            module: module,
            creating: creating,
          ),
        ),
      );
      await widget.controller.modules.load();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Поиск модулей'),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        TextButton.icon(
          onPressed: busy ? null : _create,
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
                  key: ValueKey('module-${m.id}'),
                  title: Text(m.title),
                  subtitle: Text(
                    m.items.isEmpty
                        ? 'Пустой модуль'
                        : '${m.items.length} элементов · ${m.description}',
                  ),
                  onTap: busy
                      ? null
                      : widget.selecting && m.items.isNotEmpty
                      ? () => Navigator.pop(context, m)
                      : () => _edit(m),
                  trailing: IconButton(
                    tooltip: 'Изменить определение модуля',
                    icon: const Icon(Icons.edit),
                    onPressed: busy ? null : () => _edit(m),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return widget.embedded
        ? content
        : LeatherScaffold(
            title: widget.selecting ? 'Все модули' : 'Каталог модулей',
            child: content,
          );
  }
}
