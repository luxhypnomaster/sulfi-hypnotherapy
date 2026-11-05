import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../models/plan_duration.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import '../services/library_service.dart';
import '../services/session_audio_handler.dart';
import 'design.dart';
import 'structure_shell.dart';
import 'structure_item_row.dart';
import 'structure_unsaved.dart';
import 'session_actions.dart';
import 'library_screen.dart';
import 'recorder_screen.dart';
import 'pause_time_picker.dart';

class ModuleEditor extends StatefulWidget {
  const ModuleEditor({
    super.key,
    required this.controller,
    required this.player,
    this.module,
    this.instance,
    this.phaseId,
  }) : assert((module == null) != (instance == null));
  final SessionController controller;
  final PreviewPlayer player;
  final ModuleDefinition? module;
  final PhaseChild? instance;
  final String? phaseId;
  @override
  State<ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends State<ModuleEditor> {
  late String name = widget.module?.title ?? widget.instance!.title;
  late String description =
      widget.module?.description ?? widget.instance!.description;
  late List<SessionStep> items = List.of(
    widget.module?.items ?? widget.instance!.items,
  );
  bool busy = false, allowPop = false;
  String token() => jsonEncode({
    'name': name,
    'description': description,
    'items': items.map((s) => s.toMap()).toList(),
  });
  late final String baseline;
  @override
  void initState() {
    super.initState();
    baseline = token();
  }

  bool get dirty => token() != baseline;
  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    await showActionError(context, f);
    if (mounted) setState(() => busy = false);
  }

  void changed(List<SessionStep> next) => setState(() => items = next);
  Future<void> close() async {
    if (busy) return;
    if (dirty) {
      final action = await askStructureExit(context);
      if (action == StructureExit.stay || !mounted) return;
      if (action == StructureExit.apply) {
        await run(apply);
        return;
      }
    }
    finish(false);
  }

  void finish(bool applied) {
    setState(() => allowPop = true);
    if (Navigator.canPop(context)) Navigator.pop(context, applied);
  }

  Future<void> apply({bool archive = false}) async {
    final c = widget.controller;
    if (name.trim().isEmpty) {
      throw const LibraryException('Введите название модуля');
    }
    if (items.map((s) => s.id).toSet().length != items.length) {
      throw const LibraryException('Повторяется ID элемента');
    }
    if (widget.module case final ModuleDefinition old) {
      await c.modules.load();
      final existing = c.modules.entries
          .where((m) => m.id == old.id)
          .firstOrNull;
      if (existing == null || existing.version != old.version) {
        throw const LibraryException(
          'Определение изменилось. Закройте редактор и откройте его снова.',
        );
      }
      await c.modules.save(
        ModuleDefinition(
          id: old.id,
          title: name.trim(),
          description: description,
          tags: old.tags,
          recommendedPhaseIds: old.recommendedPhaseIds,
          version: old.version + 1,
          archived: archive || old.archived,
          items: items,
        ),
      );
    } else {
      final phase = modularize(c.draft.plan).phases!
          .where((p) => p.id == widget.phaseId)
          .firstOrNull;
      final current = phase?.children
          .where((m) => m.id == widget.instance!.id)
          .firstOrNull;
      if (current == null ||
          jsonEncode(current.toMap()) != jsonEncode(widget.instance!.toMap())) {
        throw const LibraryException(
          'Экземпляр изменился. Откройте его снова.',
        );
      }
      await c.updateChild(
        phase!.id,
        current.copyWith(
          title: name.trim(),
          description: description,
          items: items,
        ),
      );
    }
    if (mounted) finish(true);
  }

  Future<void> metadata() async {
    final d = await askDetails(
      context,
      title: 'Параметры модуля',
      name: name,
      description: description,
    );
    if (d != null && mounted) {
      setState(() {
        name = d.name;
        description = d.description;
      });
    }
  }

