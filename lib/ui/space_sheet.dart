import 'dart:async';

import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../services/session_controller.dart';
import '../services/preview_player.dart';
import '../services/access_policy.dart';
import 'backup_screen.dart';
import 'content_catalog_screen.dart';

Future<void> showSpaceSheet(
  BuildContext pageContext, {
  required LibraryService library,
  SessionController? controller,
  required PreviewPlayer player,
  required Future<void> Function() onReset,
  Future<void> Function()? onChanged,
}) => showModalBottomSheet<void>(
  context: pageContext,
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
            'Личные аудио, планы и история хранятся на этом устройстве. Дневник имеет отдельную настройку публикаций. Удаление приложения удалит локальные данные: создайте внешнюю ZIP-копию.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Инструмент саморегуляции не заменяет медицинскую помощь. Не используйте за рулём. Предпрослушивание останавливается при уходе в фон.',
          ),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: library.policy,
            builder: (context, _) => Column(
              children: [
                Text(
                  library.policy.isAuthor ? 'Режим: Автор' : 'Режим: Клиент',
                ),
                if (!library.policy.clientEdition)
                  SegmentedButton<LocalMode>(
                    segments: const [
                      ButtonSegment(
                        value: LocalMode.author,
                        label: Text('Автор'),
                      ),
                      ButtonSegment(
                        value: LocalMode.client,
                        label: Text('Клиент'),
                      ),
                    ],
                    selected: {library.policy.mode},
                    onSelectionChanged: (value) async {
                      await library.policy.setMode(value.single);
                      if (pageContext.mounted) await onChanged?.call();
                    },
                  ),
              ],
            ),
          ),
          if (controller?.capsules != null)
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push<void>(
                  pageContext,
                  MaterialPageRoute(
                    builder: (_) => ContentCatalogScreen(
                      controller: controller!,
                      player: player,
                    ),
                  ),
                );
                if (pageContext.mounted) await onChanged?.call();
              },
              icon: const Icon(Icons.view_list_outlined),
              label: const Text('Локальный каталог материалов'),
            ),
          if (controller?.capsules != null)
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await player.stop();
                if (!pageContext.mounted) return;
                await Navigator.push<void>(
                  pageContext,
                  MaterialPageRoute(
                    builder: (_) => BackupScreen(controller: controller!),
                  ),
                );
                if (pageContext.mounted) await onChanged?.call();
              },
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Резервная копия и обновления'),
            ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              unawaited(onReset());
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить все данные приложения'),
          ),
          const SizedBox(height: 12),
          const Text('Сульфи · 0.4.12+17', textAlign: TextAlign.center),
        ],
      ),
    ),
  ),
);
