import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../services/preview_player.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'library_screen.dart';
import 'pause_editor.dart';
import 'preview_bar.dart';
import 'session_actions.dart';
import 'templates_screen.dart';

class StructureScreen extends StatefulWidget {
  const StructureScreen({
    super.key,
    required this.controller,
    required this.player,
  });
  final SessionController controller;
  final PreviewPlayer player;
  @override
  State<StructureScreen> createState() => _StructureScreenState();
}

class _StructureScreenState extends State<StructureScreen> {
  final Set<String?> _collapsed = {};
  bool _busy = false;
  SessionController get c => widget.controller;
  @override
  void dispose() {
    unawaited(Future.microtask(widget.player.stop));
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showActionError(context, f);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add({SessionStep? replace}) => _run(() async {
    await c.flush();
    await widget.player.stop();
    if (!mounted) return;
    final a = await Navigator.push<AudioAsset>(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryScreen(
          library: c.library,
          player: widget.player,
          allowSelection: true,
        ),
      ),
    );
    await c.reload();
    if (a != null) {
      if (replace == null) {
        await c.addAudio(a);
      } else {
        await c.updateStep(
          replace.copyWith(
            audioAssetId: a.id,
            title: a.title,
            description: a.description,
            durationMs: a.durationMs,
          ),
        );
      }
    }
  });
  Future<void> _pause(SessionStep step) async {
    await widget.player.stop();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PauseEditor(controller: c, stepId: step.id, player: widget.player),
      ),
    );
  }

  Future<void> _preview(SessionStep s) => showActionError(context, () async {
    final a = c.asset(s.audioAssetId);
    if (a == null) throw StateError('missing');
    await widget.player.toggle(a, c.library.fileFor(a));
  });
  Future<void> _choose() => _run(() async {
    await widget.player.stop();
    if (!mounted) return;
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
  });
  Future<void> _block() => _run(() async {
    final type = await showModalBottomSheet<StepKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Добавить блок')),
            for (final kind in StepKind.values.where(
              (s) => s != StepKind.audio,
            ))
              ListTile(
                enabled: kind != StepKind.voiceRecording,
                leading: Icon(
                  kind == StepKind.silence
                      ? Icons.hourglass_empty
                      : kind == StepKind.freeWork
                      ? Icons.self_improvement
                      : Icons.mic_none,
                ),
                title: Text(kind.label),
                subtitle: kind == StepKind.voiceRecording
                    ? const Text('Запись во время сессии — следующий этап')
                    : null,
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    final duration = await showDialog<({int? ms})>(
      context: context,
      builder: (_) => _BlockDuration(kind: type),
    );
    if (duration != null) await c.addBlock(type, duration.ms);
  });
  Future<void> _group(SessionStep s) => _run(() async {
    final result = await showDialog<({String? id})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Раздел блока'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (id: null)),
            child: const Text('Без раздела'),
          ),
          for (final g in c.draft.plan.groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (id: g.id)),
              child: Text(g.name),
            ),
        ],
      ),
    );
    if (result != null) await c.setGroup(s.id, result.id);
  });
  Future<void> _exit() => _run(() async {
    final result = await showDialog<({String? id})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Аудиовыход'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, (id: null)),
            child: const Text('Без аудиовыхода — текстовая ориентация'),
          ),
          for (final s in c.draft.plan.steps.where(
            (s) => s.kind == StepKind.audio,
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (id: s.id)),
              child: Text(c.asset(s.audioAssetId)?.title ?? s.title),
            ),
        ],
      ),
    );
    if (result != null) await c.setExit(result.id);
  });
  void _menu(String action, SessionStep s) {
    switch (action) {
      case 'replace':
        unawaited(_add(replace: s));
      case 'duplicate':
        unawaited(_run(() => c.duplicate(s.id)));
      case 'delete':
        unawaited(_run(() => c.remove(s.id)));
      case 'group':
        unawaited(_group(s));
      case 'duration':
        unawaited(
          _run(() async {
            final result = await showDialog<({int? ms})>(
              context: context,
              builder: (_) =>
                  _BlockDuration(kind: s.kind, initial: s.durationMs),
            );
            if (result != null) {
              await c.updateStep(
                s.copyWith(
                  durationMs: result.ms,
                  indefinite: result.ms == null,
                ),
              );
            }
          }),
        );
      case 'up':
        final i = c.draft.plan.steps.indexOf(s);
        if (i > 0) unawaited(_run(() => c.reorder(i, i - 1)));
      case 'down':
        final i = c.draft.plan.steps.indexOf(s);
        if (i < c.draft.plan.steps.length - 1) {
          unawaited(_run(() => c.reorder(i, i + 2)));
        }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final plan = c.draft.plan;
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _choose,
              icon: const Icon(Icons.layers_outlined),
              label: Text(
                '${c.baseTemplate?.name ?? c.draft.baseTemplateName ?? 'Текущая конфигурация'}${c.draft.modified ? ' · Изменён' : ''}',
              ),
            ),
            Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                Text('Блоков: ${plan.steps.length}'),
                Text('Паузы: ${formatDuration(plan.delayMs)}'),
                Text('Аудио: ${formatDuration(plan.audioMs)}'),
                Text('Работа: ${formatDuration(plan.workMs)}'),
                Text(
                  '${plan.estimated ? 'Оценка' : 'Итого'}: ${formatDuration(plan.totalMs)}',
                  style: const TextStyle(
                    color: neonLime,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: NeonButton(
                    label: 'Добавить трек',
                    icon: Icons.add,
                    onPressed: _busy ? null : _add,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NeonButton(
                    label: 'Добавить блок',
                    icon: Icons.widgets_outlined,
                    onPressed: _busy ? null : _block,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Пауза перед треком — нажмите на время. Порядок — потяните за ручку или используйте меню.',
              style: TextStyle(fontSize: 12),
            ),
            if (plan.exitStepId == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Аудиовыход не выбран · доступна текстовая ориентация',
                  style: TextStyle(color: antiqueGold, fontSize: 12),
                ),
              ),
          ],
        ),
      );
      return LeatherScaffold(
        title: 'Структура сессии',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Настройки структуры',
            onSelected: (s) {
              if (s == 'group') {
                unawaited(
                  _run(() async {
                    final result = await askDetails(
                      context,
                      title: 'Новый раздел',
                      nameLabel: 'Название раздела',
                    );
                    if (result != null) await c.addGroup(result.name);
                  }),
                );
              }
              if (s == 'exit') unawaited(_exit());
              if (s == 'overwrite') {
                unawaited(
                  _run(() async {
                    if (await confirmAction(
                      context,
                      'Обновить исходный шаблон?',
                      'Будет создана новая версия шаблона «${c.baseTemplate?.name}». История не изменится.',
                      confirm: 'Обновить шаблон',
                    )) {
                      await c.overwriteBase();
                    }
                  }),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'group',
                child: Text('Создать раздел'),
              ),
              const PopupMenuItem(
                value: 'exit',
                child: Text('Выбрать аудиовыход'),
              ),
              if (c.baseTemplate != null)
                const PopupMenuItem(
                  value: 'overwrite',
                  child: Text('Обновить исходный шаблон'),
                ),
            ],
          ),
        ],
        bottom: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .34,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.saveError != null)
                    Text(
                      c.saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: 'Выбрать другой шаблон',
                          stacked: true,
                          icon: Icons.layers_outlined,
                          onPressed: _busy ? null : _choose,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: NeonButton(
                          label: 'Библиотека',
                          stacked: true,
                          icon: Icons.library_music_outlined,
                          onPressed: _busy ? null : _add,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: NeonButton(
                          label: 'Записать свой аудиомодуль',
                          stacked: true,
                          icon: Icons.mic_none,
                          onPressed: null,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: 'Вернуть из шаблона',
                          stacked: true,
                          icon: Icons.restore,
                          onPressed: _busy || c.baseTemplate == null
                              ? null
                              : () => _run(() async {
                                  if (await confirmAction(
                                    context,
                                    'Вернуть настройки шаблона?',
                                    'Текущие дорожки и паузы будут заменены. Тема и заметки сохранятся.',
                                    confirm: 'Вернуть',
                                  )) {
                                    await c.restore();
                                  }
                                }),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: NeonButton(
                          label: 'Сохранить как шаблон',
                          stacked: true,
                          icon: Icons.save_outlined,
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await saveTemplateDialog(context, c);
                                }),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: NeonButton(
                          label: 'Применить и вернуться',
                          stacked: true,
                          icon: Icons.check,
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await c.flush();
                                  if (c.saveError != null) {
                                    throw StateError('unsaved');
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                }),
                          primary: true,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: plan.steps.isEmpty
                  ? ListView(
                      children: [
                        header,
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.queue_music,
                                size: 48,
                                color: neonPink,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Соберите свою последовательность',
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Добавьте аудио из библиотеки или блок тишины. Все новые паузы — 00:00.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ReorderableListView.builder(
                      header: header,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      buildDefaultDragHandles: false,
                      itemCount: plan.steps.length,
                      onReorderItem: (from, to) {
                        if (!_busy) {
                          unawaited(
                            _run(
                              () => c.reorder(from, to > from ? to + 1 : to),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final s = plan.steps[index];
                        final first =
                            index == 0 ||
                            plan.steps[index - 1].groupId != s.groupId;
                        return Column(
                          key: ValueKey(s.id),
                          children: [
                            if (first)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 5,
                                ),
                                child: NeonPanel(
                                  padding: EdgeInsets.zero,
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      if (!_collapsed.add(s.groupId)) {
                                        _collapsed.remove(s.groupId);
                                      }
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _collapsed.contains(s.groupId)
                                                ? Icons.chevron_right
                                                : Icons.expand_more,
                                            color: neonPink,
                                          ),
                                          Expanded(
                                            child: Text(
                                              plan.groupName(s.groupId),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            formatDuration(
                                              plan.steps
                                                  .where(
                                                    (x) =>
                                                        x.groupId == s.groupId,
                                                  )
                                                  .fold(
                                                    0,
                                                    (n, x) => n + x.estimatedMs,
                                                  ),
                                            ),
                                            style: const TextStyle(
                                              color: neonLime,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!_collapsed.contains(s.groupId))
                              _step(s, index),
                          ],
                        );
                      },
                    ),
            ),
            if (widget.player.current != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: SingleChildScrollView(
                  child: PreviewBar(player: widget.player, library: c.library),
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _step(SessionStep s, int index) {
    final a = c.asset(s.audioAssetId);
    final title = a?.title ?? s.title;
    final missing = s.kind == StepKind.audio && a == null;
    final menu = PopupMenuButton<String>(
      tooltip: 'Действия блока ${index + 1}',
      enabled: !_busy,
      onSelected: (action) => _menu(action, s),
      itemBuilder: (_) => [
        if (s.kind == StepKind.audio)
          const PopupMenuItem(value: 'replace', child: Text('Заменить трек')),
        if (s.kind != StepKind.audio)
          const PopupMenuItem(
            value: 'duration',
            child: Text('Изменить длительность'),
          ),
        const PopupMenuItem(
          value: 'group',
          child: Text('Переместить в раздел'),
        ),
        const PopupMenuItem(value: 'up', child: Text('Выше')),
        const PopupMenuItem(value: 'down', child: Text('Ниже')),
        const PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
        const PopupMenuItem(value: 'delete', child: Text('Удалить блок')),
      ],
    );
    final handle = ReorderableDragStartListener(
      index: index,
      enabled: !_busy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
        child: Column(
          children: [
            const Icon(Icons.drag_indicator, size: 20),
            Text('${index + 1}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    final pause = Tooltip(
      message: 'Пауза перед блоком ${index + 1}',
      child: OutlinedButton(
        key: Key('pause-${s.id}'),
        onPressed: _busy ? null : () => _pause(s),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          minimumSize: const Size(63, 48),
          foregroundColor: neonLime,
          side: const BorderSide(color: Color(0xFF737B11)),
        ),
        child: Text(
          '${(s.delayBeforeSeconds ~/ 60).toString().padLeft(2, '0')}:${(s.delayBeforeSeconds % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
    final play = IconButton(
      tooltip: 'Прослушать $title',
      onPressed: s.kind == StepKind.audio && !missing && !_busy
          ? () => _preview(s)
          : null,
      icon: Icon(
        s.kind == StepKind.audio
            ? Icons.play_circle_outline
            : Icons.hourglass_empty,
        color: missing ? Colors.redAccent : neonPink,
      ),
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: missing ? Colors.redAccent : null,
          ),
        ),
        if (s.description.isNotEmpty)
          Text(
            s.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFFC7ACBD)),
          ),
        if (s.id == c.draft.plan.exitStepId)
          const Text(
            'Аудиовыход',
            style: TextStyle(fontSize: 11, color: neonLime),
          ),
      ],
    );
    final duration = Text(
      s.durationMs == null ? 'До остановки' : formatDuration(s.durationMs!),
      style: const TextStyle(fontSize: 12, color: Color(0xFFCDBECA)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF100A0F),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF4B263B)),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 370 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        handle,
                        Expanded(child: name),
                        menu,
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [pause, play, const Spacer(), duration],
                      ),
                    ),
                  ],
                ),
              );
            }
            return Row(
              children: [
                handle,
                pause,
                play,
                Expanded(child: name),
                const SizedBox(width: 6),
                duration,
                menu,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BlockDuration extends StatefulWidget {
  const _BlockDuration({required this.kind, this.initial = 300000});
  final StepKind kind;
  final int? initial;
  @override
  State<_BlockDuration> createState() => _BlockDurationState();
}

class _BlockDurationState extends State<_BlockDuration> {
  late final _seconds = TextEditingController(
    text: '${(widget.initial ?? 300000) ~/ 1000}',
  );
  late bool _indefinite = widget.initial == null;
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind.label),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.kind == StepKind.freeWork)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('До ручного завершения'),
              value: _indefinite,
              onChanged: (v) => setState(() => _indefinite = v),
            ),
          if (!_indefinite)
            TextFormField(
              controller: _seconds,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Длительность, секунд',
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 86400
                    ? 'От 1 до 86400 секунд'
                    : null;
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              ms: _indefinite ? null : int.parse(_seconds.text) * 1000,
            ));
          }
        },
        child: const Text('Применить'),
      ),
    ],
  );
}
