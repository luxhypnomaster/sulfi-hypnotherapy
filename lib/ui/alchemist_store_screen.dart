import 'alchemist_sync_screen.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/alchemist_api.dart';
import '../services/alchemist_install.dart';
import '../services/session_controller.dart';
import 'alchemist_catalog_screen.dart';
import 'design.dart';

/// No automatic media transfer: loading cards only fetches metadata.
class AlchemistStoreScreen extends StatefulWidget {
  const AlchemistStoreScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<AlchemistStoreScreen> createState() => _AlchemistStoreScreenState();
}

class _AlchemistStoreScreenState extends State<AlchemistStoreScreen> {
  final query = TextEditingController();
  final category = TextEditingController(), tag = TextEditingController();
  List<Map<String, dynamic>> cards = [];
  final installed = <String, String>{};
  String? error, cursor, kind, busyId;
  String progress = '';
  bool paused = false, loading = false, authenticated = false;
  int _loadGeneration = 0;
  String _scope = 'public';
  Future<void> metadataChanged() async {
    final generation = _loadGeneration;
    final cached = await widget.controller.metadata?.cachedCards();
    if (mounted && generation == _loadGeneration && cached != null) {
      setState(() {
        cards = filterCached(cached);
        cursor = null;
      });
    }
  }

  List<Map<String, dynamic>> filterCached(List<Map<String, dynamic>> values) =>
      values.where((r) {
        final c = r['card'] as Map;
        return (kind == null || r['type'] == kind) &&
            '${c['title']} ${c['shortAnnotation']}'.toLowerCase().contains(
              query.text.trim().toLowerCase(),
            ) &&
            (category.text.trim().isEmpty ||
                (c['categoryIds'] as List? ?? []).contains(
                  category.text.trim(),
                )) &&
            (tag.text.trim().isEmpty ||
                (c['tags'] as List? ?? []).contains(tag.text.trim()));
      }).toList();
  void accountChanged() {
    final current = widget.controller.diary?.api?.readerScope ?? 'public';
    final signedIn = widget.controller.diary?.authenticated ?? false;
    if (current == _scope && authenticated == signedIn) return;
    _scope = current;
    _loadGeneration++;
    if (mounted) {
      setState(() {
        cards = [];
        cursor = null;
        authenticated = signedIn;
        loading = false;
      });
    }
  }

  AlchemistApi get api =>
      widget.controller.alchemistApi(authenticated: authenticated);
  @override
  void initState() {
    super.initState();
    _scope = widget.controller.diary?.api?.readerScope ?? 'public';
    authenticated = widget.controller.diary?.authenticated ?? false;
    widget.controller.diary?.addListener(accountChanged);
    widget.controller.metadata?.addListener(metadataChanged);
    load();
  }

