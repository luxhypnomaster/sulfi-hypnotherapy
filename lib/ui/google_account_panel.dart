import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/alchemist_diagnostics.dart';
import '../services/alchemist_errors.dart';
import '../services/device_files.dart';
import '../services/diary_controller.dart';
import 'design.dart';

/// One view of the same session used by the diary, catalog and transfer runner.
class GoogleAccountPanel extends StatefulWidget {
  const GoogleAccountPanel({super.key, required this.diary});
  final DiaryController diary;
  @override
  State<GoogleAccountPanel> createState() => _GoogleAccountPanelState();
}

class _GoogleAccountPanelState extends State<GoogleAccountPanel> {
  bool busy = false;
  String? message;
  Future<void> act(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => message = AlchemistFailure.from(e).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.diary,
    builder: (context, _) {
      final d = widget.diary, api = d.api;
      final signed = api?.readerAuthenticated ?? false;
      final waiting = busy || d.authorBusy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Google-аккаунт',
            style: TextStyle(
              color: transferYellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            waiting
                ? 'Подключение / проверка…'
                : signed
                ? 'Вход подтверждён сервером'
                : 'Нужен Google-вход для облачных действий',
          ),
          if (signed && api?.accountLabel != null) Text(api!.accountLabel!),
          Text(
            'Роль сервера: ${signed ? api?.verifiedRole ?? 'не подтверждена' : 'ожидает проверки'}',
          ),
          const Text(
            'Локальное редактирование не предоставляет серверных прав.',
            style: TextStyle(fontSize: 12),
          ),
          if (message != null)
            Text(message!, style: const TextStyle(color: neonPink)),
          Wrap(
            spacing: 8,
            children: [
              if (!signed)
                TextButton(
                  onPressed: waiting ? null : () => act(d.signInAuthor),
                  child: const Text('Войти через Google'),
                ),
              if (signed) ...[
                TextButton(
                  onPressed: waiting ? null : () => act(d.switchGoogleAccount),
                  child: const Text('Сменить аккаунт'),
                ),
                TextButton(
                  onPressed: waiting ? null : () => act(d.logout),
                  child: const Text('Выйти'),
                ),
                TextButton(
                  onPressed: waiting ? null : () => act(d.verifyGoogleRights),
                  child: const Text('Проверить права'),
                ),
              ],
            ],
          ),
          if (kDebugMode)
            ListenableBuilder(
              listenable: AlchemistDiagnostics.instance,
              builder: (context, _) => Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Диагностика QA (20 минут, без секретов)',
                    ),
                    value: AlchemistDiagnostics.instance.enabled,
                    onChanged: AlchemistDiagnostics.instance.enable,
                  ),
                  if (AlchemistDiagnostics.instance.enabled)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: AlchemistDiagnostics.instance.export(),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Диагностический отчёт скопирован.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Скопировать диагностический отчёт'),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class InstalledBuildLabel extends StatefulWidget {
  const InstalledBuildLabel({super.key});
  @override
  State<InstalledBuildLabel> createState() => _InstalledBuildLabelState();
}

class _InstalledBuildLabelState extends State<InstalledBuildLabel> {
  late final Future<String> installedBuild = read();
  Future<String> read() async {
    try {
      final info = await DeviceFiles.diagnostics();
      final version = '${info['versionName']}+${info['versionCode']}';
      AlchemistDiagnostics.instance.setBuild(version);
      return 'Сульфи · $version\n${info['applicationId']}';
    } catch (_) {
      return 'Сульфи · версия устройства недоступна';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: installedBuild,
    builder: (_, snapshot) => Text(
      snapshot.data ?? 'Сульфи · проверка версии…',
      textAlign: TextAlign.center,
    ),
  );
}
