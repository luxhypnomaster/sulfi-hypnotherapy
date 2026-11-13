import 'diary_video.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../models/diary_publication.dart';
import 'diary_content_picker.dart';
import '../models/session_plan.dart';
import '../services/diary_controller.dart';
import '../services/diary_api.dart';
import 'diary_reader.dart';
import 'alchemist_sync_screen.dart';
import 'design.dart';
import 'session_scope.dart';
import 'recorder_screen.dart';
import '../services/recorder_service.dart';

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({
    super.key,
    required this.diary,
    required this.entry,
    this.recordAudio,
    this.captureBackend,
  });
  final DiaryController diary;
  final DiaryEntry entry;
  final Future<DiaryBlock?> Function()? recordAudio;
  final CaptureBackend? captureBackend;
  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> with WidgetsBindingObserver {
  late DiaryEntry entry = widget.entry;
  late final title = TextEditingController(text: entry.title);
  late final message = TextEditingController(text: entry.message);
  late List<DiaryBlock> blocks = entry.blocks.toList();
  final textControllers = <String, TextEditingController>{};
  final scroll = ScrollController();
  Timer? timer;
  Future<void> tail = Future.value();
  String? error, previewIssue;
  String saved = 'Изменения ещё не сохранены';
  int? pages;
  bool allowPop = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!busy && state != AppLifecycleState.resumed) unawaited(save());
  }

  DiaryEntry get value => entry.copyWith(
    title: title.text,
    message: message.text,
    blocks: List.of(blocks),
    updatedAt: DateTime.now().toUtc(),
  );
  void changed([String? _]) {
    timer?.cancel();
    setState(() => saved = 'Есть несохранённые изменения');
    timer = Timer(const Duration(milliseconds: 350), () => unawaited(save()));
  }

  Future<bool> save() async {
    timer?.cancel();
    final snapshot = value;
    final operation = tail.then((_) => widget.diary.saveDraft(snapshot));
    tail = operation.catchError((Object _) {});
    try {
      await operation;
      if (mounted) {
        setState(() {
          error = null;
          saved = 'Сохранено на телефоне';
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Не удалось сохранить черновик. Правки остаются на экране. Повторите сохранение.',
        );
      }
      return false;
    }
  }

  Future<void> close() async {
    if (busy) return;
    if (await save() && mounted) {
      setState(() => allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> preview() async {
    if (!await save() || !mounted) return;
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DiaryReader(entry: value, preview: true, diary: widget.diary),
      ),
    );
  }

  Future<void> cloud({bool? publish}) async {
    if (busy) return;
    setState(() => busy = true);
    timer?.cancel();
    try {
      if (!await save() || !mounted) return;
      if (publish == true) {
        final problem =
            value.publicationErrorFor(
              advanced: widget.diary.api?.supportsAdvancedPublication ?? false,
            ) ??
            previewIssue;
        if (problem != null) {
          setState(() => error = problem);
          return;
        }
        FocusScope.of(context).unfocus();
        final confirm = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => DiaryReader(
              entry: value,
              preview: true,
              publicationReview: true,
              diary: widget.diary,
            ),
          ),
        );
        if (confirm != true || !mounted) return;
      }
      final controller = SessionScope.maybeOf(context)?.controller;
      if (widget.diary.api?.supportsServerIdentity == true &&
          controller?.capsules != null) {
        await widget.diary.signInAuthor();
        await widget.diary.api!.enqueueDurablePublication(
          value,
          published: publish,
        );
        await controller!.cloudQueue.enqueue(
          'alchemist_diary_queue:${value.id}',
        );
        if (mounted) {
          unawaited(
            Navigator.pushReplacement<void, void>(
              context,
              MaterialPageRoute(
                builder: (_) => AlchemistSyncScreen(
                  controller: controller,
                  focusName: 'alchemist_diary_queue:${value.id}',
                ),
              ),
            ),
          );
        }
        return;
      }
      if (publish == null) {
        await widget.diary.saveToCloud(value);
      } else {
        await widget.diary.publish(value, published: publish);
      }
      entry = widget.diary.drafts.firstWhere((e) => e.id == entry.id);
      if (mounted) {
        setState(
          () => saved = publish == null
              ? 'Сохранено на Диске'
              : publish
              ? 'Публикация подтверждена'
              : 'Публикация снята',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DiaryApiException
              ? e.message
              : 'Сервер не подтвердил действие. Черновик сохранён на телефоне.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add(DiaryBlockType type, {DiaryBlock? replacing}) async {
    if (type == DiaryBlockType.text) {
      setState(() => blocks.add(DiaryBlock(id: newId(), type: type)));
      changed();
      return;
    }
    final store = widget.diary.mediaStore;
    if (store == null) {
      setState(() => error = 'Импорт вложений не настроен');
      return;
    }
    var record = false;
    if (type == DiaryBlockType.audio) {
      final method = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Записать аудио'),
                onTap: () => Navigator.pop(context, 'record'),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Выбрать с телефона'),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
            ],
          ),
        ),
      );
      if (method == null || !mounted) return;
      record = method == 'record';
      if (record && !await save()) return;
      if (!mounted) return;
    }
    setState(() => busy = true);
    try {
      DiaryBlock? imported;
      var committed = false;
      if (record) {
        if (widget.recordAudio != null) {
          imported = await widget.recordAudio!();
        } else {
          final scope = SessionScope.maybeOf(context);
          if (scope == null) {
            throw const FormatException('Диктофон недоступен в этом контексте');
          }
          imported = await Navigator.push<DiaryBlock>(
            context,
            MaterialPageRoute(
              builder: (_) => RecorderScreen(
                controller: scope.controller,
                player: scope.player,
                diaryRecording: true,
                backend: widget.captureBackend,
                attachDiaryBlock: (block) async {
                  final attached = await _commitAttachment(block, replacing);
                  committed = true;
                  return attached;
                },
              ),
            ),
          );
        }
        if (replacing != null && imported != null) {
          imported = DiaryBlock.fromMap({
            ...imported.toMap(),
            'id': replacing.id,
          });
        }
      } else {
        imported = await store.import(type, blockId: replacing?.id);
      }
      if (imported != null && !committed) {
        imported = await _commitAttachment(imported, replacing);
      }
      final added = imported;
      if (added != null && mounted) {
        setState(() {
          if (replacing == null) {
            blocks.add(added);
          } else {
            final index = blocks.indexWhere((b) => b.id == replacing.id);
            if (index >= 0) {
              blocks[index] = added.copyWith(
                altText: replacing.altText,
                caption: replacing.caption,
                label: replacing.label,
              );
            }
          }
        });
        changed();
        await save();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Не удалось импортировать файл. Старое вложение сохранено.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<DiaryBlock> _commitAttachment(
    DiaryBlock block,
    DiaryBlock? replacing,
  ) async {
    final attached = replacing == null
        ? block
        : DiaryBlock.fromMap({...block.toMap(), 'id': replacing.id}).copyWith(
            altText: replacing.altText,
            caption: replacing.caption,
            label: replacing.label,
          );
    final next = List<DiaryBlock>.of(blocks);
    final index = replacing == null
        ? -1
        : next.indexWhere((b) => b.id == replacing.id);
    if (index < 0) {
      next.add(attached);
    } else {
      next[index] = attached;
    }
    await tail;
    await widget.diary.saveDraft(value.copyWith(blocks: next));
    return attached;
  }

  void reorder(int old, int next) {
    setState(() {
      if (next > old) next--;
      final item = blocks.removeAt(old);
      blocks.insert(next, item);
    });
    changed();
  }

  void remove(DiaryBlock b) {
    final index = blocks.indexOf(b);
    setState(() => blocks.remove(b));
    changed();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Блок удалён из черновика'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            if (!mounted || blocks.any((v) => v.id == b.id)) return;
            setState(() => blocks.insert(index.clamp(0, blocks.length), b));
            changed();
          },
        ),
      ),
    );
  }

  Future<void> metadata(DiaryBlock b) async {
    final caption = TextEditingController(
      text: b.type == DiaryBlockType.image ? b.caption : b.label,
    );
    final alt = TextEditingController(text: b.altText);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Свойства блока'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caption,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: b.type == DiaryBlockType.image
                      ? 'Подпись'
                      : 'Название аудио',
                ),
              ),
              if (b.type == DiaryBlockType.image)
                TextField(
                  controller: alt,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Описание для доступности',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      setState(
        () => blocks[blocks.indexWhere((v) => v.id == b.id)] =
            b.type == DiaryBlockType.image
            ? b.copyWith(caption: caption.text, altText: alt.text)
            : b.copyWith(label: caption.text),
      );
      changed();
    }
    // Dialog route may still animate: dispose after its subtree is gone.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    caption.dispose();
    alt.dispose();
  }

  void publication(DiaryPublication next) {
    setState(() => entry = next.apply(entry));
    changed();
  }

  Future<void> expiry() async {
    final input = TextEditingController(
      text:
          DiaryPublication.of(entry).validUntil?.toUtc().toIso8601String() ??
          '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Срок видимости'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            labelText: 'UTC: 2026-12-01T18:00:00Z',
            helperText: 'Пусто — без срока',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final value = input.text.trim();
              if (value.isEmpty ||
                  (value.endsWith('Z') && DateTime.tryParse(value) != null)) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      publication(
        DiaryPublication.of(entry).changed(
          validUntil: DateTime.tryParse(result)?.toUtc(),
          clearExpiry: result.isEmpty,
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    input.dispose();
  }

  Widget publicationControls() {
    final p = DiaryPublication.of(entry);
    return ExpansionTile(
      key: const Key('diary-publication-settings'),
      title: const Text('Категория и показ записи'),
      children: [
        const Text(
          'Настройки сохраняются локально. Новый серверный контракт ещё не подключён.',
          style: TextStyle(fontSize: 11),
        ),
        DropdownButtonFormField<String>(
          initialValue: p.categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Категория'),
          items: [
            for (final item in diaryCategories.entries)
              DropdownMenuItem(
                value: item.key,
                child: Text(item.value, maxLines: 2),
              ),
            if (!diaryCategories.containsKey(p.categoryId))
              DropdownMenuItem(
                value: p.categoryId,
                child: Text('Неизвестная категория: ${p.categoryId}'),
              ),
          ],
          onChanged: busy ? null : (v) => publication(p.changed(categoryId: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Высокий приоритет'),
          value: p.highPriority,
          onChanged: busy
              ? null
              : (v) => publication(p.changed(highPriority: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Срочно'),
          value: p.urgent,
          onChanged: busy ? null : (v) => publication(p.changed(urgent: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Закрыть показ'),
          value: p.authorClosed,
          onChanged: busy
              ? null
              : (v) => publication(p.changed(authorClosed: v)),
        ),
        TextButton(
          onPressed: busy ? null : expiry,
          child: Text(
            p.validUntil == null
                ? 'Без срока · изменить'
                : 'До ${p.validUntil!.toUtc().toIso8601String()}',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => publication(p.changed(reannounce: true)),
          child: const Text('Показать снова как новое'),
        ),
      ],
    );
  }

  Future<void> addContent() async {
    final link = await pickDiaryContent(context);
    if (link == null || !mounted) return;
    setState(
      () => entry = entry.copyWith(
        extra: {
          ...entry.extra,
          'contentLinks': [
            if (entry.extra['contentLinks'] is List)
              ...entry.extra['contentLinks'],
            if (!entry.contentLinks.any(
              (v) =>
                  v.key.token == link.key.token &&
                  v.key.digest == link.key.digest,
            ))
              link.toMap(),
          ],
        },
      ),
    );
    changed();
    await save();
  }

  Widget addBlockActions() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    children: [
      for (final type in DiaryBlockType.values)
        OutlinedButton.icon(
          key: ValueKey('diary-add-${type.name}'),
          onPressed: busy ? null : () => add(type),
          icon: Icon(switch (type) {
            DiaryBlockType.text => Icons.notes,
            DiaryBlockType.image => Icons.image_outlined,
            DiaryBlockType.audio => Icons.mic_none,
            DiaryBlockType.video => Icons.video_library_outlined,
          }, color: neonLime),
          label: Text(switch (type) {
            DiaryBlockType.text => 'Текст',
            DiaryBlockType.image => 'Изображение',
            DiaryBlockType.audio => 'Аудио',
            DiaryBlockType.video => 'Видео',
          }),
        ),
    ],
  );

  Widget blockCard(int i) {
    final b = blocks[i];
    final name = switch (b.type) {
      DiaryBlockType.text => 'Текст',
      DiaryBlockType.image => 'Изображение',
      DiaryBlockType.audio => 'Аудио',
      DiaryBlockType.video => 'Видео',
    };
    return Padding(
      key: ValueKey(b.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: NeonPanel(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  enabled: !busy,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: 'Перетащить блок',
                      child: Icon(Icons.drag_indicator, color: neonPink),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: neonLime,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Действия блока',
                  enabled: !busy,
                  onSelected: (a) {
                    if (a == 'up' && i > 0) reorder(i, i - 1);
                    if (a == 'down' && i < blocks.length - 1) reorder(i, i + 2);
                    if (a == 'meta') unawaited(metadata(b));
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'up',
                      enabled: i > 0,
                      child: const Text('Выше'),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      enabled: i < blocks.length - 1,
                      child: const Text('Ниже'),
                    ),
                    if (b.type != DiaryBlockType.text)
                      const PopupMenuItem(
                        value: 'meta',
                        child: Text('Название / описание'),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Удалить блок',
                  onPressed: busy ? null : () => remove(b),
                  icon: const Icon(Icons.delete_outline, color: neonPink),
                ),
              ],
            ),
            if (b.type == DiaryBlockType.text)
              TextField(
                key: ValueKey('text-${b.id}'),
                enabled: !busy,
                controller: textControllers.putIfAbsent(
                  b.id,
                  () => TextEditingController(text: b.text),
                ),
                minLines: 3,
                maxLines: null,
                onChanged: (s) {
                  blocks[i] = blocks[i].copyWith(text: s);
                  changed();
                },
                decoration: const InputDecoration(labelText: 'Текст блока'),
              ),
            if (b.type == DiaryBlockType.image)
              SizedBox(
                height: 140,
                child: DiaryImage(block: b, diary: widget.diary),
              ),
            if (b.type == DiaryBlockType.video)
              SizedBox(
                height: 220,
                child: DiaryVideo(block: b, diary: widget.diary),
              ),
            if (b.type == DiaryBlockType.audio)
              Text(
                '${b.label.isEmpty ? 'Аудио' : b.label} · ${diaryTime(b.durationMs == null ? null : Duration(milliseconds: b.durationMs!))}',
              ),
            if (b.type != DiaryBlockType.text)
              TextButton.icon(
                onPressed: busy ? null : () => add(b.type, replacing: b),
                icon: const Icon(Icons.sync),
                label: const Text('Заменить'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    title.dispose();
    message.dispose();
    for (final c in textControllers.values) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.diary.authorWorkspace) {
      return const Scaffold(
        body: Center(child: Text('Авторский режим недоступен')),
      );
    }
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (p, _) {
        if (!p) unawaited(close());
      },
      child: Stack(
        children: [
          LeatherScaffold(
            title: 'Редактор записи',
            actions: [
              IconButton(
                tooltip: 'Сохранить и закрыть',
                onPressed: busy ? null : close,
                icon: const Icon(Icons.check),
              ),
            ],
            child: Column(
              children: [
                if (busy) const LinearProgressIndicator(minHeight: 2),
                Text(
                  entry.number == null
                      ? 'Черновик · без номера'
                      : 'Запись №${entry.number}',
                  style: const TextStyle(fontSize: 12, color: neonLime),
                ),
                if (previewIssue != null)
                  Text(
                    previewIssue!,
                    style: const TextStyle(fontSize: 11, color: neonPink),
                  ),
                if (error != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Text(
                        error!,
                        style: const TextStyle(color: neonPink, fontSize: 12),
                      ),
                    ),
                  ),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scroll,
                    buildDefaultDragHandles: false,
                    onReorderItem: (old, next) =>
                        reorder(old, next > old ? next + 1 : next),
                    itemCount: blocks.length,
                    header: Column(
                      children: [
                        TextField(
                          key: const Key('diary-title'),
                          enabled: !busy,
                          controller: title,
                          onChanged: changed,
                          maxLines: null,
                          decoration: const InputDecoration(
                            labelText: 'Название записи',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('diary-message'),
                          enabled: !busy,
                          controller: message,
                          onChanged: changed,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Короткое послание',
                          ),
                          style: const TextStyle(color: neonPink),
                        ),
                        publicationControls(),
                        for (final link in entry.contentLinks)
                          ListTile(
                            dense: true,
                            title: Text(
                              '${link.key.content.type.name} · ${link.key.content.id}',
                            ),
                            subtitle: Text(
                              'Точная ревизия ${link.key.digest.substring(0, 12)}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Удалить ссылку на материал',
                              icon: const Icon(Icons.close),
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(
                                        () => entry = entry.copyWith(
                                          extra: {
                                            ...entry.extra,
                                            'contentLinks': entry.contentLinks
                                                .where(
                                                  (v) =>
                                                      v.key.token !=
                                                          link.key.token ||
                                                      v.key.digest !=
                                                          link.key.digest,
                                                )
                                                .map((v) => v.toMap())
                                                .toList(),
                                          },
                                        ),
                                      );
                                      changed();
                                    },
                            ),
                          ),
                        TextButton.icon(
                          key: const Key('diary-add-content'),
                          onPressed: busy ? null : addContent,
                          icon: const Icon(Icons.link),
                          label: Text(
                            (widget.diary.api?.supportsServerIdentity ?? false)
                                ? 'Добавить из каталога'
                                : 'Добавить материал',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Содержание',
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    itemBuilder: (_, i) => blockCard(i),
                    footer: const SizedBox.shrink(),
                  ),
                ),
                addBlockActions(),
                Text(
                  '$saved · ${pages == null ? 'Расчёт страниц…' : 'Страниц: $pages'}',
                  style: const TextStyle(fontSize: 11, color: antiqueGold),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: busy ? null : preview,
                      child: const Text('Предпросмотр'),
                    ),
                    TextButton(
                      onPressed: busy ? null : save,
                      child: const Text('Сохранить черновик'),
                    ),
                    if (widget.diary.api != null &&
                        (widget.diary.policy?.clientEdition != true))
                      TextButton(
                        onPressed: busy ? null : () => cloud(),
                        child: const Text('Сохранить на Диск'),
                      ),
                    if (widget.diary.policy?.clientEdition != true)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: neonLime,
                          foregroundColor: ink,
                        ),
                        onPressed: busy ? null : () => cloud(publish: true),
                        child: const Text('К публикации'),
                      ),
                    if (entry.status == DiaryStatus.published &&
                        (widget.diary.policy?.clientEdition != true))
                      TextButton(
                        onPressed: busy ? null : () => cloud(publish: false),
                        child: const Text('Снять публикацию'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Offstage(
              offstage: true,
              child: DiaryReader(
                entry: value,
                preview: true,
                calculateOnly: true,
                onLayout: (layout, _, h) {
                  final issue =
                      MediaQuery.textScalerOf(context).scale(16) <= 16 &&
                          layout.header.height > h
                      ? 'Название и послание не помещаются на первую страницу. Сократите верхний блок.'
                      : null;
                  if (mounted &&
                      (pages != layout.pages.length || previewIssue != issue)) {
                    setState(() {
                      pages = layout.pages.length;
                      previewIssue = issue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
