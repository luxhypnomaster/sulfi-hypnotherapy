import 'package:flutter/material.dart';

import '../services/capsule_service.dart';
import '../services/device_files.dart';

/// The same portable capsule and system save dialog as whole-device backups.
Future<void> exportMaterial(
  BuildContext context,
  CapsuleService service, {
  String? trackId,
  String? moduleId,
  String? templateId,
}) async {
  final zip = await service.export(
    trackId: trackId,
    moduleId: moduleId,
    templateId: templateId,
  );
  try {
    if (!context.mounted) return;
    final saved = await DeviceFiles.save(zip.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Материал сохранён в ZIP. История и дневник не включены.'
                : 'Сохранение отменено.',
          ),
        ),
      );
    }
  } finally {
    if (await zip.exists()) await zip.delete();
  }
}
