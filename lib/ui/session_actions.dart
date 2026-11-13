import 'package:flutter/material.dart';

import '../models/session_plan.dart';
import '../services/library_service.dart';
import '../services/session_controller.dart';
import 'design.dart';

Future<void> showActionError(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is LibraryException
                ? e.message
                : e is FormatException
                ? e.message.toString()
                : 'Не удалось сохранить изменения. Повторите действие.',
          ),
        ),
      );
    }
  }
}

Future<SessionTemplate?> saveTemplateDialog(
  BuildContext context,
  SessionController c, {
  SessionPlan? plan,
  String? initialName,
}) async {
  final result = await askDetails(
    context,
    title: 'Сохранить как программу',
    name: initialName ?? '',
    hint: !(plan ?? c.draft.plan).hasExitAudio
        ? 'Аудиовыход не назначен. При завершении будет доступна текстовая ориентация.'
        : null,
  );
  if (result == null) return null;
  if (!context.mounted ||
      !await warnMissingPlanAudio(context, c, plan ?? c.draft.plan)) {
    return null;
  }
  return c.saveAsTemplate(result.name, result.description, plan: plan);
}

Future<bool> warnMissingPlanAudio(
  BuildContext context,
  SessionController c,
  SessionPlan plan,
) async {
  final missing = <String>[];
  for (final step in plan.allSteps) {
    if (step.kind != StepKind.audio) continue;
    final asset = c.asset(step.audioAssetId);
    if (asset == null || !await c.library.fileFor(asset).exists()) {
      missing.add(step.title);
    }
  }
  if (missing.isEmpty) return true;
  if (!context.mounted) return false;
  return confirmAction(
    context,
    'Часть аудио недоступна',
    'Не найдены: ${missing.join(', ')}. Полный план сохранится. Перед запуском замените отсутствующие треки в конструкторе.',
    confirm: 'Сохранить полный план',
  );
}

Future<bool> loadTemplateSafely(
  BuildContext context,
  SessionController c,
  SessionTemplate template,
) async {
  if (c.draft.modified) {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Текущая конфигурация изменена'),
        content: const Text(
          'Сохранить её как отдельную программу перед переключением? Тема и заметки останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Переключить без сохранения'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Сохранить как программу'),
          ),
        ],
      ),
    );
    if (action == null || action == 'cancel') return false;
    if (action == 'save') {
      if (!context.mounted) return false;
      if (await saveTemplateDialog(context, c) == null) return false;
    }
  }
  if (!context.mounted ||
      !await warnMissingPlanAudio(context, c, template.plan)) {
    return false;
  }
  await c.loadTemplate(template);
  return true;
}
