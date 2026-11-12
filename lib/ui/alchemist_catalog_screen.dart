import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'dart:async';

import '../services/alchemist_announcement.dart';
import '../services/alchemist_errors.dart';
import 'diary_editor.dart';
import '../models/diary_entry.dart';

import 'package:flutter/material.dart';

import '../models/content_revision.dart';
import '../services/alchemist_catalog.dart';
import '../services/local_content_catalog.dart';
import '../services/session_controller.dart';
import 'design.dart';
import 'session_actions.dart';

Future<void> preparePublication(
  BuildContext context,
  SessionController c,
  ContentType type,
  String id, {
  bool catalogOnly = false,
}) async {
  await showActionError(context, () async {
    final index = await LocalCatalogSource.currentIndex(c.capsules!);
    final root = index.singleWhere(
      (r) => r.key.content.type == type && r.key.content.id == id,
    );
    final draft = await c.catalog.prepare(root);
    final announcement = catalogOnly
        ? null
        : await prepareCatalogAnnouncement(c.catalog, draft);
    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => catalogOnly
              ? CatalogCardEditor(service: c.catalog, draft: draft)
              : DiaryEditor(diary: c.diary!, entry: announcement!),
        ),
      );
    }
  });
}

class CatalogCardEditor extends StatefulWidget {
  const CatalogCardEditor({
    super.key,
    required this.service,
    required this.draft,
  });
  final AlchemistCatalog service;
  final Map<String, dynamic> draft;
  @override
  State<CatalogCardEditor> createState() => _CatalogCardEditorState();
}

class _CatalogCardEditorState extends State<CatalogCardEditor> {
  late final Map<String, dynamic> draft = Map.from(widget.draft);
  late final Map<String, dynamic> card = Map.from(draft['card']);
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String? error;
  String progress = '';
  bool paused = false;
  Timer? autosave;
  bool get transferring => widget.service.controller.cloudQueue.rows.any(
    (r) =>
        r['catalogItemId'] == draft['catalogItemId'] &&
        !const [
          'complete',
          'failed',
          'paused',
          'cancelled',
        ].contains(r['_work']?['phase']),
  );
  void queueChanged() {
    if (mounted) setState(() {});
  }

  void scheduleSave() {
    autosave?.cancel();
    autosave = Timer(const Duration(milliseconds: 500), () {
      if (mounted &&
          !busy &&
          !transferring &&
          widget.service.controller.policy.isAuthor) {
        unawaited(save());
      }
    });
  }

  void _identityChanged() {
    if (!widget.service.controller.policy.isAuthor) paused = true;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.service.controller.policy.addListener(_identityChanged);
    widget.service.controller.cloudQueue.addListener(queueChanged);
    for (final k in [
      'title',
      'shortAnnotation',
      'description',
      'language',
      'authorDisplayName',
      'releaseNotes',
    ]) {
      fields[k] = TextEditingController(text: card[k] as String? ?? '');
    }
    fields['tags'] = TextEditingController(
      text: (card['tags'] as List? ?? []).join(', '),
    );
    fields['categoryIds'] = TextEditingController(
      text: (card['categoryIds'] as List? ?? []).join(', '),
    );
    for (final field in fields.values) {
      field.addListener(scheduleSave);
    }
  }

