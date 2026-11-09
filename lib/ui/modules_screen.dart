import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart' show newId;
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'content_export.dart';
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
  String origin = 'all';
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
          decoration: InputDecoration(
            labelText: 'Поиск модулей',
            suffixIcon: DropdownButton<String>(
              value: origin,
              underline: const SizedBox.shrink(),
              onChanged: (value) => setState(() => origin = value!),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все')),
                DropdownMenuItem(value: 'supplied', child: Text('Общие')),
                DropdownMenuItem(value: 'personal', child: Text('Мои')),
              ],
            ),
          ),
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
                    (origin == 'all' || m.origin == origin) &&
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
                        : '${m.origin == 'supplied' ? 'Общие' : 'Мои'} · Постоянный · ${m.items.length} элементов · ${m.description}',
                  ),
                  onTap: busy
                      ? null
                      : widget.selecting && m.items.isNotEmpty
                      ? () => Navigator.pop(context, m)
                      : () => _edit(m),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Действия модуля',
                    enabled: !busy,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _edit(m);
                        return;
                      }
                      setState(() => busy = true);
                      await showActionError(
                        context,
                        () => exportMaterial(
                          context,
                          widget.controller.capsules!,
                          moduleId: m.id,
                        ),
                      );
                      if (mounted) setState(() => busy = false);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      if (widget.controller.capsules != null)
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Экспортировать модуль'),
                        ),
                    ],
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