  Future<void> addAudio({bool record = false}) async {
    final c = widget.controller;
    await widget.player.stop();
    if (!mounted) return;
    void insert(AudioAsset a) => changed([
      ...items,
      SessionStep(
        id: newId(),
        kind: StepKind.audio,
        title: a.title,
        description: a.description,
        audioAssetId: a.id,
        durationMs: a.durationMs,
        groupId: widget.phaseId,
      ),
    ]);
    if (record) {
      final a = await Navigator.push<AudioAsset>(
        context,
        MaterialPageRoute(
          builder: (_) => RecorderScreen(controller: c, player: widget.player),
        ),
      );
      if (a != null && mounted) insert(a);
    } else {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LibraryScreen(
            library: c.library,
            controller: c,
            player: widget.player,
            allowSelection: true,
            onSelected: (a) async {
              insert(a);
            },
          ),
        ),
      );
    }
    await c.reload();
  }

  Future<void> pause(SessionStep? item, {bool before = false}) async {
    final seconds = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => PauseTimePicker(
          initialSeconds: before
              ? item!.delayBeforeSeconds
              : (item?.durationMs ?? 0) ~/ 1000,
          manualEnd: !before && item != null && item.durationMs == null,
        ),
      ),
    );
    if (seconds == null || !mounted) return;
    final next = item == null
        ? SessionStep(
            id: newId(),
            kind: StepKind.silence,
            title: 'Пауза',
            durationMs: seconds * 1000,
            groupId: widget.phaseId,
          )
        : before
        ? item.copyWith(delayBeforeSeconds: seconds)
        : item.copyWith(
            durationMs: seconds < 0 ? null : seconds * 1000,
            indefinite: seconds < 0,
          );
    changed(
      item == null
          ? [...items, next]
          : items.map((s) => s.id == item.id ? next : s).toList(),
    );
  }

  Future<void> addMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in [
              ('audio', Icons.library_music, 'Трек из библиотеки'),
              ('pause', Icons.pause_circle_outline, 'Добавить паузу'),
              ('record', Icons.mic_none, 'Записать свой трек'),
            ])
              ListTile(
                leading: Icon(p.$2),
                title: Text(p.$3),
                onTap: () => Navigator.pop(context, p.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'audio') await addAudio();
    if (action == 'pause') await pause(null);
    if (action == 'record') await addAudio(record: true);
  }

  Future<void> preview(SessionStep s) async {
    if (sessionAudioHandler?.engine?.active ?? false) {
      throw const LibraryException('Сначала завершите активную сессию');
    }
    final a = widget.controller.asset(s.audioAssetId);
    if (a == null) throw const LibraryException('Аудиофайл недоступен');
    await widget.player.toggle(a, widget.controller.library.fileFor(a));
  }

  Widget menu(SessionStep s, int index) => PopupMenuButton<String>(
    tooltip: 'Действия элемента',
    enabled: !busy,
    onSelected: (value) => run(() async {
      if (value == 'delete') {
        changed([...items]..removeAt(index));
      }
      if (value == 'repeat') {
        final next = [...items];
        next.insert(index + 1, s.copyWith(id: newId()));
        changed(next);
      }
      if (value == 'toggle') {
        changed(
          items
              .map((v) => v.id == s.id ? s.copyWith(enabled: !s.enabled) : v)
              .toList(),
        );
      }
      if (value == 'before') await pause(s, before: true);
      if (value == 'duration') await pause(s);
      if (value == 'name') {
        if (!mounted) return;
        final d = await askDetails(
          context,
          title: 'Параметры элемента',
          name: s.title,
          description: s.description,
        );
        if (d != null && mounted) {
          changed(
            items
                .map(
                  (v) => v.id == s.id
                      ? s.copyWith(title: d.name, description: d.description)
                      : v,
                )
                .toList(),
          );
        }
      }
      if (value == 'up' && index > 0) {
        final next = [...items];
        next.insert(index - 1, next.removeAt(index));
        changed(next);
      }
      if (value == 'down' && index < items.length - 1) {
        final next = [...items];
        next.insert(index + 1, next.removeAt(index));
        changed(next);
      }
    }),
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'name', child: Text('Название и описание')),
      if (s.kind == StepKind.audio)
        const PopupMenuItem(value: 'before', child: Text('Пауза перед треком')),
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
      PopupMenuItem(value: 'up', enabled: index > 0, child: const Text('Выше')),
      PopupMenuItem(
        value: 'down',
        enabled: index < items.length - 1,
        child: const Text('Ниже'),
      ),
      PopupMenuItem(
        value: 'toggle',
        child: Text(s.enabled ? 'Выключить' : 'Включить'),
      ),
      const PopupMenuItem(value: 'repeat', child: Text('Повторить элемент')),
      const PopupMenuItem(
        value: 'delete',
        child: Text('Удалить ссылку из модуля'),
      ),
    ],
  );
  @override
  void dispose() {
    unawaited(Future.microtask(widget.player.stop));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(close());
    },
    child: StructureShell(
      title: name,
      onBack: close,
      summary: Row(
        children: [
          Expanded(
            child: Semantics(
              label: PlanDuration.steps(items).semantics,
              child: Text(
                '${items.length} элементов • ${PlanDuration.steps(items).label}',
                style: const TextStyle(color: neonLime, fontSize: 13),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Название и описание',
            onPressed: busy ? null : metadata,
            icon: const Icon(Icons.edit_outlined, color: neonPink),
          ),
          if (widget.module != null)
            IconButton(
              tooltip: 'Архивировать модуль',
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (await confirmAction(
                        context,
                        'Архивировать модуль?',
                        'Применённые экземпляры и аудиофайлы сохранятся.',
                        confirm: 'В архив',
                      )) {
                        await apply(archive: true);
                      }
                    }),
              icon: const Icon(Icons.archive_outlined, color: neonPink),
            ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: StructureFooterButton(
              label: 'Отмена',
              onPressed: busy ? null : close,
            ),
          ),
          Expanded(
            child: StructureFooterButton(
              label: 'Применить',
              primary: true,
              onPressed: busy ? null : () => run(apply),
            ),
          ),
        ],
      ),
      child: ReorderableListView.builder(
        key: const Key('module-items'),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorderItem: (from, to) {
          final next = [...items];
          next.insert(to, next.removeAt(from));
          changed(next);
        },
        itemBuilder: (context, i) {
          final s = items[i];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(s.id),
            index: i,
            enabled: !busy,
            child: StructureItemRow(
              step: s,
              handle: ReorderableDragStartListener(
                index: i,
                enabled: !busy,
                child: SizedBox(
                  key: ValueKey('drag-${s.id}'),
                  width: 32,
                  height: 48,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: neonPink,
                  ),
                ),
              ),
              menu: menu(s, i),
              onPause: busy ? null : () => run(() => pause(s, before: true)),
              onPreview: busy ? null : () => run(() => preview(s)),
              onDuration: busy ? null : () => run(() => pause(s)),
            ),
          );
        },
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : () => run(addMenu),
            icon: const Icon(Icons.add, color: neonLime),
            label: const Text('Добавить', style: TextStyle(color: neonLime)),
          ),
        ),
      ),
    ),
  );
}
