import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../models/audio_asset.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'library_screen.dart';
import 'design.dart';

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
        builder: (_) => _ModuleEditor(
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

class _ModuleEditor extends StatefulWidget {
  const _ModuleEditor({
    required this.controller,
    required this.player,
    required this.module,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final ModuleDefinition module;
  @override
  State<_ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends State<_ModuleEditor> {
  late ModuleDefinition m = widget.module;
  Future<void> _save(List<SessionStep> items) async {
    final updated = ModuleDefinition(
      id: m.id,
      title: m.title,
      description: m.description,
      tags: m.tags,
      recommendedPhaseIds: m.recommendedPhaseIds,
      version: m.version + 1,
      items: items,
    );
    await widget.controller.modules.save(updated);
    if (mounted) setState(() => m = updated);
  }

  Future<void> _add() async {
    final a = await Navigator.push<AudioAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          library: widget.controller.library,
          player: widget.player,
          controller: widget.controller,
          allowSelection: true,
        ),
      ),
    );
    if (a != null) {
      await _save([
        ...m.items,
        SessionStep(
          id: newId(),
          kind: StepKind.audio,
          title: a.title,
          audioAssetId: a.id,
          durationMs: a.durationMs,
          description: a.description,
        ),
      ]);
    }
  }

  Future<void> _interval() async {
    final kind = await showDialog<StepKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Интервал модуля'),
        children: [
          for (final k in [StepKind.silence, StepKind.freeWork])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, k),
              child: Text(k.label),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final value = await askDetails(
      context,
      title: 'Длительность интервала',
      name: '60',
      nameLabel: 'Секунды (0 — до ручного завершения)',
    );
    if (value == null) return;
    final n = int.tryParse(value.name);
    if (n == null || n < 0) return;
    await _save([
      ...m.items,
      SessionStep(
        id: newId(),
        kind: kind,
        title: kind.label,
        durationMs: n == 0 ? null : n * 1000,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: m.title,
    actions: [
      IconButton(
        tooltip: 'Название и описание',
        icon: const Icon(Icons.edit),
        onPressed: () async {
          final d = await askDetails(
            context,
            title: 'Параметры модуля',
            name: m.title,
            description: m.description,
          );
          if (d != null) {
            m = ModuleDefinition(
              id: m.id,
              title: d.name,
              description: d.description,
              tags: m.tags,
              recommendedPhaseIds: m.recommendedPhaseIds,
              version: m.version,
              items: m.items,
            );
            await _save(m.items);
          }
        },
      ),
      IconButton(
        tooltip: 'Архивировать модуль',
        icon: const Icon(Icons.archive_outlined),
        onPressed: () async {
          if (!await confirmAction(
            context,
            'Архивировать модуль?',
            'Применённые копии в сессиях, шаблоны и аудиофайлы останутся.',
            confirm: 'В архив',
          )) {
            return;
          }
          await widget.controller.modules.save(
            ModuleDefinition(
              id: m.id,
              title: m.title,
              description: m.description,
              items: m.items,
              tags: m.tags,
              recommendedPhaseIds: m.recommendedPhaseIds,
              archived: true,
              version: m.version + 1,
            ),
          );
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ],
    child: Column(
      children: [
        Text(m.description),
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Добавить трек из библиотеки'),
        ),
        TextButton.icon(
          onPressed: _interval,
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Добавить интервал'),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: m.items.length,
            onReorderItem: (from, to) {
              final list = [...m.items];
              list.insert(to, list.removeAt(from));
              _save(list);
            },
            itemBuilder: (context, i) => ListTile(
              key: ValueKey(m.items[i].id),
              title: Text(m.items[i].title),
              subtitle: Text(formatDuration(m.items[i].durationMs ?? 0)),
              trailing: IconButton(
                tooltip: 'Удалить ссылку из модуля',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _save([...m.items]..removeAt(i)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
