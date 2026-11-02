import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../services/library_service.dart';
import '../services/preview_player.dart';
import 'asset_editor.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.library, required this.player});
  final LibraryService library;
  final PreviewPlayer player;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  List<AudioAsset> _assets = [];
  bool _busy = true;
  bool _asking = false;
  String? _loadError;
  String _query = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.player.addListener(_playerChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.player.removeListener(_playerChanged);
    unawaited(widget.player.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This slice provides foreground preview only. Never promise background
    // session playback until the foreground-service milestone is implemented.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.player.stop());
    }
  }

  void _playerChanged() {
    if (mounted) setState(() {});
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _loadError = null;
    });
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

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(
        error is LibraryException
            ? error.message
            : 'Не удалось выполнить действие. Повторите попытку.',
      );
    } finally {
      if (mounted) await _load();
    }
  }

  Future<T?> _ask<T>(Future<T?> Function() show) async {
    setState(() => _asking = true);
    try {
      return await show();
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _import() => _run(() async {
    await widget.player.stop();
    final draft = await widget.library.prepareImport();
    if (draft == null) return;
    var saved = false;
    try {
      if (!mounted) return;
      final edited = await _ask(() => editAsset(context, draft));
      if (edited == null) return;
      await widget.library.save(edited);
      saved = true;
    } finally {
      if (!saved) await widget.library.discard(draft);
    }
  });

  Future<void> _edit(AudioAsset asset) => _run(() async {
    final edited = await _ask(() => editAsset(context, asset));
    if (edited != null) await widget.library.save(edited);
  });

  Future<bool> _confirm(String title, String message, String button) async =>
      await _ask(
        () => showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(button),
              ),
            ],
          ),
        ),
      ) ??
      false;

  Future<void> _delete(AudioAsset asset) => _run(() async {
    if (!await _confirm(
      'Удалить аудио?',
      '«${asset.title}» будет удалено из приложения. Исходный файл останется на месте.',
      'Удалить',
    )) {
      return;
    }
    if (widget.player.current?.id == asset.id) await widget.player.stop();
    await widget.library.delete(asset);
  });

  Future<void> _reset() => _run(() async {
    if (!await _confirm(
      'Удалить все данные?',
      'Все импортированные аудио и их названия будут удалены из приложения. Это действие нельзя отменить. Исходные файлы останутся на месте.',
      'Удалить всё',
    )) {
      return;
    }
    await widget.player.stop();
    await widget.library.reset();
  });

  Future<void> _preview(AudioAsset asset) => _run(() async {
    await widget.player.toggle(asset, widget.library.fileFor(asset));
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(widget.player.stop());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'СУЛЬФИ',
            style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'О приложении и данных',
              icon: const Icon(Icons.shield_outlined),
              onPressed: _busy
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ваше пространство',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Аудио хранится только на этом устройстве. Приложение не отправляет записи в интернет и не использует микрофон на этом этапе.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Это инструмент саморегуляции, а не медицинская помощь. Не слушайте записи за рулём. Выбирайте безопасное место, где можно спокойно остановиться.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Удаление приложения удалит библиотеку. Сохраняйте исходные файлы отдельно. Обновление поверх установленного приложения сохраняет данные.',
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  unawaited(_reset());
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text(
                                  'Удалить все данные приложения',
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Версия 0.1.0 · этап 1',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  if (_busy && !_asking)
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: switch (_tab) {
                      0 => _library(context),
                      1 => const _FuturePage(
                        icon: Icons.view_timeline_outlined,
                        title: 'Из аудио — в сессию',
                        description: 'Сначала соберите библиотеку. На следующем этапе здесь появится конструктор: аудио, тишина и запись с микрофона с настраиваемой длительностью.',
                      ),
                      _ => const _FuturePage(
                        icon: Icons.self_improvement_outlined,
                        title: 'Время для себя',
                        description: 'Проигрывание сессий и история появятся после конструктора. Сейчас можно прослушивать отдельные записи в библиотеке.',
                      ),
                    },
                  ),
                  if (widget.player.error case final String error)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error, style: TextStyle(color: colors.error)),
                    ),
                  if (widget.player.current case final AudioAsset current)
                    _previewBar(context, current),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music),
              label: 'Библиотека',
            ),
            NavigationDestination(
              icon: Icon(Icons.view_timeline_outlined),
              label: 'Шаблоны',
            ),
            NavigationDestination(
              icon: Icon(Icons.self_improvement_outlined),
              label: 'Сессии',
            ),
          ],
        ),
      ),
    );
  }

  Widget _library(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _assets
        .where(
          (asset) => '${asset.title} ${asset.category.label}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Голос, который\nпомогает замедлиться',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ваши записи. Ваш темп.\nСоберите личную аудиобиблиотеку Сульфи.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.offline_bolt_outlined,
                          color: colors.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '${_assets.length} аудио · ${formatDuration(_assets.fold(0, (sum, item) => sum + item.durationMs))}\nТолько на вашем устройстве',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || _loadError != null ? null : _import,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить аудио'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MP3, M4A, WAV · копия внутри приложения',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 28),
                Text(
                  'Аудиобиблиотека',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_assets.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Найти по названию или категории',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_loadError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(_loadError!),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          )
        else if (_assets.isEmpty && !_busy)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 8, 32, 40),
              child: Column(
                children: [
                  Icon(Icons.graphic_eq, size: 56, color: Color(0xFFE28BC8)),
                  SizedBox(height: 16),
                  Text(
                    'Начните с одной записи',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Добавьте готовое аудио с устройства. Название и категорию можно изменить перед сохранением.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (visible.isEmpty && !_busy)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Записи не найдены. Измените поиск.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _assetCard(context, visible[index]),
            ),
          ),
      ],
    );
  }

  Widget _assetCard(BuildContext context, AudioAsset asset) {
    final active =
        widget.player.current?.id == asset.id && widget.player.playing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: active ? 'Пауза' : 'Прослушать ${asset.title}',
              onPressed: _busy ? null : () => _preview(asset),
              icon: Icon(active ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${asset.category.label} · ${formatDuration(asset.durationMs)}',
                  ),
                  Text(
                    '${asset.format.toUpperCase()} · ${(asset.fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} МБ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Действия с аудио',
              enabled: !_busy,
              onSelected: (action) =>
                  action == 'edit' ? _edit(asset) : _delete(asset),
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
      ),
    );
  }

  Widget _previewBar(BuildContext context, AudioAsset current) {
    final position = widget.player.position.inMilliseconds.clamp(
      0,
      current.durationMs,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: position / current.durationMs,
            minHeight: 2,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${formatDuration(position)} / ${formatDuration(current.durationMs)} · предпрослушивание',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: widget.player.playing ? 'Пауза' : 'Продолжить',
                  onPressed: _busy ? null : () => _preview(current),
                  icon: Icon(
                    widget.player.playing ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  tooltip: 'Остановить прослушивание',
                  onPressed: _busy ? null : () => _run(widget.player.stop),
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuturePage extends StatelessWidget {
  const _FuturePage({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: 24),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(description),
      ],
    ),
  );
}