  @override
  void dispose() {
    paused = true;
    widget.controller.diary?.removeListener(accountChanged);
    widget.controller.metadata?.removeListener(metadataChanged);
    query.dispose();
    category.dispose();
    tag.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    final generation = ++_loadGeneration;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final runtime = widget.controller.metadata;
      if (runtime != null && !more) {
        final cached = await runtime.cachedCards();
        if (mounted && generation == _loadGeneration && cached != null) {
          setState(() {
            cards = filterCached(cached);
            cursor = null;
          });
        }
        final ready = await runtime.refresh(widget.controller.cloudQueue);
        if (ready || cached != null && runtime.gateway.state != 'legacy') {
          final receipts = await widget.controller.capsules!.database.query(
            'app_settings',
            where: 'name LIKE ?',
            whereArgs: ['alchemist_installed:%'],
          );
          installed.clear();
          for (final r in receipts) {
            final v = jsonDecode(r['value'] as String);
            installed[v['catalogItemId']] = v['immutableRevisionId'];
          }
          await metadataChanged();
          return;
        }
      }
      final result = await api.call('catalog.list', {
        'search': query.text.trim(),
        'state': 'published',
        'readerView': true,
        'type': ?kind,
        if (category.text.trim().isNotEmpty) 'category': category.text.trim(),
        if (tag.text.trim().isNotEmpty) 'tag': tag.text.trim(),
        'limit': 25,
        if (more && cursor != null) 'cursor': cursor,
      });
      final receipts = await widget.controller.capsules!.database.query(
        'app_settings',
        where: 'name LIKE ?',
        whereArgs: ['alchemist_installed:%'],
      );
      installed.clear();
      for (final r in receipts) {
        final value = jsonDecode(r['value'] as String);
        installed[value['catalogItemId']] = value['immutableRevisionId'];
      }
      if (mounted && generation == _loadGeneration) {
        setState(() {
          final items = (result['items'] as List).map(
            (x) => Map<String, dynamic>.from(x),
          );
          cards = more ? [...cards, ...items] : items.toList();
          cursor = result['nextPage'];
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> install(Map<String, dynamic> c) async {
    final id = c['catalogItemId'] as String;
    final detail = await api.call('catalog.get', {'catalogItemId': id});
    if (detail['immutableRevisionId'] != c['immutableRevisionId']) {
      throw const FormatException('Каталог изменился. Обновите список.');
    }
    c = detail;
    if (busyId != null) return;
    final plan = await api.call('catalog.getInstallPlan', {
      'catalogItemId': id,
      'installed': [],
    });
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c['card']['title']),
        content: Text(
          '${c['card']['description']}\n\nЗависимостей: ${(plan['dependencies'] as List).length}. '
          'Полный объём: ${plan['downloadBytes']} байт. Уже имеющиеся проверенные файлы повторно не скачиваются. '
          'Пользовательские изменения автоматически не заменяются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Установить'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busyId = id;
      paused = false;
      error = null;
    });
    try {
      if (widget.controller.nativeTransfers) {
        final task = await widget.controller.installInBackground(c);
        if (mounted) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AlchemistSyncScreen(
                controller: widget.controller,
                focusName: task,
              ),
            ),
          );
        }
      } else {
        await AlchemistInstall(widget.controller.capsules!, api).install(
          c,
          interrupted: () => paused || !mounted,
          progress: (n, total) {
            if (mounted) setState(() => progress = '$n / $total байт');
          },
        );
      }
      await widget.controller.reload();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          busyId = null;
          progress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => LeatherScaffold(
    title: 'Облачный каталог',
    child: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        children: [
          Text(
            widget.controller.metadata?.gateway.label ??
                'Каталог: прежний API; новый протокол выключен',
            key: const Key('metadata-capability-status'),
            style: const TextStyle(fontSize: 11),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (widget.controller.policy.isAuthor)
                TextButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Мои публикации'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlchemistCatalogScreen(
                        service: widget.controller.catalog,
                      ),
                    ),
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Очередь передач'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AlchemistSyncScreen(controller: widget.controller),
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(
                  authenticated
                      ? 'Выйти из Google'
                      : 'Войти для личных материалов',
                ),
                onPressed: busyId != null
                    ? null
                    : () async {
                        try {
                          final target = !authenticated;
                          if (!target) {
                            await widget.controller.signOutAlchemist();
                          } else {
                            await widget.controller.signInAlchemistReader();
                          }
                          if (mounted) {
                            final d = widget.controller.diary;
                            setState(
                              () => authenticated =
                                  d?.api?.supportsServerIdentity == true
                                  ? d!.authenticated
                                  : target,
                            );
                            if (target &&
                                d?.api?.supportsServerIdentity == true &&
                                !authenticated) {
                              setState(
                                () => error =
                                    d?.error ?? 'Вход не подтверждён сервером',
                              );
                              return;
                            }
                            await load();
                          }
                        } catch (e) {
                          if (mounted) setState(() => error = e.toString());
                        }
                      },
              ),
            ],
          ),
          TextField(
            controller: query,
            decoration: InputDecoration(
              labelText: 'Название или аннотация',
              suffixIcon: IconButton(
                onPressed: () => load(),
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => load(),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  onSubmitted: (_) => load(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: tag,
                  decoration: const InputDecoration(labelText: 'Тег'),
                  onSubmitted: (_) => load(),
                ),
              ),
            ],
          ),
          DropdownButton<String?>(
            value: kind,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: null, child: Text('Все материалы')),
              DropdownMenuItem(value: 'collection', child: Text('Сборки')),
              DropdownMenuItem(value: 'package', child: Text('ZIP-пакеты')),
              DropdownMenuItem(value: 'track', child: Text('Треки')),
              DropdownMenuItem(value: 'module', child: Text('Модули')),
              DropdownMenuItem(value: 'template', child: Text('Программы')),
              DropdownMenuItem(value: 'session', child: Text('Сессии')),
            ],
            onChanged: loading
                ? null
                : (v) {
                    setState(() => kind = v);
                    load();
                  },
          ),
          if (loading || busyId != null) const LinearProgressIndicator(),
          if (progress.isNotEmpty) Text(progress),
          if (busyId != null)
            TextButton(
              onPressed: () => setState(() => paused = true),
              child: const Text('Приостановить'),
            ),
          if (error != null)
            Text(error!, style: const TextStyle(color: neonPink)),
          for (final c in cards)
            ListTile(
              leading: c['card']['coverAssetId'] == null
                  ? null
                  : SizedBox(
                      width: 56,
                      height: 56,
                      child: AlchemistCover(
                        key: ValueKey(c['card']['coverAssetId']),
                        controller: widget.controller,
                        api: api,
                        assetId: c['card']['coverAssetId'],
                      ),
                    ),
              title: Text(c['card']['title']),
              subtitle: Text(
                '${c['card']['shortAnnotation']}\n${c['type']} · версия ${c['metadataRevision']} · файлы ${c['summary']?['downloadBytes'] ?? '—'} байт · '
                '${installed[c['catalogItemId']] == c['immutableRevisionId']
                    ? 'Установлено'
                    : installed.containsKey(c['catalogItemId'])
                    ? 'Есть обновление'
                    : 'Не скачано'}',
              ),
              trailing:
                  [
                    'track',
                    'module',
                    'template',
                    'collection',
                    'package',
                    'session',
                  ].contains(c['type'])
                  ? IconButton(
                      tooltip: 'Состав и установка',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: busyId != null
                          ? null
                          : () async {
                              try {
                                await install(c);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => error = e.toString());
                                }
                              }
                            },
                    )
                  : null,
            ),
          if (!loading && cards.isEmpty && error == null)
            ListTile(
              title: Text(
                cursor == null
                    ? 'Опубликованных материалов пока нет'
                    : 'На этой странице совпадений нет. Нажмите «Ещё».',
              ),
            ),
          if (cursor != null)
            TextButton(
              onPressed: loading ? null : () => load(more: true),
              child: const Text('Ещё'),
            ),
        ],
      ),
    ),
  );
}

class AlchemistCover extends StatefulWidget {
  const AlchemistCover({
    super.key,
    required this.controller,
    required this.api,
    required this.assetId,
  });
  final SessionController controller;
  final AlchemistApi api;
  final String assetId;
  @override
  State<AlchemistCover> createState() => _AlchemistCoverState();
}

class _AlchemistCoverState extends State<AlchemistCover> {
  File? file;
  bool loading = false;
  Future<void> load() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final d = await widget.api.call('media.getDescriptor', {
        'assetRevisionId': widget.assetId,
      });
      if (!(d['mime'] as String).startsWith('image/') ||
          (d['byteLength'] as int) > 20 * 1024 * 1024) {
        throw const FormatException('Обложка недоступна');
      }
      final f = await widget.controller.downloadAsset(d);
      if (mounted) setState(() => file = f);
    } catch (_) {
      if (mounted) setState(() => file = null);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : file == null
      ? IconButton(
          tooltip: 'Загрузить обложку',
          onPressed: load,
          icon: const Icon(Icons.image_outlined),
        )
      : Image.file(
          file!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => IconButton(
            tooltip: 'Повторить загрузку обложки',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        );
}
