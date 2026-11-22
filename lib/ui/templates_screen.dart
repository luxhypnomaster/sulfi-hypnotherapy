import '../services/course22_store.dart';
import 'alchemist_catalog_screen.dart';
import '../models/content_revision.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/session_plan.dart';
import '../services/preview_player.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'content_export.dart';
import 'session_actions.dart';
import 'modular_structure_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({
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
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  String _query = '';
  String origin = 'all';
  bool _busy = false;
  SessionController get c => widget.controller;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await showActionError(context, action);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _select(SessionTemplate t, {bool edit = false}) =>
      _run(() async {
        if (edit && !widget.selecting) {
          final editor = await c.beginEditing();
          try {
            if (!mounted ||
                !await loadTemplateSafely(context, editor, t) ||
                !mounted) {
              return;
            }
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ModularStructureScreen(
                  controller: editor,
                  player: widget.player,
                ),
              ),
            );
          } finally {
            editor.dispose();
          }
          await c.reload();
          return;
        }
        if (!await loadTemplateSafely(context, c, t) || !mounted) return;
        if (widget.selecting) {
          Navigator.pop(context);
          return;
        }
        if (edit) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ModularStructureScreen(controller: c, player: widget.player),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      });
  Future<void> _create() => _run(() async {
    final result = await askDetails(
      context,
      title: 'Создать программу',
      hint: 'Создаётся пустая программа. Затем вы сможете собрать её рабочую копию и явно обновить исходную программу.',
    );
    if (result == null) return;
    final t = await c.saveAsTemplate(
      result.name,
      result.description,
      plan: SessionPlan(steps: const []),
    );
    if (!mounted) return;
    final editor = await c.beginEditing();
    try {
      if (!mounted ||
          !await loadTemplateSafely(context, editor, t) ||
          !mounted) {
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ModularStructureScreen(controller: editor, player: widget.player),
        ),
      );
    } finally {
      editor.dispose();
    }
    await c.reload();
  });
  Future<void> _action(String action, SessionTemplate t) => _run(() async {
    if (['rename', 'delete'].contains(action) &&
        !c.policy.canEditMaterial('template', t.id, t.origin)) {
      throw StateError(
        'Общую программу изменяет только автор. Сохраните личный вариант.',
      );
    }
    if (action == 'rename') {
      final result = await askDetails(
        context,
        title: 'Название и описание',
        name: t.name,
        description: t.description,
      );
      if (result != null) {
        await c.repository.saveTemplate(
          SessionTemplate(
            id: t.id,
            name: result.name,
            description: result.description,
            plan: t.plan,
            createdAt: t.createdAt,
            updatedAt: DateTime.now().toUtc(),
            version: t.version + 1,
            isDefault: t.isDefault,
            origin: t.origin,
            parentRevision: t.parentRevision,
            baseRevision: t.baseRevision,
            author: t.author,
          ),
        );
      }
    }
    if ((action == 'publish' || action == 'catalog') && mounted) {
      await preparePublication(
        context,
        c,
        ContentType.template,
        t.id,
        catalogOnly: action == 'catalog',
      );
      return;
    }
    if (action == 'export' && mounted && c.capsules != null) {
      await exportMaterial(context, c.capsules!, templateId: t.id);
    }
    if (action == 'copy') {
      await c.saveAsTemplate(
        '${t.name} — копия',
        t.description,
        plan: t.plan,
        parent: t,
      );
    }
    if (action == 'default') await c.repository.setDefault(t.id);
    if (action == 'delete') {
      if (!mounted) return;
      if (!await confirmAction(
        context,
        'Удалить программу?',
        '«${t.name}» будет удалён. Текущая конфигурация, история и аудиофайлы сохранятся.',
        confirm: 'Удалить',
      )) {
        return;
      }
      if (c.project22Enabled && c.capsules != null && t.origin == 'official') {
        await Course22Store(
          c.capsules!.database,
          owner: () => c.transferOwner,
        ).markDeleted(t.id);
      }
      await c.repository.deleteTemplate(t.id);
    }
    await c.reload();
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final visible = c.templates
          .where(
            (t) =>
                (origin == 'all' || t.origin == origin) &&
                '${t.name} ${t.description}'.toLowerCase().contains(
                  _query.toLowerCase(),
                ),
          )
          .toList();
      final content = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Создать'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await saveTemplateDialog(context, c);
                        }),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Из текущей'),
                ),
              ),
            ],
          ),
          TextField(
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Найти программу',
              prefixIcon: const Icon(Icons.search),
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
            onChanged: (q) => setState(() => _query = q),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Программ пока нет. Создайте свою или сохраните текущую конфигурацию.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = visible[index];
                      return ListTile(
                        key: ValueKey('template-${t.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        minVerticalPadding: 2,
                        title: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${c.policy.isCatalogOriginal('template', t.id) ? 'Официальный · ' : ''}${t.plan.steps.length} элементов · ${formatDuration(t.plan.totalMs)}${t.plan.exitStepId == null ? ' · без выхода' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: antiqueGold,
                          ),
                        ),
                        onTap: _busy ? null : () => _select(t),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Действия программы',
                          enabled: !_busy,
                          onSelected: (v) {
                            if (v == 'edit') {
                              unawaited(_select(t, edit: true));
                            } else {
                              unawaited(_action(v, t));
                            }
                          },
                          itemBuilder: (_) => [
                            if (c.capsules != null &&
                                c.library.policy.isAuthor) ...[
                              const PopupMenuItem(
                                value: 'catalog',
                                child: Text('Добавить в каталог'),
                              ),
                              const PopupMenuItem(
                                value: 'publish',
                                child: Text('Подготовить к публикации'),
                              ),
                            ],
                            if (c.capsules != null)
                              const PopupMenuItem(
                                value: 'export',
                                child: Text('Экспортировать на устройство'),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Редактировать'),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Переименовать и описать'),
                            ),
                            PopupMenuItem(
                              value: 'copy',
                              child: Text('Копировать'),
                            ),
                            PopupMenuItem(
                              value: 'default',
                              child: Text('Сделать базовым'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
      return widget.embedded
          ? content
          : LeatherScaffold(
              title: widget.selecting ? 'Выбрать программу' : 'Программы',
              child: content,
            );
    },
  );
}
