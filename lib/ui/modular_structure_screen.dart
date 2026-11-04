import 'package:flutter/material.dart';

import 'dart:async';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../models/modular_plan.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'modules_screen.dart';
import 'library_screen.dart';
import 'recorder_screen.dart';
import 'pause_editor.dart';
import 'pause_time_picker.dart';
import 'session_actions.dart';
import 'templates_screen.dart';

class ModularStructureScreen extends StatefulWidget {
  const ModularStructureScreen({
    super.key,
    required this.controller,
    required this.player,
  });
  final SessionController controller;
  final PreviewPlayer player;
  @override
  State<ModularStructureScreen> createState() => _ModularStructureScreenState();
}

class _ModularStructureScreenState extends State<ModularStructureScreen> {
  SessionController get c => widget.controller;
  final Set<String> _collapsed = {};
  bool _open(String id) => !_collapsed.contains(id);
  void _toggle(String id) => setState(() {
    if (!_collapsed.remove(id)) _collapsed.add(id);
  });
  @override
  void dispose() {
    unawaited(Future.microtask(widget.player.stop));
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) => showActionError(context, f);
  Future<void> _addPhase([PhaseType? type]) async {
    final selected =
        type ??
        await showDialog<PhaseType>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Добавить фазу'),
            children: phaseTypes
                .map(
                  (p) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, p),
                    child: ListTile(
                      title: Text(p.title),
                      subtitle: Text(p.description),
                    ),
                  ),
                )
                .toList(),
          ),
        );
    if (selected != null) await c.createPhase(selected.id);
  }

  Future<void> _audio(
    PhaseInstance phase, {
    PhaseChild? child,
    bool record = false,
  }) async {
    await widget.player.stop();
    if (!mounted) return;
    Future<void> add(AudioAsset asset) => c.addLoose(
      phase.id,
      SessionStep(
        id: newId(),
        kind: StepKind.audio,
        title: asset.title,
        description: asset.description,
        audioAssetId: asset.id,
        durationMs: asset.durationMs,
      ),
      childId: child?.id,
    );
    if (!record) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LibraryScreen(
            library: c.library,
            controller: c,
            player: widget.player,
            allowSelection: true,
            onSelected: add,
          ),
        ),
      );
    } else {
      final asset = await Navigator.push<AudioAsset>(
        context,
        MaterialPageRoute(
          builder: (_) => RecorderScreen(controller: c, player: widget.player),
        ),
      );
      if (asset != null) await add(asset);
    }
    await c.reload();
  }

  Future<void> _module(PhaseInstance phase) async {
    await c.modules.load();
    if (!mounted) return;
    final m = await Navigator.push<ModuleDefinition>(
      context,
      MaterialPageRoute(
        builder: (_) => ModulesScreen(
          controller: c,
          player: widget.player,
          selecting: true,
        ),
      ),
    );
    if (m != null) await c.addModule(phase.id, m);
  }

  Future<void> _interval(PhaseInstance phase, {PhaseChild? child}) async {
    final seconds = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const PauseTimePicker()),
    );
    if (seconds == null) return;
    await c.addLoose(
      phase.id,
      SessionStep(
        id: newId(),
        kind: StepKind.silence,
        title: 'Пауза',
        durationMs: seconds * 1000,
      ),
      childId: child?.id,
    );
  }

  Future<void> _alternative(PhaseInstance phase, PhaseChild current) async {
    final selected = await Navigator.push<ModuleDefinition>(
      context,
      MaterialPageRoute(
        builder: (_) => ModulesScreen(
          controller: c,
          player: widget.player,
          selecting: true,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Применить выбранный модуль'),
        content: const Text(
          'Заменить текущий экземпляр с его правками или добавить ещё один?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Добавить ещё один'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
    if (action == 'add') await c.addModule(phase.id, selected);
    if (action == 'replace') {
      final fresh = selected.instantiate(phase.id);
      await c.updateChild(
        phase.id,
        PhaseChild(
          id: current.id,
          title: fresh.title,
          definitionId: fresh.definitionId,
          definitionVersion: fresh.definitionVersion,
          baseFingerprint: fresh.baseFingerprint,
          items: fresh.items,
        ),
      );
    }
  }

  Future<void> _duration(SessionStep item) async {
    final seconds = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PauseTimePicker(
          initialSeconds: (item.durationMs ?? 0) ~/ 1000,
          manualEnd: item.durationMs == null,
        ),
      ),
    );
    if (seconds != null) {
      await c.updateStep(
        item.copyWith(
          durationMs: seconds < 0 ? null : seconds * 1000,
          indefinite: seconds < 0,
        ),
      );
    }
  }

  Future<void> _replace(SessionStep item) async {
    final a = await Navigator.push<AudioAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          library: c.library,
          controller: c,
          player: widget.player,
          allowSelection: true,
        ),
      ),
    );
    await c.reload();
    if (a != null) {
      await c.updateStep(
        item.copyWith(
          audioAssetId: a.id,
          title: a.title,
          description: a.description,
          durationMs: a.durationMs,
        ),
      );
    }
  }

  Future<void> _move(SessionStep item) async {
    final phases = modularize(c.draft.plan).phases!;
    final target = await showDialog<({String phase, String? child})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Перенести трек / интервал'),
        children: [
          for (final p in phases) ...[
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, (phase: p.id, child: null)),
              child: Text('${p.title} · отдельно'),
            ),
            for (final child in p.children.where((c) => c.isModule))
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, (phase: p.id, child: child.id)),
                child: Text('${p.title} → ${child.title}'),
              ),
          ],
        ],
      ),
    );
    if (target == null) return;
    await c.changePhases(
      (ps) => ps.map((p) {
        final cleaned = p.children
            .map(
              (c) => c.copyWith(
                items: c.items.where((s) => s.id != item.id).toList(),
              ),
            )
            .toList();
        if (p.id != target.phase) return p.copyWith(children: cleaned);
        final moved = item.copyWith(groupId: p.id);
        return p.copyWith(
          children: target.child == null
              ? [
                  ...cleaned,
                  PhaseChild(id: newId(), title: moved.title, items: [moved]),
                ]
              : cleaned
                    .map(
                      (c) => c.id == target.child
                          ? c.copyWith(items: [...c.items, moved])
                          : c,
                    )
                    .toList(),
        );
      }).toList(),
    );
  }

  Future<void> _templates() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatesScreen(
          controller: c,
          player: widget.player,
          selecting: true,
        ),
      ),
    );
    await c.reload();
  }

  Future<void> _addMenu(PhaseInstance p, {PhaseChild? child}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (child == null)
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Модуль'),
                onTap: () => Navigator.pop(context, 'module'),
              ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('Трек из библиотеки'),
              onTap: () => Navigator.pop(context, 'audio'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Добавить паузу'),
              onTap: () => Navigator.pop(context, 'pause'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Записать свой трек'),
              onTap: () => Navigator.pop(context, 'record'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    await _run(() async {
      if (action == 'module') await _module(p);
      if (action == 'audio') await _audio(p, child: child);
      if (action == 'pause') await _interval(p, child: child);
      if (action == 'record') await _audio(p, child: child, record: true);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final plan = modularize(c.draft.plan), phases = plan.phases!;
      // One scrollable/reorder surface: dragging any level retains edge autoscroll.
      final rows =
          <
            ({
              String id,
              String level,
              PhaseInstance phase,
              PhaseChild? child,
              SessionStep? step,
            })
          >[];
      for (final p in phases) {
        rows.add((id: p.id, level: 'phase', phase: p, child: null, step: null));
        if (!_open(p.id)) continue;
        rows.add((
          id: 'actions-${p.id}',
          level: 'actions',
          phase: p,
          child: null,
          step: null,
        ));
        for (final child in p.children) {
          if (child.isModule) {
            rows.add((
              id: child.id,
              level: 'module',
              phase: p,
              child: child,
              step: null,
            ));
            if (!_open(child.id)) continue;
            rows.add((
              id: 'actions-${child.id}',
              level: 'actions',
              phase: p,
              child: child,
              step: null,
            ));
          }
          for (final step in child.items) {
            rows.add((
              id: step.id,
              level: child.isModule ? 'item' : 'loose',
              phase: p,
              child: child,
              step: step,
            ));
          }
        }
      }
      return LeatherScaffold(
        title: 'Структура сессии',
        bottom: Row(
          key: const Key('structure-footer'),
          children: [
            Expanded(
              child: Tooltip(
                message: 'Выбрать другой шаблон',
                child: TextButton(
                  onPressed: _templates,
                  child: const Text('Выбрать'),
                ),
              ),
            ),
            Expanded(
              child: Tooltip(
                message: 'Сохранить как шаблон',
                child: TextButton(
                  onPressed: () => _run(() async {
                    await saveTemplateDialog(context, c);
                  }),
                  child: const Text('Сохранить'),
                ),
              ),
            ),
            Expanded(
              child: Tooltip(
                message: 'Применить изменения и вернуться',
                child: FilledButton(
                  onPressed: () => _run(() async {
                    await c.flush();
                    if (c.saveError == null && context.mounted) {
                      Navigator.pop(context);
                    }
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: neonLime,
                    foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text('Применить'),
                ),
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '${phases.length} фаз · ${plan.steps.length} элементов · ${formatDuration(plan.totalMs)}',
              style: const TextStyle(fontSize: 11, color: antiqueGold),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _run(_addPhase),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить фазу'),
                  ),
                ),
                IconButton(
                  tooltip: 'Каталог модулей',
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ModulesScreen(controller: c, player: widget.player),
                    ),
                  ),
                  icon: const Icon(Icons.layers_outlined),
                ),
              ],
            ),
            Expanded(
              child: phases.isEmpty
                  ? ListView(
                      children: [
                        for (final type in phaseTypes)
                          ListTile(
                            title: Text(type.title),
                            subtitle: Text(type.description),
                            trailing: const Icon(Icons.add),
                            onTap: () => _run(() => _addPhase(type)),
                          ),
                      ],
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorderItem: (from, to) => _run(() async {
                        final source = rows[from];
                        final destination = rows[to.clamp(0, rows.length - 1)];
                        if (source.level == 'phase') {
                          final list = [...phases];
                          final a = list.indexWhere(
                            (p) => p.id == source.phase.id,
                          );
                          final b = list.indexWhere(
                            (p) => p.id == destination.phase.id,
                          );
                          if (a == b) return;
                          list.insert(b, list.removeAt(a));
                          await c.changePhases((_) => list);
                        } else if ((source.level == 'module' ||
                            source.level == 'loose')) {
                          final list = [...source.phase.children];
                          final a = list.indexWhere(
                            (v) => v.id == source.child!.id,
                          );
                          final b =
                              source.phase.id == destination.phase.id &&
                                  destination.child != null
                              ? list.indexWhere(
                                  (v) => v.id == destination.child!.id,
                                )
                              : (to > from ? list.length - 1 : 0);
                          if (a < 0 || b < 0 || a == b) return;
                          list.insert(b, list.removeAt(a));
                          await c.updatePhase(
                            source.phase.copyWith(children: list),
                          );
                        } else if (source.level == 'item') {
                          final list = [...source.child!.items];
                          final a = list.indexWhere((v) => v.id == source.id);
                          final b =
                              source.child?.id == destination.child?.id &&
                                  destination.step != null
                              ? list.indexWhere((v) => v.id == destination.id)
                              : (to > from ? list.length - 1 : 0);
                          if (a < 0 || b < 0 || a == b) return;
                          list.insert(b, list.removeAt(a));
                          await c.updateChild(
                            source.phase.id,
                            source.child!.copyWith(items: list),
                          );
                        }
                      }),
                      itemBuilder: (context, i) {
                        final row = rows[i], p = row.phase, child = row.child;
                        Widget content;
                        if (row.level == 'phase' || row.level == 'module') {
                          final id = child?.id ?? p.id;
                          final title = child == null
                              ? '${phases.indexOf(p) + 1}. ${p.title}'
                              : child.title;
                          content = Material(
                            color: child == null
                                ? const Color(0xFF321023)
                                : const Color(0xFF1A0D15),
                            child: InkWell(
                              onTap: () => _toggle(id),
                              child: Row(
                                children: [
                                  ReorderableDelayedDragStartListener(
                                    index: i,
                                    child: SizedBox(
                                      key: ValueKey('drag-$id'),
                                      width: 44,
                                      height: 48,
                                      child: const ColoredBox(
                                        color: Colors.transparent,
                                        child: Icon(
                                          Icons.drag_indicator,
                                          size: 18,
                                          color: antiqueGold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: child == null ? 14 : 13,
                                        color: (child?.enabled ?? p.enabled)
                                            ? null
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: ValueKey('expand-$id'),
                                    tooltip: _open(id)
                                        ? 'Свернуть'
                                        : 'Раскрыть',
                                    onPressed: () => _toggle(id),
                                    icon: Icon(
                                      _open(id) ? Icons.remove : Icons.add,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else if (row.level == 'actions') {
                          content = Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _addMenu(p, child: child),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Добавить'),
                                  ),
                                ),
                              ),
                              child == null
                                  ? _phaseMenu(p)
                                  : _childMenu(p, child),
                            ],
                          );
                        } else {
                          content = _item(p, child!, row.step!);
                        }
                        if (row.level == 'item' || row.level == 'loose') {
                          content = ReorderableDelayedDragStartListener(
                            index: i,
                            child: content,
                          );
                        }
                        return Container(key: ValueKey(row.id), child: content);
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _phaseMenu(PhaseInstance p) => PopupMenuButton<String>(
    onSelected: (v) => _run(() async {
      if (v == 'toggle') {
        await c.updatePhase(p.copyWith(enabled: !p.enabled));
      }
      if (v == 'rename' && mounted) {
        final d = await askDetails(
          context,
          title: 'Название фазы',
          name: p.title,
        );
        if (d != null) await c.updatePhase(p.copyWith(title: d.name));
      }
      if (v == 'delete' &&
          mounted &&
          await confirmAction(
            context,
            'Удалить фазу?',
            'Её содержимое удалится только из текущего черновика.',
            confirm: 'Удалить',
          )) {
        await c.changePhases((ps) => ps.where((v) => v.id != p.id).toList());
      }
    }),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'toggle',
        child: Text(p.enabled ? 'Выключить фазу' : 'Включить фазу'),
      ),
      const PopupMenuItem(value: 'rename', child: Text('Переименовать фазу')),
      const PopupMenuItem(value: 'delete', child: Text('Удалить фазу')),
    ],
  );
  Widget _childMenu(PhaseInstance p, PhaseChild child) =>
      PopupMenuButton<String>(
        onSelected: (v) => _run(() async {
          if (v == 'alternative') await _alternative(p, child);
          if (v == 'toggle') {
            await c.updateChild(p.id, child.copyWith(enabled: !child.enabled));
          }
          if (v == 'remove' &&
              mounted &&
              await confirmAction(
                context,
                'Удалить экземпляр модуля?',
                'Каталог и файлы останутся.',
                confirm: 'Удалить',
              )) {
            await c.removeChild(p.id, child.id);
          }
          if (v == 'restore') {
            final d = c.modules.entries
                .where((m) => m.id == child.definitionId)
                .firstOrNull;
            if (d != null &&
                mounted &&
                await confirmAction(
                  context,
                  'Вернуть исходный состав модуля?',
                  'Локальные правки экземпляра будут заменены.',
                  confirm: 'Вернуть',
                )) {
              final replacement = d.instantiate(p.id);
              await c.updateChild(
                p.id,
                PhaseChild(
                  id: child.id,
                  title: replacement.title,
                  definitionId: replacement.definitionId,
                  definitionVersion: replacement.definitionVersion,
                  baseFingerprint: replacement.baseFingerprint,
                  items: replacement.items,
                ),
              );
            }
          }
        }),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'toggle',
            child: Text(child.enabled ? 'Выключить модуль' : 'Включить модуль'),
          ),
          const PopupMenuItem(
            value: 'alternative',
            child: Text('Выбрать другой модуль'),
          ),
          const PopupMenuItem(
            value: 'restore',
            child: Text('Вернуть исходный состав модуля'),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Удалить экземпляр'),
          ),
        ],
      );

  Widget _item(PhaseInstance p, PhaseChild child, SessionStep s) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 3),
    minVerticalPadding: 0,
    dense: true,
    minTileHeight: 52,
    leading: TextButton(
      key: Key('pause-${s.id}'),
      style: TextButton.styleFrom(
        foregroundColor: neonLime,
        padding: const EdgeInsets.symmetric(horizontal: 3),
      ),
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PauseEditor(controller: c, stepId: s.id, player: widget.player),
        ),
      ),
      child: Text(formatPause(s.delayBeforeSeconds)),
    ),
    title: Text(
      '${s.enabled ? '' : '○ '}${s.kind == StepKind.audio ? s.title : 'Пауза'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    ),
    subtitle: Text(
      '${s.kind.label} · ${s.durationMs == null ? 'до завершения' : formatDuration(s.durationMs!)}',
      style: const TextStyle(fontSize: 10, color: antiqueGold),
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (v) => _run(() async {
        if (v == 'toggle') await c.updateStep(s.copyWith(enabled: !s.enabled));
        if (v == 'move') await _move(s);
        if (v == 'duration') await _duration(s);
        if (v == 'replace') await _replace(s);
        if (v == 'repeat') {
          final list = [...child.items];
          list.insert(
            list.indexWhere((i) => i.id == s.id) + 1,
            s.copyWith(id: newId()),
          );
          await c.updateChild(p.id, child.copyWith(items: list));
        }
        if (v == 'preview') {
          final a = c.asset(s.audioAssetId);
          if (a != null) await widget.player.toggle(a, c.library.fileFor(a));
        }
        if (v == 'delete' &&
            mounted &&
            await confirmAction(
              context,
              'Удалить элемент?',
              'Аудиофайл в библиотеке останется.',
              confirm: 'Удалить',
            )) {
          await c.remove(s.id);
        }
        if (v == 'edit' && mounted) {
          final d = await askDetails(
            context,
            title: 'Параметры элемента',
            name: s.title,
            description: s.description,
          );
          if (d != null) {
            await c.updateStep(
              s.copyWith(title: d.name, description: d.description),
            );
          }
        }
      }),
      itemBuilder: (_) => [
        if (s.kind == StepKind.audio)
          const PopupMenuItem(value: 'preview', child: Text('Прослушать')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(s.enabled ? 'Выключить' : 'Включить'),
        ),
        if (s.kind == StepKind.audio)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Название и описание'),
          ),
        if (s.kind == StepKind.audio)
          const PopupMenuItem(value: 'replace', child: Text('Заменить трек')),
        if (s.kind != StepKind.audio)
          const PopupMenuItem(
            value: 'duration',
            child: Text('Изменить длительность'),
          ),
        const PopupMenuItem(value: 'repeat', child: Text('Повторить элемент')),
        const PopupMenuItem(
          value: 'move',
          child: Text('Перенести в фазу / модуль'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
    ),
  );
}
