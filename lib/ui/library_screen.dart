import '../services/session_controller.dart';
import 'recorder_screen.dart';
import 'modules_screen.dart';
import 'module_assignment.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../services/library_service.dart';
import '../services/preview_player.dart';
import 'asset_editor.dart';
import 'design.dart';
import 'preview_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.library,
    required this.player,
    this.allowSelection = false,
    this.controller,
    this.onReset,
  });
  final LibraryService library;
  final SessionController? controller;
  final PreviewPlayer player;
  final bool allowSelection;
  final Future<void> Function()? onReset;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  List<AudioAsset> _assets = [];
  bool _busy = true, _asking = false;
  String? _loadError;
  String _query = '';
  bool _searchAll = true;
  LibrarySection _section = LibrarySection.general;
  AudioCategory? _category;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(Future.microtask(widget.player.stop));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.player.stop());
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _loadError = null;
      });
    }
    try {
      final items = await widget.library.repository.list();
      if (mounted) setState(() => _assets = items);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _loadError = 'Не удалось открыть библиотеку. Данные не удалены.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _ask<T>(Future<T?> Function() f) async {
    setState(() => _asking = true);
    try {
      return await f();
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      _message(
        e is LibraryException
            ? e.message
            : 'Не удалось выполнить действие. Повторите попытку.',
      );
    } finally {
      if (mounted) await _load();
    }
  }

  Future<void> _import() => _run(() async {
    await widget.player.stop();
    final draft = await widget.library.prepareImport();
    if (draft == null) return;
    var saved = false;
    try {
      if (!mounted) return;
      final choice = ModuleChoice();
      final edited = await _ask(
        () => editAsset(
          context,
          draft,
          catalog: widget.controller?.modules,
          choice: choice,
        ),
      );
      if (edited == null) return;
      await widget.library.save(edited);
      saved = true;
      if (widget.controller != null) {
        try {
          await attachAudioToModule(widget.controller!.modules, choice, edited);
        } catch (_) {
          _message("Трек сохранён, но связь с модулем не сохранена.");
        }
      }
      _section = edited.section;
    } finally {
      if (!saved) await widget.library.discard(draft);
    }
  });
  Future<void> _edit(AudioAsset asset) => _run(() async {
    await widget.player.stop();
    final edited = await _ask(() => editAsset(context, asset));
    if (edited != null) {
      await widget.library.save(edited);
      _section = edited.section;
    }
  });
  Future<void> _delete(AudioAsset asset) => _run(() async {
    final confirmed = await _ask(
      () => confirmAction(
        context,
        'Удалить аудио?',
        '«${asset.title}» будет удалено из приложения. История сохранит сведения о треке, но прослушать удалённый файл будет нельзя. Исходный файл останется на месте.',
        confirm: 'Удалить',
      ),
    );
    if (confirmed != true) return;
    if (widget.player.current?.id == asset.id) await widget.player.stop();
    await widget.library.delete(asset);
  });
  Future<void> _reset() => _run(() async {
    final confirmed = await _ask(
      () => confirmAction(
        context,
        'Удалить все данные?',
        'Библиотека, шаблоны, текущая конфигурация и история будут удалены с этого устройства. Исходные файлы останутся на месте.',
        confirm: 'Удалить всё',
      ),
    );
    if (confirmed != true) return;
    await widget.player.stop();
    if (widget.onReset != null) {
      await widget.onReset!();
    } else {
      await widget.library.reset();
    }
  });
  Future<void> _preview(AudioAsset a) =>
      _run(() => widget.player.toggle(a, widget.library.fileFor(a)));
  void _privacy() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ваше пространство',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Все аудио и заметки хранятся на этом устройстве. Нет облака, аналитики и передачи записей. Сохраняйте исходные файлы отдельно: удаление приложения удаляет его данные.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Инструмент саморегуляции не заменяет медицинскую помощь. Не используйте за рулём. Предпрослушивание останавливается при уходе в фон.',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                unawaited(_reset());
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить все данные приложения'),
            ),
            const SizedBox(height: 12),
            const Text('Sulfi · 0.2.0', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final visible = _assets
        .where(
          (a) =>
              ((q.isNotEmpty && _searchAll) || a.section == _section) &&
              (_category == null || a.category == _category) &&
              '${a.title} ${a.description} ${a.category.label} ${a.tags.join(' ')}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    return LeatherScaffold(
      title: widget.allowSelection ? 'Выбрать аудио' : 'Библиотека',
      actions: [
        if (widget.controller != null)
          IconButton(
            tooltip: 'Каталог модулей',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ModulesScreen(
                    controller: widget.controller!,
                    player: widget.player,
                  ),
                ),
              );
              await _load();
            },
          ),
        if (widget.controller != null)
          IconButton(
            tooltip: 'Записать свой трек',
            icon: const Icon(Icons.mic_none),
            onPressed: () async {
              await widget.player.stop();
              if (!context.mounted) return;
              await Navigator.push<AudioAsset>(
                context,
                MaterialPageRoute(
                  builder: (_) => RecorderScreen(
                    controller: widget.controller!,
                    player: widget.player,
                  ),
                ),
              );
              await _load();
            },
          ),

        IconButton(
          tooltip: 'О приложении и данных',
          onPressed: _busy ? null : _privacy,
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
      bottom: PreviewBar(player: widget.player, library: widget.library),
      child: ListenableBuilder(
        listenable: widget.player,
        builder: (context, _) => CustomScrollView(
          slivers: [
            if (_busy && !_asking)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ваши записи. Ваш темп.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_assets.length} аудио · ${formatDuration(_assets.fold(0, (n, a) => n + a.durationMs))} · только на устройстве',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    NeonButton(
                      label: 'Добавить аудио',
                      icon: Icons.add,
                      onPressed: _busy || _loadError != null ? null : _import,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MP3, M4A, WAV · копия внутри приложения',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: LibrarySection.values
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(switch (s) {
                                    LibrarySection.general => 'Общие',
                                    LibrarySection.suggestions => 'Установки',
                                    LibrarySection.personal => 'Мои',
                                  }),
                                  selected: _section == s,
                                  onSelected: (_) => setState(() {
                                    _section = s;
                                    _searchAll = false;
                                  }),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Найти аудио',
                        hintText: 'Название, описание, метки',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: _searchAll
                              ? 'Поиск по всей библиотеке'
                              : 'Поиск в выбранном разделе',
                          onPressed: () =>
                              setState(() => _searchAll = !_searchAll),
                          icon: Icon(
                            _searchAll
                                ? Icons.manage_search
                                : Icons.folder_open,
                          ),
                        ),
                      ),
                      onChanged: (s) => setState(() => _query = s),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Все категории'),
                            selected: _category == null,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                          ...AudioCategory.values.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: CategoryLabel(c),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loadError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_loadError!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visible.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.graphic_eq, size: 48, color: neonPink),
                      const SizedBox(height: 12),
                      Text(
                        _assets.isEmpty
                            ? 'Начните с одной записи'
                            : 'Записи не найдены. Измените поиск.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _assets.isEmpty
                            ? 'Добавьте готовое аудио с устройства. Название, описание и категорию можно изменить перед сохранением.'
                            : 'В этом разделе пока нет подходящих аудио.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(visible[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(AudioAsset a) {
    final playing = widget.player.current?.id == a.id && widget.player.playing;
    return NeonPanel(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                tooltip: playing ? 'Пауза' : 'Прослушать ${a.title}',
                onPressed: _busy ? null : () => _preview(a),
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(a.title),
                      content: SingleChildScrollView(
                        child: Text(
                          '${a.description.isEmpty ? 'Без описания' : a.description}\n\n${a.section.label} · ${a.category.label}\n${formatDuration(a.durationMs)} · ${a.format.toUpperCase()}\n${a.tags.join(', ')}',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      CategoryLabel(a.category),
                      if (a.description.isNotEmpty)
                        Text(
                          a.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatDuration(a.durationMs)} · ${a.format.toUpperCase()} · ${(a.fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} МБ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия с аудио',
                enabled: !_busy,
                onSelected: (s) => s == 'edit' ? _edit(a) : _delete(a),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Изменить название и категорию'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          if (widget.allowSelection)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : () => Navigator.pop(context, a),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Добавить в сессию'),
              ),
            ),
        ],
      ),
    );
  }
}
