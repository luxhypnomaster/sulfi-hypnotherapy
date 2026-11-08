import 'package:flutter/material.dart';

enum StructureExit { apply, discard, stay }

Future<StructureExit> askStructureExit(BuildContext context) =>
    showDialog<StructureExit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Есть неприменённые изменения'),
        content: const Text('Применить их или вернуться к прежнему состоянию?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, StructureExit.stay),
            child: const Text('Остаться'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, StructureExit.discard),
            child: const Text('Отбросить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, StructureExit.apply),
            child: const Text('Применить'),
          ),
        ],
      ),
    ).then((v) => v ?? StructureExit.stay);
