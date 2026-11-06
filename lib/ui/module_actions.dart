import 'package:flutter/material.dart';

import '../models/modular_plan.dart';
import '../models/session_plan.dart';
import '../services/library_service.dart';
import '../services/session_controller.dart';
import 'design.dart';

/// Explicitly preserve an already composed session instance as a reusable recipe.
/// It never overwrites the original definition or another session instance.
Future<void> saveModuleCopyDialog(
  BuildContext context,
  SessionController controller,
  PhaseChild instance,
) async {
  if (instance.items.isEmpty) {
    throw const LibraryException('Добавьте в модуль трек или паузу');
  }
  final details = await askDetails(
    context,
    title: 'Сохранить как модуль',
    name: '${instance.title} — вариант',
    description: instance.description,
    hint: 'Состав сохранится отдельным модулем в каталоге. Текущая сессия и исходный модуль останутся прежними.',
  );
  if (details == null) return;
  await controller.modules.save(
    ModuleDefinition(
      id: newId(),
      title: details.name,
      description: details.description,
      items: instance.items
          .map((s) => s.copyWith(id: newId(), ungroup: true))
          .toList(),
    ),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Модуль сохранён в «Шаблоны и модули» → «Модули»'),
      ),
    );
  }
}
