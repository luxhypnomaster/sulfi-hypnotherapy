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
  String id,
) async {
  await showActionError(context, () async {
    final index = await LocalCatalogSource.currentIndex(c.capsules!);
    final root = index.singleWhere(
      (r) => r.key.content.type == type && r.key.content.id == id,
    );
    final draft = await c.catalog.prepare(root);
    if (context.mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CatalogCardEditor(service: c.catalog, draft: draft),
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
  @override
  void initState() {
    super.initState();
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
  }

  Future<void> save({bool publish = false}) async {
    if (busy) return;
    setState(() => busy = true);
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
        await widget.service.publish(
          draft,
          progress: (n, total) {
            if (mounted) setState(() => progress = '$n / $total байт');
          },
        );
      }
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: 'Карточка публикации',
    child: Column(
      children: [
        if (error != null)
          Text(error!, style: const TextStyle(color: neonPink)),
        Text(
          'Статус: ${draft['status'] == 'published'
              ? 'Опубликовано'
              : draft['status'] == 'failed'
              ? 'Сбой — можно повторить'
              : 'Черновик на телефоне'}',
        ),
        if (busy) const LinearProgressIndicator(),
        if (progress.isNotEmpty) Text(progress),
        Expanded(
          child: ListView(
            children: [
              for (final item in const {
                'title': 'Название',
                'shortAnnotation': 'Аннотация',
                'description': 'Описание',
                'categoryIds': 'Категории через запятую',
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
                    enabled: !busy,
                    maxLines:
                        ['description', 'shortAnnotation'].contains(item.key)
                        ? 3
                        : 1,
                    decoration: InputDecoration(labelText: item.value),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: card['visibility'] as String? ?? 'private',
                decoration: const InputDecoration(labelText: 'Видимость'),
                items: const [
                  DropdownMenuItem(
                    value: 'private',
                    child: Text('Личный материал'),
                  ),
                  DropdownMenuItem(
                    value: 'public',
                    child: Text('Для всех читателей'),
                  ),
                ],
                onChanged: busy ? null : (v) => card['visibility'] = v,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Публикация выполняется только после проверки файлов и ответа сервера. Сохранение черновика не публикует материал.',
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy ? null : () => save(),
              child: const Text('Сохранить черновик'),
            ),
            FilledButton(
              onPressed: busy ? null : () => save(publish: true),
              child: const Text('Опубликовать'),
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
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await widget.service.drafts();
      if (mounted) setState(() => cards = values);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: 'Каталог публикаций',
    child: Column(
      children: [
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
          decoration: const InputDecoration(labelText: 'Поиск публикаций'),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        if (error != null) Text(error!),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              children: [
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
        ),
      ],
    ),
  );
}
