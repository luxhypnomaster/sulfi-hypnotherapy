import 'alchemist_store_screen.dart';
import 'alchemist_catalog_screen.dart';
import '../models/content_revision.dart';
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
import 'content_export.dart';
import 'space_sheet.dart';
import 'session_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.library,
    required this.player,
    this.allowSelection = false,
    this.controller,
    this.onReset,
    this.onSelected,
  });
  final LibraryService library;
  final SessionController? controller;
  final PreviewPlayer player;
  final bool allowSelection;
  final Future<void> Function(AudioAsset)? onSelected;
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
  LibrarySection _section = LibrarySection.general;
  final Set<AudioCategory> _categories = {};
  final GlobalKey _categoryButton = GlobalKey();
  bool _selecting = false;
  bool _initialLoad = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      if (mounted) {
        setState(() {
          _assets = items;
          if (_initialLoad &&
              items.isNotEmpty &&
              items.every((a) => a.section == LibrarySection.personal)) {
            _section = LibrarySection.personal;
          }
          _initialLoad = false;
        });
      }
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
          policy: widget.library.policy,
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
    final edited = await _ask(
      () => editAsset(context, asset, policy: widget.library.policy),
    );
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
  void _privacy() => showSpaceSheet(
    context,
    library: widget.library,
    controller: widget.controller,
    player: widget.player,
    onReset: _reset,
    onChanged: _load,
  );
  bool _matches(AudioAsset a) {
    final section = switch (_section) {
      LibrarySection.general => a.section == LibrarySection.general,
      LibrarySection.suggestions => a.section == LibrarySection.suggestions,
      LibrarySection.personal => a.section == LibrarySection.personal,
    };
    final category =
        _categories.isEmpty ||
        _categories.any(
          (c) =>
              c == a.category ||
              c == AudioCategory.suggestions && a.isSuggestion,
        );
    final q = _query.trim().toLowerCase();
    return section &&
        category &&
        '${a.title} ${a.description} ${a.category.label} ${a.tags.join(' ')}'
            .toLowerCase()
            .contains(q);
  }

  Future<void> _categoriesMenu() async {
    final box =
        _categoryButton.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final top = origin.dy + box.size.height + 4;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, updateMenu) {
          final media = MediaQuery.of(context);
          void change(VoidCallback f) {
            setState(f);
            updateMenu(() {});
          }

          final width = (240 * media.textScaler.scale(1)).clamp(
            0.0,
            media.size.width - 16,
          );
          final below =
              media.size.height -
              media.padding.bottom -
              media.viewInsets.bottom -
              top -
              8;
          final above = origin.dy - media.padding.top - 8;
          final upwards = below < 160 && above > below;
          return Stack(
            children: [
              Positioned(
                left: origin.dx.clamp(8.0, media.size.width - width - 8),
                top: upwards ? null : top,
                bottom: upwards ? media.size.height - origin.dy + 4 : null,
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (upwards ? above - 4 : below).clamp(
                      48.0,
                      media.size.height,
                    ),
                  ),
                  child: Material(
                    key: const Key('library-category-menu'),
                    color: const Color(0xFF260719),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: neonPink),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        CheckboxListTile(
                          key: const Key('category-all'),
                          minTileHeight: 40,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          title: const Text(
                            'Все категории',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: _categories.isEmpty,
                          activeColor: neonLime,
                          checkColor: ink,
                          onChanged: (_) => change(_categories.clear),
                        ),
                        for (final c in AudioCategory.values)
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Color(0x667F2751),
                                  width: .5,
                                ),
                              ),
                            ),
                            child: CheckboxListTile(
                              key: ValueKey('category-${c.name}'),
                              minTileHeight: 40,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: categoryColor(c),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      c.label,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              value: _categories.contains(c),
                              activeColor: neonLime,
                              checkColor: ink,
                              onChanged: (selected) => change(() {
                                if (selected == true) {
                                  _categories.add(c);
                                } else {
                                  _categories.remove(c);
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _select(AudioAsset a) async {
    if (_selecting || _busy) return;
    if (widget.onSelected == null) {
      Navigator.pop(context, a);
      return;
    }
    setState(() => _selecting = true);
    try {
      await widget.onSelected!(a);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Добавлено'),
            duration: Duration(milliseconds: 650),
          ),
        );
      }
    } catch (_) {
      _message('Не удалось добавить трек. Повторите попытку.');
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  void _details(AudioAsset a) => showDialog<void>(
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
  );

  Widget _toolbar() => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
      return SingleChildScrollView(
        key: const Key('library-toolbar-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: box.maxWidth * scale,
          child: Row(
            key: const Key('library-toolbar'),
            children: [
              Expanded(
                key: _categoryButton,
                flex: 3,
                child: OutlinedButton(
                  key: const Key('library-categories'),
                  onPressed: _categoriesMenu,
                  style: _thinButton(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categories.isEmpty
                              ? 'Все категории'
                              : 'Категории · ${_categories.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB48A9D)),
                  ),
                  child: Row(
                    children: [
                      for (final s in LibrarySection.values)
                        Expanded(
                          flex: s == LibrarySection.general
                              ? 3
                              : s == LibrarySection.suggestions
                              ? 5
                              : 2,
                          child: TextButton(
                            key: ValueKey('library-section-${s.name}'),
                            onPressed: () => setState(() => _section = s),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              backgroundColor: _section == s
                                  ? neonLime
                                  : Colors.transparent,
                              foregroundColor: _section == s
                                  ? ink
                                  : const Color(0xFFF1E3E9),
                            ),
                            child: Text(switch (s) {
                              LibrarySection.general => 'Общие',
                              LibrarySection.suggestions => 'Установки',
                              LibrarySection.personal => 'Мои',
                            }, style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  onPressed: _busy || _loadError != null ? null : _import,
                  style: _thinButton(pink: true),
                  child: const Text(
                    '+ Добавить аудио',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  ButtonStyle _thinButton({bool pink = false}) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: const Color(0xFFF1E3E9),
    side: BorderSide(color: pink ? neonPink : const Color(0xFFB48A9D)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  @override
  Widget build(BuildContext context) {
    final visible = _assets.where(_matches).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF16040D),
      bottomNavigationBar: SafeArea(
        top: false,
        child: PreviewBar(
          player: widget.player,
          library: widget.library,
          compact: true,
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.player,
          builder: (context, _) => CustomScrollView(
            key: const Key('library-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (ModalRoute.of(context)?.canPop ?? false)
                            IconButton(
                              tooltip: 'Назад',
                              icon: const Icon(
                                Icons.arrow_back,
                                color: neonPink,
                              ),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.allowSelection
                                      ? 'Выбрать аудио'
                                      : 'Библиотека',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${_assets.length} аудио · ${formatDuration(_assets.fold(0, (n, a) => n + a.durationMs))}',
                                  key: const Key('library-summary'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (!widget.allowSelection &&
                              widget.controller?.capsules != null)
                            SizedBox(
                              width: 52,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlchemistStoreScreen(
                                      controller: widget.controller!,
                                    ),
                                  ),
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_outlined, size: 20),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Каталог',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.controller != null) ...[
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
                          ],
                          IconButton(
                            tooltip: 'О приложении и данных',
                            onPressed: _busy ? null : _privacy,
                            icon: const Icon(Icons.shield_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _toolbar(),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('library-search'),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Найти аудио',
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                        ),
                        onChanged: (s) => setState(() => _query = s),
                      ),
                      if (_busy && !_asking)
                        const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ),
              if (_loadError != null)
                SliverToBoxAdapter(
                  child: TextButton(onPressed: _load, child: Text(_loadError!)),
                )
              else if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _assets.isEmpty
                          ? 'Начните с одной записи'
                          : 'Записи не найдены. Измените поиск.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) => _row(visible[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(AudioAsset a) {
    final playing = widget.player.current?.id == a.id && widget.player.playing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          widget.allowSelection ? 'pick-${a.id}' : 'library-${a.id}',
        ),
        onTap: _busy || _selecting
            ? null
            : widget.allowSelection
            ? () => _select(a)
            : () => _details(a),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x997D194B), width: .5),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: widget.allowSelection
                    ? 'Прослушать: ${a.title}'
                    : playing
                    ? 'Пауза'
                    : 'Прослушать ${a.title}',
                onPressed: _busy ? null : () => _preview(a),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                iconSize: 22,
                padding: EdgeInsets.zero,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.library.policy.isCatalogOriginal('track', a.id))
                      const Text('Официальный', style: TextStyle(fontSize: 11)),
                    CategoryLabel(a.category),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                formatDuration(a.durationMs),
                style: const TextStyle(fontSize: 12),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия с аудио',
                enabled: !_busy,
                padding: EdgeInsets.zero,
                iconSize: 20,
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 36),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelected: (s) {
                  if ((s == 'publish' || s == 'catalog')) {
                    unawaited(
                      preparePublication(
                        context,
                        widget.controller!,
                        ContentType.track,
                        a.id,
                        catalogOnly: s == 'catalog',
                      ),
                    );
                  }
                  if (s == 'info') _details(a);
                  if (s == 'export') {
                    unawaited(
                      showActionError(
                        context,
                        () => exportMaterial(
                          context,
                          widget.controller!.capsules!,
                          trackId: a.id,
                        ),
                      ),
                    );
                  }
                  if (s == 'edit') _edit(a);
                  if (s == 'delete') _delete(a);
                },
                itemBuilder: (_) => [
                  if (widget.controller?.capsules != null &&
                      widget.library.policy.isAuthor) ...[
                    const PopupMenuItem(
                      value: 'catalog',
                      child: Text('Добавить в каталог'),
                    ),
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Подготовить к публикации'),
                    ),
                  ],
                  if (widget.controller?.capsules != null)
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Экспортировать на устройство'),
                    ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('Сведения о треке'),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    enabled: widget.library.policy.canEditAudio(a),
                    child: Text('Изменить название и категорию'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: widget.library.policy.canEditAudio(a),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
