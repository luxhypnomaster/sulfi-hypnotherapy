import '../services/alchemist_install.dart';

import 'package:flutter/material.dart';

import '../data/content_revision_store.dart';
import '../models/content_link.dart';
import '../models/content_revision.dart';
import '../services/local_content_catalog.dart';
import 'content_catalog_screen.dart';
import 'session_scope.dart';
import 'session_actions.dart';
import 'modules_screen.dart';
import 'templates_screen.dart';

class DiaryContentLink extends StatefulWidget {
  const DiaryContentLink({super.key, required this.link});
  final ContentLink link;
  @override
  State<DiaryContentLink> createState() => _DiaryContentLinkState();
}

class _DiaryContentLinkState extends State<DiaryContentLink> {
  ContentRevision? installed;
  bool checked = false, busy = false, remoteVerified = false;
  bool get strictAvailability =>
      SessionScope.maybeOf(context)?.controller.project22Enabled == true;
  String? problem;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!checked) {
      checked = true;
      refresh();
    }
  }

  @override
  void didUpdateWidget(covariant DiaryContentLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.key.token != widget.link.key.token ||
        oldWidget.link.key.digest != widget.link.key.digest) {
      installed = null;
      remoteVerified = false;
      refresh();
    }
  }

  Future<void> refresh() async {
    final scope = SessionScope.maybeOf(context);
    final service = scope?.controller.capsules;
    ContentRevision? result;
    final key = widget.link.key;
    String? error;
    var available = false;
    final account = scope?.controller.transferOwner;
    final strict = scope?.controller.project22Enabled == true;
    try {
      if (service != null) {
        final r = await ContentRevisionStore(service.database).get(key);
        if (r != null &&
            await LocalCatalogSource.installedRevision(service, r)) {
          result = r;
        }
      }
      if (strict &&
          result == null &&
          const String.fromEnvironment('SULFI_ALCHEMIST_API').isNotEmpty) {
        final card = await scope!.controller.alchemistApi().call(
          'catalog.resolveReference',
          {
            'logicalId': key.content.id,
            'revisionId': key.revision,
            'digest': key.digest,
          },
        );
        available =
            card['logicalContentId'] == key.content.id &&
            card['immutableRevisionId'] == key.revision &&
            card['type'] == key.content.type.name &&
            key.digest == key.revision;
      }
    } catch (_) {
      error = 'Точная ссылка недоступна или повреждена.';
    }
    if (mounted &&
        account == scope?.controller.transferOwner &&
        widget.link.key.token == key.token &&
        widget.link.key.digest == key.digest) {
      setState(() {
        installed = result;
        remoteVerified = available;
        problem =
            error ??
            (strict && result == null && !available
                ? 'Материал или право установки пока не подтверждены.'
                : null);
      });
    }
  }

  Future<void> openContent() async {
    final scope = SessionScope.maybeOf(context);
    if (scope?.controller.capsules == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Локальный каталог недоступен. Материал не установлен.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    await showActionError(context, () async {
      final r = installed;
      if (r != null && r.key.content.type == ContentType.track) {
        final asset = scope!.controller.asset(r.key.content.id);
        if (asset != null) {
          await scope.player.toggle(
            asset,
            scope.controller.library.fileFor(asset),
          );
        }
        return;
      }
      if (r != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => r.key.content.type == ContentType.module
                ? ModulesScreen(
                    controller: scope!.controller,
                    player: scope.player,
                  )
                : TemplatesScreen(
                    controller: scope!.controller,
                    player: scope.player,
                  ),
          ),
        );
        return;
      }
      if (const String.fromEnvironment('SULFI_ALCHEMIST_API').isNotEmpty) {
        final c = scope!.controller,
            api = c.alchemistApi(authenticated: strictAvailability),
            key = widget.link.key;
        final card = await api.call('catalog.resolveReference', {
          'logicalId': key.content.id,
          'revisionId': key.revision,
          'digest': key.digest,
        });
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(card['card']['title']),
            content: Text(
              'Установить точную ревизию ${key.revision.substring(0, 8)}? Недостающие файлы будут скачаны после подтверждения.',
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
        if (accepted == true) {
          await AlchemistInstall(c.capsules!, api).install(card);
          await c.reload();
          if (mounted) await refresh();
        }
        return;
      }
      // Opening the local selector is not installing anything. It will require
      // the exact requested key and report a missing source explicitly.
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ContentCatalogScreen(
            controller: scope!.controller,
            player: scope.player,
            requested: widget.link.key,
          ),
        ),
      );
      if (mounted) await refresh();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('diary-content-${widget.link.key.token}'),
    leading: const Icon(Icons.inventory_2_outlined),
    title: Text(
      installed?.payload['title'] ??
          installed?.payload['name'] ??
          'Материал: ${widget.link.key.content.id}',
    ),
    subtitle: Text(
      problem ??
          (installed == null
              ? (const String.fromEnvironment('SULFI_ALCHEMIST_API').isEmpty
                    ? 'Точная ревизия. Для установки нужен локальный пакет.'
                    : 'Точная ревизия. Доступна выборочная установка с сервера.')
              : 'Установлено · точная ревизия'),
    ),
    trailing: strictAvailability && installed == null && !remoteVerified
        ? null
        : TextButton(
            onPressed: busy ? null : openContent,
            child: Text(
              installed == null ? 'Посмотреть / установить' : 'Открыть',
            ),
          ),
  );
}
