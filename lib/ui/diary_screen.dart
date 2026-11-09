import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import '../models/session_plan.dart';
import '../services/diary_api.dart';
import '../services/diary_controller.dart';
import '../services/diary_layout.dart';
import 'diary_editor.dart';
import 'diary_reader.dart';
import 'design.dart';
export 'diary_editor.dart';
export 'diary_reader.dart';
export 'diary_legacy_pagination.dart';
export '../services/diary_layout.dart' show diaryDate;

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.diary});
  final DiaryController diary;
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DiaryController get d => widget.diary;
  String query = '';
  String? category;
  DiaryBlockType? filter;
  bool byDate = false, readerMode = false, busy = false;
  @override
  void initState() {
    super.initState();
    unawaited(d.sync());
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is DiaryApiException
                  ? e.message
                  : 'Действие не выполнено. Данные сохранены.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editor([DiaryEntry? entry]) async {
    if (!d.authorWorkspace) return;
    final now = DateTime.now().toUtc();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditor(
          diary: d,
          entry:
              entry ??
              DiaryEntry(
                id: newId(),
                message: '',
                body: '',
                order: d.drafts.isEmpty
                    ? 0
                    : d.drafts
                              .map((e) => e.order)
                              .reduce((a, b) => a > b ? a : b) +
                          1,
                createdAt: now,
                updatedAt: now,
              ),
        ),
      ),
    );
  }

  Future<void> remove(DiaryEntry e) async {
    final public =
        d.published.any((p) => p.id == e.id) ||
        e.status == DiaryStatus.published;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          '«${e.displayTitle}»${public ? '\nПосле синхронизации запись исчезнет у читателей.' : '\nБудет удалён только этот черновик.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (accepted == true) await action(() => d.deleteEntry(e));
  }

  List<DiaryEntry> entries(bool author) {
    final list = author
        ? [
            ...d.drafts,
            ...d.published.where((p) => !d.drafts.any((e) => e.id == p.id)),
          ]
        : d.published.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    if (byDate) list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list
        .where(
          (e) =>
              (query.isEmpty ||
                  '${e.displayTitle} ${e.message}'.toLowerCase().contains(
                    query.toLowerCase(),
                  )) &&
              (filter == null || e.blocks.any((b) => b.type == filter)) &&
              (category == null ||
                  DiaryPublication.of(e).categoryId == category),
        )
        .toList();
  }

  Future<void> move(List<DiaryEntry> list, int from, int to) async {
    if (to > from) to--;
    final next = list.toList(), item = list[from];
    next.removeAt(from);
    next.insert(to, item);
    await action(() => d.reorderEntries(next));
  }

  Widget row(
    DiaryEntry e,
    int i,
    bool author,
    bool drag,
    List<DiaryEntry> list,
  ) {
    final snapshot = d.published.where((p) => p.id == e.id).firstOrNull;
    final hasDraft =
        snapshot != null &&
        (snapshot.body != e.body ||
            snapshot.title != e.title ||
            snapshot.message != e.message ||
            snapshot.blocks.map((b) => b.toMap().toString()).join() !=
                e.blocks.map((b) => b.toMap().toString()).join());
    return Container(
      key: ValueKey(e.id),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x885C123E))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (drag)
                ReorderableDragStartListener(
                  index: i,
                  enabled: !busy,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: 'Перетащить запись',
                      child: Icon(Icons.drag_indicator, color: neonPink),
                    ),
                  ),
                ),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiaryReader(
                        entry: snapshot ?? e,
                        preview: author && snapshot == null,
                        diary: d,
                        fromJournal: true,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.number == null ? 'Черновик' : '№${e.number}'}  ${e.displayTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          diaryDate(e.createdAt),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              DiaryPublication.of(e).categoryName,
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (d.reads.isRead(e))
                              const Text(
                                'Прочитано',
                                style: TextStyle(fontSize: 11),
                              ),
                            for (final type
                                in e.blocks.map((b) => b.type).toSet())
                              Text(
                                switch (type) {
                                  DiaryBlockType.text => 'Текст',
                                  DiaryBlockType.image => 'Изображение',
                                  DiaryBlockType.audio => 'Аудио',
                                },
                                style: const TextStyle(
                                  color: neonLime,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        if (author)
                          Text(
                            snapshot != null
                                ? (hasDraft
                                      ? 'Опубликовано · есть черновик'
                                      : 'Опубликовано')
                                : e.status == DiaryStatus.unpublished
                                ? 'Снято с публикации'
                                : 'Черновик',
                            style: const TextStyle(
                              color: antiqueGold,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (author)
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (drag)
                  IconButton(
                    tooltip: 'Запись выше',
                    onPressed: busy || i == 0
                        ? null
                        : () => move(list, i, i - 1),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                if (drag)
                  IconButton(
                    tooltip: 'Запись ниже',
                    onPressed: busy || i == list.length - 1
                        ? null
                        : () => move(list, i, i + 2),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                IconButton(
                  tooltip: 'Редактировать запись',
                  onPressed: busy ? null : () => editor(e),
                  icon: const Icon(Icons.edit_outlined, color: neonPink),
                ),
                IconButton(
                  tooltip: 'Удалить запись',
                  onPressed: busy ? null : () => remove(e),
                  icon: const Icon(Icons.delete_outline, color: neonPink),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: d,
    builder: (context, _) {
      final cloudSignedIn = d.policy != null
          ? d.authenticated
          : d.authorWorkspace;
      final author = d.authorWorkspace && !readerMode,
          list = entries(author),
          drag = author && !byDate && query.isEmpty && filter == null;
      return LeatherScaffold(
        title: 'Журнал записей',
        actions: [
          if (d.canSignIn)
            IconButton(
              tooltip: cloudSignedIn
                  ? 'Выйти из аккаунта автора'
                  : 'Войти как автор через Google',
              onPressed: d.authorBusy || busy
                  ? null
                  : () => action(cloudSignedIn ? d.logout : d.signInAuthor),
              icon: Icon(cloudSignedIn ? Icons.logout : Icons.person_outline),
            ),
          IconButton(
            tooltip: 'Обновить дневник',
            onPressed: d.syncing ? null : d.sync,
            icon: const Icon(Icons.refresh),
          ),
        ],
        child: Column(
          children: [
            if (d.syncing || busy) const LinearProgressIndicator(minHeight: 2),
            if (d.error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 90),
                child: SingleChildScrollView(
                  child: Text(
                    d.error!,
                    style: const TextStyle(fontSize: 11, color: antiqueGold),
                  ),
                ),
              ),
            if (d.authorWorkspace)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      d.policy?.isAuthor == false ? 'Мои записи' : 'Автор',
                    ),
                    selected: !readerMode,
                    onSelected: (_) => setState(() => readerMode = false),
                  ),
                  ChoiceChip(
                    label: const Text('Читатель'),
                    selected: readerMode,
                    onSelected: (_) => setState(() => readerMode = true),
                  ),
                  if (author)
                    TextButton.icon(
                      onPressed: busy ? null : () => editor(),
                      icon: const Icon(Icons.add, color: neonLime),
                      label: const Text('Новая запись'),
                    ),
                  if (author && d.api != null && (d.policy?.isAuthor ?? true))
                    IconButton(
                      tooltip: 'Загрузить недостающие черновики с Диска',
                      onPressed: busy
                          ? null
                          : () => action(() async {
                              await d.restoreFromCloud();
                            }),
                      icon: const Icon(Icons.cloud_download_outlined),
                    ),
                ],
              ),
            if (!d.authorWorkspace &&
                d.allowDebugAuthor &&
                !(d.policy?.clientEdition ?? false))
              TextButton(
                onPressed: () async {
                  d.enterDebugAuthor();
                  await d.load();
                },
                child: const Text('Локальный автор · тестовый режим'),
              ),
            DropdownButton<String>(
              isExpanded: true,
              value: category,
              hint: const Text('Все категории'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все категории'),
                ),
                for (final c in diaryCategories.entries)
                  DropdownMenuItem(value: c.key, child: Text(c.value)),
                for (final id
                    in d.published
                        .map((e) => DiaryPublication.of(e).categoryId)
                        .toSet()
                        .where((id) => !diaryCategories.containsKey(id)))
                  DropdownMenuItem(
                    value: id,
                    child: Text('Неизвестная категория: $id'),
                  ),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Поиск записей',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (s) => setState(() => query = s),
            ),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Всего: ${list.length}',
                  style: const TextStyle(fontSize: 12, color: neonLime),
                ),
                DropdownButton<bool>(
                  value: byDate,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Вручную')),
                    DropdownMenuItem(value: true, child: Text('По дате')),
                  ],
                  onChanged: (v) => setState(() => byDate = v ?? false),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButton<DiaryBlockType?>(
                    isExpanded: true,
                    selectedItemBuilder: (_) => [
                      for (final label in [
                        'Все типы',
                        'Текст',
                        'Изображение',
                        'Аудио',
                      ])
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    value: filter,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Все типы'),
                      ),
                      for (final t in DiaryBlockType.values)
                        DropdownMenuItem(
                          value: t,
                          child: Text(switch (t) {
                            DiaryBlockType.text => 'Текст',
                            DiaryBlockType.image => 'Изображение',
                            DiaryBlockType.audio => 'Аудио',
                          }),
                        ),
                    ],
                    onChanged: (t) => setState(() => filter = t),
                  ),
                ),
              ],
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        query.isNotEmpty || filter != null
                            ? 'Записи не найдены.'
                            : author
                            ? 'Создайте первую запись.'
                            : d.hasCache
                            ? 'Опубликованных записей пока нет.'
                            : 'Каталог ещё не загружен. Подключитесь к сети и обновите дневник.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      onReorderItem: drag
                          ? (a, b) => move(list, a, b > a ? b + 1 : b)
                          : (_, _) {},
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          row(list[i], i, author, drag, list),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
