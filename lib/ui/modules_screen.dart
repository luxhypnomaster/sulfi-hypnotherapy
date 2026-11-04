import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../models/audio_asset.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'library_screen.dart';
import 'design.dart';
import 'pause_time_picker.dart';

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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          library: widget.controller.library,
          player: widget.player,
          controller: widget.controller,
          allowSelection: true,
          onSelected: (a) => _save([
            ...m.items,
            SessionStep(
              id: newId(),
              kind: StepKind.audio,
              title: a.title,
              audioAssetId: a.id,
              durationMs: a.durationMs,
              description: a.description,
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _interval([SessionStep? item]) async {
    final seconds = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PauseTimePicker(
          initialSeconds: (item?.durationMs ?? 0) ~/ 1000,
          manualEnd: item != null && item.durationMs == null,
        ),
      ),
    );
    if (seconds == null) return;
    final step =
        item?.copyWith(
          durationMs: seconds < 0 ? null : seconds * 1000,
          indefinite: seconds < 0,
        ) ??
        SessionStep(
          id: newId(),
          kind: StepKind.silence,
          title: 'Пауза',
          durationMs: seconds * 1000,
        );
    await _save(
      item == null
          ? [...m.items, step]
          : m.items.map((v) => v.id == item.id ? step : v).toList(),
    );
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
        if (m.description.isNotEmpty)
          Text(
            m.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Добавить трек'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _interval(),
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Добавить паузу'),
              ),
            ),
          ],
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: m.items.length,
            onReorderItem: (from, to) {
              final list = [...m.items];
              list.insert(to, list.removeAt(from));
              _save(list);
            },
            itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
              key: ValueKey(m.items[i].id),
              index: i,
              child: ListTile(
                dense: true,
                minTileHeight: 52,
                minVerticalPadding: 0,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drag_indicator),
                onTap: m.items[i].kind == StepKind.audio
                    ? null
                    : () => _interval(m.items[i]),
                title: Text(
                  m.items[i].kind == StepKind.audio
                      ? m.items[i].title
                      : 'Пауза',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  m.items[i].durationMs == null
                      ? 'До завершения вручную'
                      : formatDuration(m.items[i].durationMs!),
                ),
                trailing: IconButton(
                  tooltip: 'Удалить ссылку из модуля',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _save([...m.items]..removeAt(i)),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
