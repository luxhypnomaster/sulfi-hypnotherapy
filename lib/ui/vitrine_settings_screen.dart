import 'package:flutter/material.dart';

import '../models/vitrine_config.dart';
import '../services/diary_controller.dart';
import '../services/vitrine_settings.dart';
import 'diary_screen.dart';

class PublicationsVitrineScreen extends StatelessWidget {
  const PublicationsVitrineScreen({super.key, required this.diary});
  final DiaryController diary;
  @override
  Widget build(BuildContext context) {
    if (diary.policy?.clientEdition == true || !diary.authorWorkspace) {
      return Scaffold(appBar: AppBar(title: const Text('Доступ недоступен')));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Публикации и витрина'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Публикации'),
              Tab(text: 'Настройки витрины'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DiaryScreen(diary: diary),
            VitrineSettingsScreen(
              store: VitrineSettingsStore(
                diary.repository.database,
                account: () =>
                    diary.api?.readerScope ??
                    (diary.reads.loaded ? diary.reads.readerId : null),
                canEdit: () =>
                    diary.policy?.clientEdition != true &&
                    diary.authorWorkspace,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VitrineSettingsScreen extends StatefulWidget {
  const VitrineSettingsScreen({super.key, required this.store});
  final VitrineSettingsStore store;
  @override
  State<VitrineSettingsScreen> createState() => _VitrineSettingsScreenState();
}

class _VitrineSettingsScreenState extends State<VitrineSettingsScreen> {
  final splash = TextEditingController(text: '3'),
      entry = TextEditingController(text: '7'),
      high = TextEditingController(text: '1'),
      normal = TextEditingController(text: '1'),
      pinned = TextEditingController(text: '3');
  VitrineSplashMode mode = VitrineSplashMode.fullCycle;
  String status = 'Черновик';
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final state = await widget.store.load();
      if (!mounted) return;
      final c = state['saved'] == null
          ? const VitrineConfig()
          : VitrineConfig.fromMap(state['saved']);
      splash.text = '${c.splashSeconds}';
      entry.text = '${c.entrySeconds}';
      high.text = '${c.highWeight}';
      normal.text = '${c.normalWeight}';
      pinned.text = '${c.pinnedEveryNth}';
      mode = c.splashMode;
      setState(() {
        busy = false;
        status = state['saved'] == null
            ? 'Черновик'
            : 'Сохранено на этом устройстве. Опубликованная редакция: ${state['publishedRevision'] ?? 'нет'}';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Ошибка чтения. Исходные настройки сохранены.';
        });
      }
    }
  }

  VitrineConfig config() => VitrineConfig(
    splashSeconds: int.parse(splash.text),
    entrySeconds: int.parse(entry.text),
    highWeight: int.parse(high.text),
    normalWeight: int.parse(normal.text),
    pinnedEveryNth: int.parse(pinned.text),
    splashMode: mode,
  );
  Future<void> action(bool publish) async {
    setState(() => busy = true);
    try {
      await widget.store.save(config());
      if (publish) await widget.store.publish();
      if (mounted) {
        setState(
          () => status = publish
              ? 'Публикация подтверждена сервером'
              : 'Сохранено на этом устройстве; ещё не опубликовано',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Не сохранено или не подтверждено сервером. Предыдущая опубликованная версия сохранена.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [splash, entry, high, normal, pinned]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(status, key: const Key('vitrine-status')),
      for (final pair in [
        (splash, 'Заставка, секунд (1–60)'),
        (entry, 'Публикация, секунд (1–60)'),
        (high, 'Вес приоритетных'),
        (normal, 'Вес обычных'),
        (pinned, 'Закреплённая каждые N слайдов'),
      ])
        TextField(
          controller: pair.$1,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: pair.$2),
          onChanged: (_) => setState(
            () => status = 'Черновик — есть несохранённые изменения',
          ),
        ),
      DropdownButton<VitrineSplashMode>(
        value: mode,
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: VitrineSplashMode.fullCycle,
            child: Text('Заставка после полного круга'),
          ),
          DropdownMenuItem(
            value: VitrineSplashMode.betweenEntries,
            child: Text('Заставка между публикациями'),
          ),
        ],
        onChanged: busy
            ? null
            : (v) => setState(() {
                mode = v!;
                status = 'Черновик';
              }),
      ),
      const Text(
        'Технические ограничения весов 1–100 и N 1–1000 — предложение для проверки.',
      ),
      FilledButton(
        onPressed: busy ? null : () => action(false),
        child: const Text('Сохранить на устройстве'),
      ),
      OutlinedButton(
        onPressed: busy || widget.store.admin == null
            ? null
            : () => action(true),
        child: const Text('Опубликовать настройки'),
      ),
      if (widget.store.admin == null)
        const Text(
          'Серверная публикация настроек пока не подключена. Локальное сохранение не изменяет витрину CLIENT.',
        ),
      TextButton(
        onPressed: busy ? null : load,
        child: const Text('Вернуть сохранённые настройки'),
      ),
      const Divider(),
      const Text(
        'Статичный предпросмотр порядка: заставка → приоритетная → обычная → … → заставка. Прочтение и очередь не меняются.',
      ),
    ],
  );
}
