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
  List<Map<String, dynamic>> cards = [];
  final installed = <String, String>{};
  String? error, cursor, kind, busyId;
  String progress = '';
  bool paused = false, loading = false, authenticated = false;
  AlchemistApi get api =>
      widget.controller.alchemistApi(authenticated: authenticated);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    paused = true;
    query.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.call('catalog.list', {
        'search': query.text.trim(),
        'type': ?kind,
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
      if (mounted) {
        setState(() {
          final items = (result['items'] as List).map(
            (x) => Map<String, dynamic>.from(x),
          );
          cards = more ? [...cards, ...items] : items.toList();
          cursor = result['nextPage'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> install(Map<String, dynamic> c) async {
    final id = c['catalogItemId'] as String;
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
      await AlchemistInstall(widget.controller.capsules!, api).install(
        c,
        interrupted: () => paused || !mounted,
        progress: (n, total) {
          if (mounted) setState(() => progress = '$n / $total байт');
        },
      );
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
    child: Column(
      children: [
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
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                authenticated
                    ? 'Читать без входа'
                    : 'Войти для личных материалов',
              ),
              onPressed: busyId != null
                  ? null
                  : () {
                      setState(() => authenticated = !authenticated);
                      load();
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
        DropdownButton<String?>(
          value: kind,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: null, child: Text('Все материалы')),
            DropdownMenuItem(value: 'collection', child: Text('Сборки')),
            DropdownMenuItem(value: 'package', child: Text('ZIP-пакеты')),
            DropdownMenuItem(value: 'track', child: Text('Треки')),
            DropdownMenuItem(value: 'module', child: Text('Модули')),
            DropdownMenuItem(value: 'template', child: Text('Шаблоны')),
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              children: [
                for (final c in cards)
                  ListTile(
                    title: Text(c['card']['title']),
                    subtitle: Text(
                      '${c['card']['shortAnnotation']}\n${c['type']} · '
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
                  const ListTile(
                    title: Text('Опубликованных материалов пока нет'),
                  ),
                if (cursor != null)
                  TextButton(
                    onPressed: loading ? null : () => load(more: true),
                    child: const Text('Ещё'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
