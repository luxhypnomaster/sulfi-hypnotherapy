import 'dart:io';

import 'package:flutter/material.dart';

import '../models/content_revision.dart';
import '../services/device_files.dart';
import '../services/local_content_catalog.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import 'design.dart';
import 'session_actions.dart';
import 'modules_screen.dart';
import 'templates_screen.dart';

class ContentCatalogScreen extends StatefulWidget {
  const ContentCatalogScreen({
    super.key,
    required this.controller,
    required this.player,
    this.requested,
    this.initialSource,
    this.openOnStart = false,
  });
  final SessionController controller;
  final PreviewPlayer player;
  final RevisionKey? requested;
  final LocalCatalogSource? initialSource;
  final bool openOnStart;
  @override
  State<ContentCatalogScreen> createState() => _ContentCatalogScreenState();
}

class _ContentCatalogScreenState extends State<ContentCatalogScreen> {
  LocalCatalogSource? source;
  ContentType? filter;
  bool busy = false, cancelled = false;
  String message = '';
  String? installedDescription;
  final Map<String, bool> installed = {};
  @override
  void initState() {
    super.initState();
    source = widget.initialSource;
    if (source != null) refresh();
    if (widget.openOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) open();
      });
    }
  }

  @override
  void dispose() {
    cancelled = true;
    source?.close();
    super.dispose();
  }

  Future<void> refresh() async {
    if (source == null) return;
    final states = <String, bool>{};
    for (final r in source!.revisions) {
      states[r.key.token] = await source!.installed(r);
    }
    if (mounted) {
      setState(() {
        installed.clear();
        installed.addAll(states);
      });
    }
  }

  Future<void> open() async {
    if (busy) return;
    setState(() => busy = true);
    await showActionError(context, () async {
      final path = await DeviceFiles.open();
      if (path == null) return;
      final next = await LocalCatalogSource.open(
        widget.controller.capsules!,
        File(path),
      );
      if (!mounted) {
        await next.close();
        return;
      }
      await source?.close();
      source = next;
      await refresh();
      if (mounted &&
          widget.requested != null &&
          !next.revisions.any(
            (r) =>
                r.key.token == widget.requested!.token &&
                r.key.digest == widget.requested!.digest,
          )) {
        setState(
          () => message = 'Точной ревизии из дневника в этом пакете нет.',
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> details(ContentRevision r) async {
    final plan = await source!.plan(r.key);
    if (!mounted) return;
    final ready = installed[r.key.token] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          r.payload['title'] ?? r.payload['name'] ?? r.key.content.id,
        ),
        content: SingleChildScrollView(
          child: Text(
            '${r.payload['description'] ?? ''}\nТип: ${r.key.content.type.name}\nВерсия: ${r.declaredVersion ?? "неизвестна"}\nТочная ревизия: ${r.key.revision}\nПроисхождение: ${r.payload['origin'] ?? "неизвестно"}\nЗависимостей: ${plan.closure.revisions.length - 1}\nНовый аудиоконтент: ${plan.newBytes} Б\nЗапись файлов: ${plan.physicalWriteBytes} Б\nВременное место: ${plan.stagingBytes} Б\nРезерв: ${plan.reserveBytes} Б\n\nSHA-256 проверяет целостность; это не подпись издателя и не право доступа.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ready ? 'Открыть' : 'Установить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (ready) {
      await showInstalled(r);
      return;
    }
    setState(() {
      busy = true;
      cancelled = false;
      message = 'Подготовка установки';
    });
    await showActionError(context, () async {
      await source!.install(
        plan,
        cancelled: () => cancelled,
        onState: (state) {
          if (mounted) {
            setState(
              () => message = switch (state) {
                ContentInstallState.planned => 'План готов',
                ContentInstallState.staging => 'Подготовка файлов',
                ContentInstallState.verifying =>
                  'Проверка SHA-256 и зависимостей',
                ContentInstallState.committing => 'Сохранение',
                ContentInstallState.installed => 'Обновление списка',
                ContentInstallState.failed =>
                  'Установка не завершена. Можно повторить.',
                ContentInstallState.cancelled => 'Установка отменена',
              },
            );
          }
        },
      );
      await widget.controller.reload();
      await refresh();
      if (mounted) {
        setState(() {
          message = 'Установлено';
          installedDescription =
              '«${r.payload['title'] ?? r.payload['name'] ?? r.key.content.id}» — ${switch (r.key.content.type) {
                ContentType.track => 'Библиотека',
                ContentType.module => 'Шаблоны и модули → Модули',
                ContentType.template => 'Шаблоны и модули → Шаблоны',
              }}';
        });
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> showInstalled(ContentRevision r) async {
    await widget.controller.reload();
    if (!mounted) return;
    if (r.key.content.type == ContentType.track) {
      final asset = widget.controller.asset(r.key.content.id);
      if (asset != null) {
        await widget.player.toggle(
          asset,
          widget.controller.library.fileFor(asset),
        );
      }
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => r.key.content.type == ContentType.module
            ? ModulesScreen(
                controller: widget.controller,
                player: widget.player,
              )
            : TemplatesScreen(
                controller: widget.controller,
                player: widget.player,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requested = widget.requested;
    final entries =
        source?.revisions
            .where(
              (r) =>
                  (filter == null || r.key.content.type == filter) &&
                  (requested == null ||
                      r.key.token == requested.token &&
                          r.key.digest == requested.digest),
            )
            .toList() ??
        <ContentRevision>[];
    return LeatherScaffold(
      title: 'Локальный каталог',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Материалы из выбранного ZIP на устройстве. Это локальный источник, не онлайн-каталог.',
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : open,
            icon: const Icon(Icons.folder_open),
            label: const Text('Импортировать ZIP'),
          ),
          DropdownButton<ContentType?>(
            value: filter,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Все типы')),
              for (final t in ContentType.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(switch (t) {
                    ContentType.track => 'Треки',
                    ContentType.module => 'Модули',
                    ContentType.template => 'Шаблоны',
                  }),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => filter = v),
          ),
          if (message.isNotEmpty) Text(message),
          if (installedDescription != null) Text(installedDescription!),
          if (busy)
            TextButton(
              onPressed: () => setState(() {
                cancelled = true;
              }),
              child: const Text('Отменить установку'),
            ),
          if (requested != null && entries.isEmpty)
            const Text(
              'Точная ревизия недоступна. Выберите локальный пакет, содержащий этот материал. Установка не выполнена.',
            ),
          Expanded(
            child: ListView(
              children: [
                for (final r in entries)
                  ListTile(
                    key: ValueKey('catalog-${r.key.token}'),
                    title: Text(
                      r.payload['title'] ??
                          r.payload['name'] ??
                          r.key.content.id,
                    ),
                    subtitle: Text(
                      '${r.key.content.type.name} · версия ${r.declaredVersion ?? "?"} · ${installed[r.key.token] == true ? "Установлено" : "Доступно"}\n${r.payload['description'] ?? ""}',
                    ),
                    trailing: Icon(
                      installed[r.key.token] == true
                          ? Icons.check_circle_outline
                          : Icons.download_outlined,
                    ),
                    onTap: busy
                        ? null
                        : () => showActionError(context, () => details(r)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
