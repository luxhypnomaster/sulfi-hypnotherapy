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
import '../models/plan_duration.dart';
import '../models/structure_rows.dart';
import '../services/library_service.dart';
import '../services/session_audio_handler.dart';
import 'module_editor.dart';
import 'structure_shell.dart';
import 'structure_item_row.dart';
import 'structure_unsaved.dart';

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
  SessionController? _working;
  SessionController get c => _working!;
  final ScrollController _scroll = ScrollController();
  bool _owns = false, _busy = false, _allowPop = false;
  String? _loadError, _selected;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final work = widget.controller.isEditor
          ? widget.controller
          : await widget.controller.beginEditing();
      if (!mounted) {
        if (!widget.controller.isEditor) work.dispose();
        return;
      }
      setState(() {
        _working = work;
        _owns = !widget.controller.isEditor;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError =
              'Не удалось открыть редактор. Текущая конфигурация сохранена.',
        );
      }
    }
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_working != null) {
      await c.flush();
      if (c.hasEditorChanges && mounted) {
        final action = await askStructureExit(context);
        if (!mounted || action == StructureExit.stay) return;
        if (action == StructureExit.apply) {
          await _run(_apply);
          return;
        }
      }
    }
    _finish(false);
  }

  void _finish(bool applied) {
    setState(() => _allowPop = true);
    if (Navigator.canPop(context)) Navigator.pop(context, applied);
  }

  Future<void> _apply() async {
    await c.flush();
    if (!mounted || !await warnMissingPlanAudio(context, c, c.draft.plan)) {
      return;
    }
    await c.applyEditor();
    if (mounted) _finish(true);
  }

  Future<void> _editModule(PhaseInstance p, PhaseChild child) async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleEditor(
          controller: c,
          player: widget.player,
          phaseId: p.id,
          instance: child,
        ),
      ),
    );
    await c.reload();
  }

  Future<void> _preview(SessionStep s) async {
    if (sessionAudioHandler?.engine?.active ?? false) {
      throw const LibraryException('Сначала завершите активную сессию');
    }
    final a = c.asset(s.audioAssetId);
    if (a == null) throw const LibraryException('Аудиофайл недоступен');
    await widget.player.toggle(a, c.library.fileFor(a));
  }

  final Set<String> _collapsed = {};
  bool _open(String id) => !_collapsed.contains(id);
  void _toggle(String id) => setState(() {
    _selected = id;
    if (!_collapsed.remove(id)) _collapsed.add(id);
  });
  @override
  void dispose() {
    unawaited(Future.microtask(widget.player.stop));
    if (_owns) _working?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showActionError(context, f);
    if (mounted) setState(() => _busy = false);
  }

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
  Widget build(BuildContext context) {
    if (_working == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _loadError == null
                ? const CircularProgressIndicator()
                : TextButton(onPressed: _initialize, child: Text(_loadError!)),
          ),
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final plan = modularize(c.draft.plan),
              phases = plan.phases!,
              rows = structureRows(phases, _collapsed);
          final duration = PlanDuration.plan(plan);
          return StructureShell(
            title: 'Структура сессии',
            onBack: _back,
            summary: Semantics(
              label: '${phases.length} фаз. ${duration.semantics}',
              child: Text(
                structureSummary(plan),
                key: const Key('structure-summary'),
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ),
            footer: Row(
              key: const Key('structure-footer'),
              children: [
                Expanded(
                  child: StructureFooterButton(
                    label: 'Добавить\nфазу',
                    add: true,
                    onPressed: _busy ? null : () => _run(_addPhase),
                  ),
                ),
                Expanded(
                  child: StructureFooterButton(
                    label: 'Выбрать\nшаблон',
                    onPressed: _busy ? null : () => _run(_templates),
                  ),
                ),
                Expanded(
                  child: StructureFooterButton(
                    label: 'Сохранить\nшаблон',
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final saved = await saveTemplateDialog(context, c);
                            if (saved != null) await c.loadTemplate(saved);
                          }),
                  ),
                ),
                Expanded(
                  child: StructureFooterButton(
                    label: 'Применить',
                    primary: true,
                    onPressed: _busy ? null : () => _run(_apply),
                  ),
                ),
              ],
            ),
            child: phases.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Добавьте фазу, затем модуль, треки и паузы.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    key: const Key('structure-list'),
                    scrollController: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    buildDefaultDragHandles: false,
                    itemCount: rows.length,
                    onReorderStart: (index) {
                      final row = rows[index];
                      if (row.level == StructureLevel.phase ||
                          row.level == StructureLevel.module) {
                        setState(() => _collapsed.add(row.id));
                      }
                    },
                    onReorderItem: (from, to) => _run(
                      () => c.changePhases(
                        (current) => reorderStructure(current, rows, from, to),
                      ),
                    ),
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 5,
                      child: child,
                    ),
                    itemBuilder: (context, index) =>
                        _row(rows[index], index, phases),
                  ),
          );
        },
      ),
    );
  }

  Widget _handle(int index, String id) => ReorderableDragStartListener(
    index: index,
    enabled: !_busy,
    child: SizedBox(
      key: ValueKey('drag-$id'),
      width: 32,
      height: 48,
      child: const Icon(Icons.drag_indicator, color: neonPink, size: 18),
    ),
  );
  Widget _row(StructureRow row, int index, List<PhaseInstance> phases) {
    final p = row.phase, child = row.child;
    final phase = row.level == StructureLevel.phase,
        module = row.level == StructureLevel.module;
    final moduleBody =
        row.level == StructureLevel.item ||
        row.level == StructureLevel.addModuleItem;
    final add =
        row.level == StructureLevel.addPhaseChild ||
        row.level == StructureLevel.addModuleItem;
    Widget content;
    if (phase || module) {
      final duration = phase
          ? PlanDuration.phase(p)
          : PlanDuration.child(child!);
      final id = phase ? p.id : child!.id, open = _open(row.id);
      final enabled = phase ? p.enabled : child!.enabled;
      content = Material(
        color: phase ? const Color(0xFF35091F) : const Color(0xFF260A19),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(
            color: phase ? neonPink : const Color(0xFFC2809F),
            width: phase ? 1.2 : .8,
          ),
        ),
        child: InkWell(
          onTap: _busy ? null : () => _toggle(id),
          borderRadius: BorderRadius.circular(9),
          child: Row(
            children: [
              _handle(index, id),
              if (phase)
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selected == id || open
                          ? neonLime
                          : const Color(0xFFDDB5C8),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${phases.indexWhere((v) => v.id == p.id) + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        color: open ? neonLime : null,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(
                  width: 27,
                  child: Icon(
                    Icons.layers_outlined,
                    color: antiqueGold,
                    size: 23,
                  ),
                ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  phase ? p.title : child!.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: phase ? 16 : 14,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: !enabled
                        ? Colors.grey
                        : phase && open
                        ? neonLime
                        : const Color(0xFFF9EAF2),
                  ),
                ),
              ),
              if (open) phase ? _phaseMenu(p) : _childMenu(p, child!),
              Semantics(
                label: duration.semantics,
                child: Text(
                  duration.label,
                  key: ValueKey('duration-$id'),
                  style: TextStyle(
                    fontSize: phase ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('expand-$id'),
                tooltip: open ? 'Свернуть' : 'Раскрыть',
                onPressed: _busy ? null : () => _toggle(id),
                icon: Icon(
                  open ? Icons.remove : Icons.add,
                  color: neonPink,
                  size: 23,
                ),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: neonPink),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (add) {
      content = Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _addMenu(p, child: moduleBody ? child : null),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            side: const BorderSide(color: neonLime),
            foregroundColor: neonLime,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить', style: TextStyle(fontSize: 13)),
        ),
      );
    } else {
      content = _item(p, child!, row.step!, _handle(index, row.id));
    }
    if (!add) {
      content = ReorderableDelayedDragStartListener(
        index: index,
        enabled: !_busy,
        child: content,
      );
    }
    if (!phase) {
      final inside = module || moduleBody;
      content = Container(
        margin: const EdgeInsets.only(left: 8),
        padding: EdgeInsets.only(
          left: inside ? 7 : 3,
          right: 3,
          top: module ? 7 : 2,
          bottom: row.level == StructureLevel.addPhaseChild ? 10 : 2,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: neonPink.withValues(alpha: .55)),
            right: BorderSide(color: neonPink.withValues(alpha: .55)),
            bottom: row.level == StructureLevel.addPhaseChild
                ? const BorderSide(color: neonPink)
                : BorderSide.none,
          ),
        ),
        child: inside
            ? Container(
                margin: const EdgeInsets.only(left: 5),
                padding: const EdgeInsets.only(left: 3, right: 2),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFFDB9DAE).withValues(alpha: .6),
                    ),
                    bottom: row.level == StructureLevel.addModuleItem
                        ? const BorderSide(color: Color(0xFFDB9DAE))
                        : BorderSide.none,
                  ),
                ),
                child: content,
              )
            : content,
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.only(top: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: neonPink.withValues(alpha: .75)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: neonPink.withValues(alpha: .3), blurRadius: 8),
              BoxShadow(color: neonPink.withValues(alpha: .12), blurRadius: 15),
            ],
          ),
          child: content,
        ),
      );
    }
    return Container(key: ValueKey(row.id), child: content);
  }

  Widget _phaseMenu(PhaseInstance p) => PopupMenuButton<String>(
    key: ValueKey('menu-${p.id}'),
    tooltip: 'Действия фазы',
    enabled: !_busy,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_horiz, color: neonPink),
    iconSize: 20,
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
  Widget _childMenu(
    PhaseInstance p,
    PhaseChild child,
  ) => PopupMenuButton<String>(
    key: ValueKey('menu-${child.id}'),
    tooltip: 'Действия модуля',
    enabled: !_busy,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_horiz, color: neonPink),
    iconSize: 20,
    onSelected: (v) => _run(() async {
      if (v == 'edit') await _editModule(p, child);
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
              description: replacement.description,
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
      const PopupMenuItem(value: 'edit', child: Text('Редактировать модуль')),
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
      const PopupMenuItem(value: 'remove', child: Text('Удалить экземпляр')),
    ],
  );

  Widget _item(
    PhaseInstance p,
    PhaseChild child,
    SessionStep s,
    Widget handle,
  ) => StructureItemRow(
    step: s,
    handle: handle,
    onPause: _busy
        ? null
        : () => _run(() async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PauseEditor(
                  controller: c,
                  stepId: s.id,
                  player: widget.player,
                ),
              ),
            );
          }),
    onPreview: _busy ? null : () => _run(() => _preview(s)),
    onDuration: _busy ? null : () => _run(() => _duration(s)),
    menu: PopupMenuButton<String>(
      key: ValueKey('menu-${s.id}'),
      tooltip: 'Действия элемента',
      enabled: !_busy,
      padding: EdgeInsets.zero,
      iconSize: 20,
      onSelected: (v) => _run(() async {
        if (v == 'before') {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => PauseEditor(
                controller: c,
                stepId: s.id,
                player: widget.player,
              ),
            ),
          );
        }
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
          await _preview(s);
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
            value: 'before',
            child: Text('Пауза перед элементом'),
          ),
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
