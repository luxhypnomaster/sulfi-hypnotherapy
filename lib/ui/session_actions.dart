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
    title: 'Сохранить как шаблон',
    name: initialName ?? '',
    hint: (plan ?? c.draft.plan).exitStepId == null
        ? 'Аудиовыход не назначен. При завершении будет доступна текстовая ориентация.'
        : null,
  );
  if (result == null) return null;
  return c.saveAsTemplate(result.name, result.description, plan: plan);
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
          'Сохранить её как отдельный шаблон перед переключением? Тема и заметки останутся.',
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
            child: const Text('Сохранить как шаблон'),
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
  await c.loadTemplate(template);
  return true;
}