  Future<void> save({bool publish = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      paused = false;
    });
    try {
      for (final f in fields.entries) {
        card[f.key] = ['tags', 'categoryIds'].contains(f.key)
            ? f.value.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : f.value.text;
      }
      draft['card'] = card;
      await widget.service.save(draft);
      if (publish) {
        await widget.service.controller.cloudQueue.enqueue(
          'alchemist_card:${draft['catalogItemId']}',
        );
        progress = 'В очереди приложения. Можно перейти на другой экран.';
      }
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transition(String action) async {
    setState(() => busy = true);
    try {
      await widget.service.transition(draft, action);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cover() async {
    setState(() => busy = true);
    try {
      final store = widget.service.controller.diary?.mediaStore;
      if (store == null) {
        throw const FormatException('Импорт изображений недоступен');
      }
      final block = await store.import(DiaryBlockType.image);
      if (block == null) return;
      final m = block.media!;
      draft['localCover'] = m.toMap();
      draft['coverStatus'] = 'local';
      card['coverAssetId'] = null;
      draft['card'] = card;
      await widget.service.save(draft);
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> categories() async {
    final selected = fields['categoryIds']!.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    final known = <String>{
      ...selected,
      'Расслабление',
      'Самогипноз',
      'Ресурс',
      'Сон',
    };
    for (final d in await widget.service.drafts()) {
      known.addAll(List<String>.from(d['card']['categoryIds'] ?? []));
    }
    if (!mounted) return;
    final input = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Категории материала'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final value in known)
                    CheckboxListTile(
                      title: Text(value),
                      value: selected.contains(value),
                      onChanged: (v) => refresh(() {
                        if (v == true) {
                          selected.add(value);
                        } else {
                          selected.remove(value);
                        }
                      }),
                    ),
                  TextField(
                    controller: input,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Новая категория для этой карточки',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final value = input.text.trim();
                      if (value.isEmpty ||
                          value.length > 60 ||
                          value.contains(',') ||
                          RegExp(r'[\x00-\x1f]').hasMatch(value)) {
                        return;
                      }
                      refresh(() {
                        known.add(value);
                        selected.add(value);
                        input.clear();
                      });
                    },
                    child: const Text('Добавить значение'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
    fields['categoryIds']!.text = selected.join(', ');
    // Controller lives until the dialog route finishes disposing its text field.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
  }

  @override
  void dispose() {
    if (autosave?.isActive == true &&
        !transferring &&
        widget.service.controller.policy.isAuthor) {
      for (final f in fields.entries) {
        card[f.key] = ['tags', 'categoryIds'].contains(f.key)
            ? f.value.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : f.value.text;
      }
      draft['card'] = card;
      unawaited(widget.service.save(draft).catchError((Object _) {}));
    }
    autosave?.cancel();
    widget.service.controller.cloudQueue.removeListener(queueChanged);
    widget.service.controller.policy.removeListener(_identityChanged);
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      !widget.service.controller.policy.isAuthor
      ? const Scaffold(
          body: Center(child: Text('Авторские возможности недоступны')),
        )
      : LeatherScaffold(
          title: 'Карточка публикации',
          child: ListView(
            children: [
              if (error != null)
                Text(error!, style: const TextStyle(color: neonPink)),
              Text(
                'Статус: ${const {'draft': 'Черновик на телефоне', 'uploading': 'Передача файлов', 'publishing': 'Ожидаем ответ сервера', 'published': 'Опубликовано', 'failed': 'Сбой — можно повторить', 'paused': 'Приостановлено', 'archived': 'Архив', 'withdrawn': 'Публикация снята'}[draft['status']] ?? draft['status']}',
              ),
              if (busy) const LinearProgressIndicator(),
              if (busy && draft['status'] != 'publishing')
                TextButton(
                  onPressed: () => setState(() => paused = true),
                  child: const Text('Приостановить'),
                ),
              if (progress.isNotEmpty) Text(progress),
              Text(
                'Тип: ${draft['type']} · версия ${draft['etag'] ?? 'локальная'}',
              ),
              for (final root in draft['roots'] as List? ?? [draft['root']])
                if (root != null)
                  ListTile(
                    title: Text(
                      root['payload']['title'] ??
                          root['payload']['name'] ??
                          'Материал',
                    ),
                    subtitle: Text(
                      'Точных зависимостей: ${(root['dependencies'] as List).length}',
                    ),
                  ),
              if (draft['localCover'] is Map)
                Image.file(
                  widget.service.controller.diary!.mediaStore!.file(
                    DiaryMedia.fromMap(
                      Map<String, dynamic>.from(draft['localCover']),
                    ),
                  )!,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Обложка недоступна — выберите другую'),
                ),
              if (draft['coverStatus'] != null)
                Text('Обложка: ${draft['coverStatus']}'),
              TextButton.icon(
                onPressed: busy || transferring ? null : cover,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  card['coverAssetId'] == null
                      ? 'Добавить обложку'
                      : 'Заменить обложку',
                ),
              ),
              if (card['coverAssetId'] != null || draft['localCover'] != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            card['coverAssetId'] = null;
                            draft.remove('localCover');
                            draft.remove('coverStatus');
                          });
                          scheduleSave();
                        },
                  child: const Text('Убрать обложку'),
                ),
              if (draft['type'] != 'package' &&
                  draft['embeddedRoot'] != true &&
                  draft['remoteOnly'] != true)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            final index = await LocalCatalogSource.currentIndex(
                              widget.service.controller.capsules!,
                            );
                            final old =
                                draft['roots'] as List? ?? [draft['root']];
                            final next = old
                                .map(
                                  (r) => index
                                      .singleWhere(
                                        (v) =>
                                            v.key.content.id ==
                                                r['logicalId'] &&
                                            v.key.content.type.name ==
                                                r['type'],
                                      )
                                      .toMap(),
                                )
                                .toList();
                            if (draft['roots'] != null) {
                              draft['roots'] = next;
                            } else {
                              draft['root'] = next.single;
                            }
                            await widget.service.save(draft);
                            if (mounted) setState(() => error = null);
                          } catch (e) {
                            if (mounted) {
                              setState(
                                () => error = AlchemistFailure.from(e).message,
                              );
                            }
                          }
                        },
                  child: const Text('Обновить состав из библиотеки'),
                ),
              for (final item in const {
                'title': 'Название',
                'shortAnnotation': 'Аннотация',
                'description': 'Описание',
                'tags': 'Теги через запятую',
                'language': 'Язык',
                'authorDisplayName': 'Автор / правообладатель',
                'releaseNotes': 'Что нового',
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    key: ValueKey('catalog-${item.key}'),
                    controller: fields[item.key],
                    enabled: !busy && !transferring,
                    maxLines:
                        ['description', 'shortAnnotation'].contains(item.key)
                        ? 3
                        : 1,
                    decoration: InputDecoration(
                      labelText: item.value,
                      helperText: item.key == 'shortAnnotation'
                          ? 'Кратко: кому и чем поможет материал'
                          : item.key == 'description'
                          ? 'Подробности, состав и рекомендации'
                          : null,
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: busy || transferring ? null : categories,
                icon: const Icon(Icons.category_outlined),
                label: Text(
                  'Категории: ${fields['categoryIds']!.text.isEmpty ? 'выбрать ▾' : fields['categoryIds']!.text} ▾',
                ),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: card['visibility'] as String? ?? 'private',
                decoration: const InputDecoration(labelText: 'Видимость'),
                items: const [
                  DropdownMenuItem(
                    value: 'private',
                    child: Text(
                      'Личный материал',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'public',
                    child: Text(
                      'Для всех читателей',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: busy || transferring
                    ? null
                    : (v) {
                        card['visibility'] = v;
                        scheduleSave();
                      },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Публикация выполняется только после проверки файлов и ответа сервера. Сохранение черновика не публикует материал.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => save(),
                    child: const Text('Сохранить черновик'),
                  ),
                  if (draft['etag'] != null) ...[
                    if (draft['status'] == 'published')
                      TextButton(
                        onPressed: busy ? null : () => transition('withdraw'),
                        child: const Text('Снять публикацию'),
                      ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => transition(
                              draft['status'] == 'archived'
                                  ? 'restore'
                                  : 'archive',
                            ),
                      child: Text(
                        draft['status'] == 'archived'
                            ? 'Восстановить'
                            : 'В архив',
                      ),
                    ),
                  ],
                  FilledButton(
                    onPressed: busy || transferring
                        ? null
                        : () => save(publish: true),
                    child: const Text('Добавить в каталог'),
                  ),
                ],
              ),
            ],
          ),
        );
}

class AlchemistCatalogScreen extends StatefulWidget {
  const AlchemistCatalogScreen({super.key, required this.service});
  final AlchemistCatalog service;
  @override
  State<AlchemistCatalogScreen> createState() => _AlchemistCatalogScreenState();
}

class _AlchemistCatalogScreenState extends State<AlchemistCatalogScreen> {
  List<Map<String, dynamic>> cards = [];
  String filter = 'draft', query = '';
  String? error;
  void _identityChanged() {
    if (!widget.service.controller.policy.isAuthor) cards = [];
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.controller.policy.removeListener(_identityChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.service.controller.policy.addListener(_identityChanged);
    load();
  }

  Future<void> load() async {
    try {
      final values = await widget.service.drafts();
      if (mounted) setState(() => cards = values);
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    }
  }

  Future<void> openDraft(Map<String, dynamic> draft) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CatalogCardEditor(service: widget.service, draft: draft),
      ),
    );
    await load();
  }

  Future<void> createCollection() async {
    try {
      final index = await LocalCatalogSource.currentIndex(
        widget.service.controller.capsules!,
      );
      if (!mounted) return;
      final selected = <String>{};
      final chosen = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: const Text('Выберите состав сборки'),
            content: SizedBox(
              width: 340,
              height: 360,
              child: ListView(
                children: [
                  for (final r in index)
                    CheckboxListTile(
                      value: selected.contains(r.key.token),
                      title: Text(
                        r.payload['title'] ??
                            r.payload['name'] ??
                            r.key.content.id,
                      ),
                      subtitle: Text(r.key.content.type.name),
                      onChanged: (v) => refresh(() {
                        if (v == true) {
                          selected.add(r.key.token);
                        } else {
                          selected.remove(r.key.token);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Создать сборку'),
              ),
            ],
          ),
        ),
      );
      if (chosen == true) {
        await openDraft(
          await widget.service.prepareCollection(
            index.where((r) => selected.contains(r.key.token)).toList(),
            'Новая сборка',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    }
  }

  Future<void> createPackage() async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (f?.path != null) {
        await openDraft(await widget.service.preparePackage(File(f!.path!)));
      }
    } catch (e) {
      if (mounted) setState(() => error = AlchemistFailure.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) =>
      !widget.service.controller.policy.isAuthor
      ? const Scaffold(
          body: Center(child: Text('Авторские возможности недоступны')),
        )
      : LeatherScaffold(
          title: 'Каталог публикаций',
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await openDraft(
                            await widget.service.prepareCurrentSession(),
                          );
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => error = AlchemistFailure.from(e).message,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Текущая сессия'),
                    ),
                    TextButton.icon(
                      onPressed: createCollection,
                      icon: const Icon(Icons.add),
                      label: const Text('Создать сборку'),
                    ),
                    TextButton.icon(
                      onPressed: createPackage,
                      icon: const Icon(Icons.folder_zip_outlined),
                      label: const Text('Подготовить ZIP'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await widget.service.synchronize();
                          await load();
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => error = AlchemistFailure.from(e).message,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Синхронизировать каталог'),
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    for (final t in const {
                      'draft': 'Черновики',
                      'published': 'Опубликовано',
                      'archived': 'Архив',
                    }.entries)
                      ChoiceChip(
                        label: Text(t.value),
                        selected: filter == t.key,
                        onSelected: (_) => setState(() => filter = t.key),
                      ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск публикаций',
                  ),
                  onChanged: (v) => setState(() => query = v.toLowerCase()),
                ),
                if (error != null) Text(error!),
                for (final c in cards.where(
                  (c) =>
                      (filter == 'draft'
                          ? c['status'] != 'published' &&
                                c['status'] != 'archived'
                          : c['status'] == filter) &&
                      '${c['card']['title']} ${c['card']['shortAnnotation']}'
                          .toLowerCase()
                          .contains(query),
                ))
                  ListTile(
                    title: Text(c['card']['title']),
                    subtitle: Text(
                      '${c['card']['shortAnnotation']}\n${c['status']}',
                    ),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CatalogCardEditor(
                            service: widget.service,
                            draft: c,
                          ),
                        ),
                      );
                      await load();
                    },
                  ),
                if (cards.isEmpty)
                  const ListTile(
                    title: Text('Публикаций пока нет'),
                    subtitle: Text(
                      'Выберите материал в библиотеке и нажмите «Подготовить к публикации».',
                    ),
                  ),
              ],
            ),
          ),
        );
}
