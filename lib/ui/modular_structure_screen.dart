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
    final asset = await Navigator.push<AudioAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => record
            ? RecorderScreen(controller: c, player: widget.player)
            : LibraryScreen(
                library: c.library,
                controller: c,
                player: widget.player,
                allowSelection: true,
              ),
      ),
    );
    await c.reload();
    if (asset != null) {
      await c.addLoose(
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
    }
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
    final kind = await showDialog<StepKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Добавить интервал'),
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
      nameLabel: 'Секунды (0 — до завершения вручную)',
    );
    if (value == null) return;
    final seconds = int.tryParse(value.name);
    if (seconds == null || seconds < 0) {
      throw const FormatException('Введите число секунд');
    }
    await c.addLoose(
      phase.id,
      SessionStep(
        id: newId(),
        kind: kind,
        title: kind.label,
        durationMs: seconds == 0 ? null : seconds * 1000,
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
    final v = await askDetails(
      context,
      title: 'Длительность интервала',
      name: '${(item.durationMs ?? 0) ~/ 1000}',
      nameLabel: 'Секунды (0 — до ручного завершения)',
    );
    if (v == null) return;
    final n = int.tryParse(v.name);
    if (n == null || n < 0) throw const FormatException('Введите число секунд');
    await c.updateStep(item.copyWith(durationMs: n * 1000, indefinite: n == 0));
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final plan = modularize(c.draft.plan), phases = plan.phases!;
      return Theme(
        data: Theme.of(context).copyWith(
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 11),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
        child: LeatherScaffold(
          title: 'Структура сессии',
          bottom: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .27,
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LibraryScreen(
                          library: c.library,
                          controller: c,
                          player: widget.player,
                        ),
                      ),
                    ),
                    child: const Text('Библиотека'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push<AudioAsset>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecorderScreen(
                          controller: c,
                          player: widget.player,
                        ),
                      ),
                    ),
                    child: const Text('Записать свой трек'),
                  ),
                  TextButton(
                    onPressed: _templates,
                    child: const Text('Выбрать другой шаблон'),
                  ),
                  TextButton(
                    onPressed: () => _run(() async {
                      await saveTemplateDialog(context, c);
                    }),
                    child: const Text('Сохранить как шаблон'),
                  ),
                  TextButton(
                    onPressed: c.baseTemplate == null
                        ? null
                        : () => _run(() async {
                            if (await confirmAction(
                              context,
                              'Вернуть из шаблона?',
                              'Правки текущей конфигурации будут заменены.',
                              confirm: 'Вернуть',
                            )) {
                              await c.restore();
                            }
                          }),
                    child: const Text('Вернуть из шаблона'),
                  ),
                  NeonButton(
                    label: 'Применить и вернуться',
                    icon: Icons.check,
                    primary: true,
                    compact: true,
                    onPressed: () => _run(() async {
                      await c.flush();
                      if (c.saveError == null && context.mounted) {
                        Navigator.pop(context);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                '${phases.where((p) => p.enabled && p.children.any((c) => c.enabled && c.items.any((s) => s.enabled))).length} фаз · ${phases.where((p) => p.enabled).expand((p) => p.children).where((c) => c.enabled && c.isModule).length} модулей · ${plan.steps.where((s) => s.kind == StepKind.audio).length} треков · ${plan.steps.where((s) => s.kind != StepKind.audio).length} интервалов',
                style: const TextStyle(fontSize: 11),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _run(_addPhase),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить фазу'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ModulesScreen(controller: c, player: widget.player),
                      ),
                    ),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Каталог модулей'),
                  ),
                ],
              ),
              Expanded(
                child: phases.isEmpty
                    ? ListView(
                        children: [
                          const Text(
                            'Добавьте фазу и наполните её своими треками или модулями.',
                          ),
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
                        itemCount: phases.length,
                        onReorderItem: (from, to) => _run(
                          () => c.changePhases((p) {
                            final list = [...p];
                            list.insert(to, list.removeAt(from));
                            return list;
                          }),
                        ),
                        footer: Column(
                          children: [
                            for (final type in phaseTypes.where(
                              (t) => !phases.any((p) => p.typeId == t.id),
                            ))
                              ListTile(
                                title: Text(type.title),
                                trailing: const Icon(Icons.add),
                                onTap: () => _run(() => _addPhase(type)),
                              ),
                          ],
                        ),
                        itemBuilder: (context, i) => _phase(phases[i], i),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _phase(PhaseInstance p, int index) => Card(
    key: ValueKey(p.id),
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        '${index + 1}. Фаза: ${p.title}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        p.enabled
            ? '${p.children.where((c) => c.isModule).length} модулей'
            : 'Выключена',
      ),
      trailing: PopupMenuButton<String>(
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
            await c.changePhases(
              (ps) => ps.where((v) => v.id != p.id).toList(),
            );
          }
        }),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'toggle',
            child: Text(p.enabled ? 'Выключить фазу' : 'Включить фазу'),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: Text('Переименовать фазу'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Удалить фазу')),
        ],
      ),
      children: [
        Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _run(() => _module(p)),
              child: const Text('Добавить модуль'),
            ),
            TextButton(
              onPressed: () => _run(() => _audio(p)),
              child: const Text('Добавить трек из библиотеки'),
            ),
            TextButton(
              onPressed: () => _run(() => _interval(p)),
              child: const Text('Добавить интервал'),
            ),
            TextButton(
              onPressed: () => _run(() => _audio(p, record: true)),
              child: const Text('Записать свой трек'),
            ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: p.children.length,
          onReorderItem: (from, to) => _run(() {
            final list = [...p.children];
            list.insert(to, list.removeAt(from));
            return c.updatePhase(p.copyWith(children: list));
          }),
          itemBuilder: (context, i) => _child(p, p.children[i]),
        ),
      ],
    ),
  );
  Widget _child(PhaseInstance p, PhaseChild child) {
    final items = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: child.items.length,
      onReorderItem: (from, to) => _run(() {
        final list = [...child.items];
        list.insert(to, list.removeAt(from));
        return c.updateChild(p.id, child.copyWith(items: list));
      }),
      itemBuilder: (context, i) => _item(p, child, child.items[i]),
    );
    if (!child.isModule) {
      return Container(key: ValueKey(child.id), child: items);
    }
    return Card(
      key: ValueKey(child.id),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Модуль: ${child.title}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${child.enabled ? '' : 'Выключен · '}${child.modified ? 'Изменён · ' : ''}${child.items.isEmpty ? 'Пустой модуль' : '${child.items.length} элементов'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _run(() async {
            if (v == 'alternative') await _alternative(p, child);
            if (v == 'toggle') {
              await c.updateChild(
                p.id,
                child.copyWith(enabled: !child.enabled),
              );
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
              child: Text(
                child.enabled ? 'Выключить модуль' : 'Включить модуль',
              ),
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
        ),
        children: [
          Wrap(
            children: [
              TextButton(
                onPressed: () => _run(() => _audio(p, child: child)),
                child: const Text('Добавить трек'),
              ),
              TextButton(
                onPressed: () => _run(() => _interval(p, child: child)),
                child: const Text('Добавить интервал'),
              ),
              TextButton(
                onPressed: () =>
                    _run(() => _audio(p, child: child, record: true)),
                child: const Text('Записать свой трек'),
              ),
            ],
          ),
          items,
        ],
      ),
    );
  }

  Widget _item(PhaseInstance p, PhaseChild child, SessionStep s) => ListTile(
    key: ValueKey(s.id),
    contentPadding: const EdgeInsets.symmetric(horizontal: 3),
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
    title: Text('${s.enabled ? '' : '○ '}${s.title}', maxLines: 2),
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
        const PopupMenuItem(value: 'edit', child: Text('Название и описание')),
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
