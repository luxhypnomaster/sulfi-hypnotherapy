import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/capsule_service.dart';
import '../services/device_files.dart';
import '../services/session_controller.dart';
import '../services/library_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;
  bool restoring = false, cancelled = false;
  String? message;
  @override
  void dispose() {
    cancelled = true;
    super.dispose();
  }

  Future<void> action(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is FormatException
              ? e.message
              : e is LibraryException
              ? e.message
              : e is PlatformException
              ? e.message ?? 'Не удалось открыть системный выбор файла'
              : 'Не удалось перенести данные. Прежние данные сохранены.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> export() async {
    await widget.controller.flush();
    final zip = await widget.controller.capsules!.export();
    try {
      if (!mounted) return;
      final saved = await DeviceFiles.save(zip.path);
      if (mounted) {
        setState(
          () => message = saved
              ? 'ZIP сохранён в выбранном вами месте. Проверьте, что копия доступна вне приложения.'
              : 'Сохранение отменено. Данные приложения сохранены.',
        );
      }
    } finally {
      if (await zip.exists()) await zip.delete();
    }
  }

  Future<void> restore() async {
    setState(() => restoring = true);
    cancelled = false;
    final path = await DeviceFiles.open();
    if (path == null) {
      if (mounted) setState(() => restoring = false);
      return;
    }
    CapsulePreview? preview;
    try {
      preview = await widget.controller.capsules!.inspect(
        File(path),
        cancelled: () => cancelled,
      );
      if (!mounted) return;
      final p = preview;
      final choice = await showDialog<CapsuleConflictChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Проверенная копия'),
          content: SingleChildScrollView(
            child: Text(
              '${p.alreadyImported ? 'Эта копия уже восстановлена.\n' : ''}${p.counts.entries.where((e) => e.value > 0).map((e) => '${_labels[e.key] ?? e.key}: ${e.value}').join('\n')}\nФайлы: ${(p.bytes / 1048576).toStringAsFixed(1)} МБ\n\n${p.conflicts.isEmpty ? 'Конфликтов идентификаторов нет.' : 'Конфликты (${p.conflicts.length}):\n${p.conflicts.take(12).join('\n')}\nЗамена перепишет перечисленные объекты. Сохранение местных оставит их прежними.'}\n\nПри совпадении номеров разные сессии получат новые номера; их ID и снимки сохранятся. Активная сессия из копии восстановится как прерванная.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            if (p.conflicts.isNotEmpty)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, CapsuleConflictChoice.keepExisting),
                child: const Text('Сохранить местные'),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, CapsuleConflictChoice.replace),
              child: Text(
                p.conflicts.isEmpty ? 'Восстановить' : 'Заменить конфликтующие',
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      await widget.controller.capsules!.restore(
        p,
        choice: choice,
        cancelled: () => cancelled,
      );
      await widget.controller.reload();
      await widget.controller.diary?.load();
      if (mounted) {
        setState(
          () => message = p.alreadyImported
              ? 'Копия уже восстановлена. Дубликаты не созданы.'
              : 'Восстановлено на телефоне. Облачной публикации не было.',
        );
      }
    } finally {
      await preview?.close();
      if (mounted) setState(() => restoring = false);
      if (await File(path).exists()) await File(path).delete();
    }
  }

  static const _labels = {
    'audio_assets': 'Аудиозаписи',
    'module_definitions': 'Модули',
    'session_templates': 'Программы',
    'current_draft': 'Текущий план',
    'session_runs': 'История',
    'run_events': 'События',
    'app_counters': 'Счётчики',
    'diary_author': 'Черновики дневника',
    'diary_public': 'Кеш дневника',
    'diary_removed': 'Удаления дневника',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Данные и обновления')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Переносимая капсула Сульфи — обычный ZIP с вашими аудиозаписями, планами, историей и локальным дневником. Он содержит личные данные и не зашифрован. Вы сами выбираете место и получателя. Для копии не нужен Google-аккаунт.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : () => action(export),
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Создать резервную копию'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => action(restore),
          icon: const Icon(Icons.restore),
          label: const Text('Восстановить из копии'),
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => action(() async {
                  final d = await DeviceFiles.diagnostics();
                  if (!context.mounted) return;
                  final runs = await widget.controller.repository.history();
                  d['history'] = {
                    'storedRecords': runs.length,
                    'displayNumbers': runs.map((r) => r.displayNumber).toList(),
                    'nextNumber': await widget.controller.repository
                        .nextNumber(),
                    'note': 'Пробелы нумерации не доказывают потерю записей',
                  };
                  if (!context.mounted) return;
                  final text = const JsonEncoder.withIndent('  ').convert(d);
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Установленный APK'),
                      content: SingleChildScrollView(
                        child: SelectableText(text),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text));
                          },
                          child: const Text('Копировать'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  );
                }),
          icon: const Icon(Icons.info_outline),
          label: const Text('Диагностика установленной версии'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (busy && restoring)
          TextButton(
            onPressed: () => setState(() => cancelled = true),
            child: const Text('Отменить восстановление'),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message!),
          ),
      ],
    ),
  );
}
