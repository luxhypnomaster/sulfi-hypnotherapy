import 'catalog22_batch_screen.dart';
import 'course22_editor.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/session_plan.dart' show newId;
import '../services/project22_runtime.dart';
import '../services/session_controller.dart';
import 'alchemist_store_screen.dart';
import 'rating22_summary.dart';
import 'vitrine_settings_screen.dart';
import 'rating_policy22_screen.dart';

const admin22Sections = [
  ('publications', 'Публикации и витрина'),
  ('catalog', 'Каталог и материалы'),
  ('statistics', 'Статистика и отзывы'),
  ('operations', 'Операции и диагностика'),
  ('server', 'Состояние сервера и лимиты'),
  ('users', 'Пользователи и доступы'),
  ('backups', 'Резервное копирование и восстановление'),
];
const metricLabels22 = {
  'published': 'Опубликовано',
  'drafts': 'Черновики',
  'pending': 'Ожидают',
  'errors': 'Ошибки',
  'installs': 'Установки',
  'downloads': 'Загрузки',
  'consentedFeedback': 'Добровольные отзывы',
  'ratingTargets': 'Материалы с оценками',
  'queued': 'В очереди',
  'incidents': 'Инциденты',
  'metadata': 'API',
  'storageQuota': 'Storage',
  'databaseQuota': 'БД',
  'outbound': 'Исходящий трафик',
  'apiQuota': 'Лимит API',
  'verifiedIdentities': 'Подтверждённые пользователи',
  'roleAssignments': 'Назначения ролей',
  'lastUploaded': 'Последняя копия',
  'restoreVerified': 'Проверено восстановление',
};
Iterable<MapEntry<String, dynamic>> summaryMetrics22(Map metrics) => [
  for (final k in metricLabels22.keys.where(metrics.containsKey))
    MapEntry(k, metrics[k]),
  for (final k in metrics.keys.where((k) => !metricLabels22.containsKey(k)))
    MapEntry(k.toString(), metrics[k]),
].take(3);

String adminState22(Map? section, {bool stale = false}) {
  final metrics =
      (section?['metrics'] as Map?)?.values.cast<Map>().toList() ?? [];
  if (metrics.any((m) => m['state'] == 'problem')) return 'problem';
  if (stale ||
      metrics.isEmpty ||
      metrics.any((m) => m['state'] != 'verified')) {
    return 'unknown';
  }
  return 'healthy';
}

Color adminColor22(String state) => switch (state) {
  'problem' => const Color(0xffff2868),
  'healthy' => const Color(0xffa6ff44),
  _ => const Color(0xffffe34d),
};

class Admin22Screen extends StatefulWidget {
  const Admin22Screen({super.key, required this.controller});
  final SessionController controller;
  @override
  State<Admin22Screen> createState() => _Admin22ScreenState();
}

class _Admin22ScreenState extends State<Admin22Screen> {
  Project22Runtime? get r => widget.controller.project22;
  bool busy = false;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    r?.addListener(changed);
    refresh();
  }

  @override
  void dispose() {
    r?.removeListener(changed);
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Future.wait([
        if (r != null) r!.refresh(widget.controller.cloudQueue),
        if (widget.controller.metadata != null)
          widget.controller.metadata!.refresh(widget.controller.cloudQueue),
      ]);
    } catch (_) {
      /* LastGood status is retained. */
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Map? section(String id) => (r?.overview?['sections'] as List?)
      ?.cast<Map>()
      .where((s) => s['id'] == id)
      .firstOrNull;
  Future<void> open(String id) async {
    final c = widget.controller;
    final page = switch (id) {
      'publications' =>
        c.diary == null
            ? const Scaffold(body: Center(child: Text('Дневник недоступен')))
            : PublicationsVitrineScreen(diary: c.diary!),
      'catalog' => AdminPair22(
        title: 'Каталог и материалы',
        tabs: const ['Материалы', 'Структура каталога'],
        children: [
          Column(
            children: [
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Course22Drafts(controller: c),
                  ),
                ),
                child: const Text('Создать курс'),
              ),
              TextButton(
                onPressed: r?.admin == true
                    ? () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Catalog22BatchScreen(controller: c),
                        ),
                      )
                    : null,
                child: const Text('Управление материалами'),
              ),
              Expanded(child: AlchemistStoreScreen(controller: c)),
            ],
          ),
          CategoryPanel22(runtime: r),
        ],
      ),
      'statistics' => Statistics22Screen(runtime: r),
      'operations' => AdminPair22(
        title: 'Операции и диагностика',
        tabs: const ['Операции', 'Журнал и диагностика'],
        children: [
          RemotePanel22(
            runtime: r,
            operation: 'project.operations',
            listKey: 'jobs',
            allowRun: true,
          ),
          RemotePanel22(
            runtime: r,
            operation: 'project.incidents',
            listKey: 'incidents',
          ),
        ],
      ),
      'server' => MetricDashboard22(
        title: 'Состояние сервера и лимиты',
        section: section('server'),
        stale: r?.stale ?? true,
      ),
      'users' => AdminPair22(
        title: 'Пользователи и доступы',
        tabs: const ['Пользователи', 'Роли и права'],
        children: [
          RemotePanel22(
            runtime: r,
            operation: 'project.users',
            listKey: 'users',
          ),
          RolesPanel22(runtime: r),
        ],
      ),
      _ => AdminPair22(
        title: 'Резервное копирование и восстановление',
        tabs: const ['Резервные копии', 'Настройки и восстановление'],
        children: [
          RemotePanel22(
            runtime: r,
            operation: 'project.backups',
            listKey: 'backups',
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Копия и проверка восстановления — разные статусы. Рабочий сервер и данные не восстанавливаются из этой панели без отдельного проверенного плана. Расписание и хранение копий ещё не настроены.',
            ),
          ),
        ],
      ),
    };
    final originalOwner = c.transferOwner;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: Listenable.merge([?c.diary, ?r]),
          builder: (_, child) =>
              c.transferOwner == originalOwner &&
                  (r == null ||
                      ['publications', 'catalog'].contains(id) ||
                      !r!.accessDenied)
              ? page
              : const Scaffold(body: Center(child: Text('Доступ изменён'))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.policy.clientEdition) {
      return Scaffold(appBar: AppBar(title: const Text('Доступ недоступен')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление'),
        actions: [
          IconButton(
            tooltip: 'Обновить всё',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              r?.status ?? 'Серверный протокол №22 выключен. Доступные локальные функции сохранены; серверные показатели не получены.',
            ),
          ),
          for (final item in admin22Sections)
            ListTile(
              key: Key('admin22-${item.$1}'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              title: Text(
                item.$2,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 14,
                  color: adminColor22(
                    adminState22(section(item.$1), stale: r?.stale ?? true),
                  ),
                ),
              ),
              subtitle: section(item.$1) == null
                  ? const Text('Нет подтверждённых серверных данных')
                  : Wrap(
                      spacing: 12,
                      children: [
                        for (final entry in summaryMetrics22(
                          section(item.$1)!['metrics'] as Map,
                        ))
                          Text(
                            '${metricLabels22[entry.key] ?? entry.key}: ${entry.value['value'] ?? 'нет данных'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: entry.value['state'] == 'problem'
                                  ? adminColor22('problem')
                                  : entry.value['state'] == 'unknown'
                                  ? adminColor22('unknown')
                                  : null,
                            ),
                          ),
                      ],
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(item.$1),
            ),
          if (r?.overview != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Источник: ${r!.overview!['source']} · ${r!.overview!['updatedAt']}',
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPair22 extends StatelessWidget {
  const AdminPair22({
    super.key,
    required this.title,
    required this.tabs,
    required this.children,
  });
  final String title;
  final List<String> tabs;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t)]),
      ),
      body: TabBarView(children: children),
    ),
  );
}

class MetricDashboard22 extends StatelessWidget {
  const MetricDashboard22({
    super.key,
    required this.title,
    required this.section,
    required this.stale,
  });
  final String title;
  final Map? section;
  final bool stale;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (section == null)
          const Text('Источник не предоставил подтверждённых измерений.'),
        if (stale) const Text('Актуальность данных не подтверждена'),
        for (final e in (section?['metrics'] as Map? ?? {}).entries)
          ListTile(
            title: Text(metricLabels22[e.key] ?? e.key),
            subtitle: Text(
              'Источник: ${e.value['source']} · ${e.value['updatedAt']}',
            ),
            trailing: Text('${e.value['value'] ?? 'Нет данных'}'),
          ),
      ],
    ),
  );
}

class Statistics22Screen extends StatelessWidget {
  const Statistics22Screen({super.key, required this.runtime});
  final Project22Runtime? runtime;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Статистика и отзывы')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Установки, загрузки и добровольные отзывы учитываются отдельно. Личные записи не запрашиваются.',
        ),
        if (runtime?.ratings == null)
          const Text('Нет подтверждённой сводки оценок'),
        for (final s in runtime?.ratings?['snapshot']?['items'] as List? ?? [])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['target']['type']} · ${s['target']['contentId']}'),
                Rating22Summary(
                  value: Map<String, dynamic>.from(s),
                  stale: runtime!.stale,
                ),
                Text(
                  'Рассчитано: ${s['computedAt']} · ${s['weighted']['algorithmId']}@${s['weighted']['algorithmVersion']}',
                ),
              ],
            ),
          ),
        OutlinedButton(
          onPressed: runtime?.admin == true
              ? () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RatingPolicy22Screen(runtime: runtime!),
                  ),
                )
              : null,
          child: const Text('Модель рейтинга'),
        ),
      ],
    ),
  );
}

class RemotePanel22 extends StatefulWidget {
  const RemotePanel22({
    super.key,
    required this.runtime,
    required this.operation,
    required this.listKey,
    this.allowRun = false,
  });
  final Project22Runtime? runtime;
  final String operation, listKey;
  final bool allowRun;
  @override
  State<RemotePanel22> createState() => _RemotePanel22State();
}

class _RemotePanel22State extends State<RemotePanel22> {
  List rows = [];
  String? status;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (widget.runtime?.admin != true) {
      setState(() => status = 'Серверный источник недоступен; режим чтения.');
      return;
    }
    setState(() => busy = true);
    try {
      final v = await widget.runtime!.call(widget.operation, {});
      if (mounted) setState(() => rows = v[widget.listKey] as List? ?? []);
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Обновление недоступно. Предыдущие данные сохранены.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run(Map job) async {
    setState(() => busy = true);
    try {
      await widget.runtime!.call('project.runOperation', {
        'operationId': job['operationId'],
      });
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Сервер не подтвердил выполнение; операция сохранена.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      if (status != null) Text(status!),
      TextButton(
        onPressed: busy ? null : load,
        child: const Text('Запросить актуальные данные'),
      ),
      if (rows.isEmpty && !busy) const Text('Записей от источника нет'),
      for (final raw in rows)
        ListTile(
          title: Text(
            '${raw['state'] ?? raw['role'] ?? raw['code'] ?? raw['at'] ?? raw['uid'] ?? raw['id'] ?? 'Запись'}',
          ),
          subtitle: Text(const JsonEncoder.withIndent('  ').convert(raw)),
          trailing:
              widget.allowRun && ['QUEUED', 'WAITING'].contains(raw['state'])
              ? IconButton(
                  tooltip: 'Выполнить очередной шаг',
                  onPressed: busy ? null : () => run(raw),
                  icon: const Icon(Icons.play_arrow),
                )
              : null,
        ),
    ],
  );
}

class CategoryPanel22 extends StatefulWidget {
  const CategoryPanel22({super.key, required this.runtime});
  final Project22Runtime? runtime;
  @override
  State<CategoryPanel22> createState() => _CategoryPanel22State();
}

class _CategoryPanel22State extends State<CategoryPanel22> {
  List rows = [];
  String? status;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (widget.runtime?.admin != true) return;
      final r = await widget.runtime!.call('project.categories', {});
      if (mounted) setState(() => rows = r['categories']);
    } catch (_) {
      if (mounted) setState(() => status = 'Категории не получены.');
    }
  }

  Future<void> edit([Map? row]) async {
    final c = TextEditingController(text: row?['name']);
    String? parent = row?['parentId'];
    bool archived = row?['archived'] == true;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Категория'),
        content: StatefulBuilder(
          builder: (_, update) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: c, autofocus: true),
              DropdownButton<String>(
                value: parent ?? '',
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Корневая категория'),
                  ),
                  for (final r in rows.where((r) => r['id'] != row?['id']))
                    DropdownMenuItem(value: r['id'], child: Text(r['name'])),
                ],
                onChanged: (v) => update(() => parent = v!.isEmpty ? null : v),
              ),
              CheckboxListTile(
                value: archived,
                onChanged: (v) => update(() => archived = v!),
                title: const Text('Архивировать категорию'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null) return;
    try {
      await widget.runtime!.call('project.categoryEdit', {
        'requestId': newId(),
        'id': row?['id'] ?? newId(),
        'name': name,
        'parentId': parent,
        'archived': archived,
      });
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Не сохранено: проверьте дубликат имени, права и подключение.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      if (status != null) Text(status!),
      if (widget.runtime?.admin != true)
        const Text('Серверный источник структуры недоступен'),
      for (final r in rows)
        ListTile(
          title: Text(r['name']),
          subtitle: Text(r['parentId'] ?? 'Корневой раздел'),
          onTap: () => edit(r),
        ),
      OutlinedButton(
        onPressed: widget.runtime?.admin == true ? () => edit() : null,
        child: const Text('Создать категорию'),
      ),
    ],
  );
}

class RolesPanel22 extends StatefulWidget {
  const RolesPanel22({super.key, required this.runtime});
  final Project22Runtime? runtime;
  @override
  State<RolesPanel22> createState() => _RolesPanel22State();
}

class _RolesPanel22State extends State<RolesPanel22> {
  final uid = TextEditingController();
  String role = 'CLIENT',
      status = 'Роли проверяет сервер. Материалы при отзыве прав сохраняются.';
  bool lead = false, busy = false;
  @override
  void dispose() {
    uid.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final r = await widget.runtime!.call('project.roleChange', {
        'requestId': newId(),
        'uid': uid.text.trim(),
        'role': role,
        'canManageSubordinateRoles': lead,
      });
      if (mounted) {
        setState(() => status = 'Назначение подтверждено: ${r['role']}');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Сервер отклонил назначение. Прежние права и данные сохранены.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(status),
      TextField(
        controller: uid,
        decoration: const InputDecoration(
          labelText: 'Подтверждённый ID пользователя',
        ),
      ),
      DropdownButton<String>(
        value: role,
        items: [
          for (final r in ['CLIENT', 'AUTHOR', 'EDITOR', 'ADMIN'])
            DropdownMenuItem(value: r, child: Text(r)),
        ],
        onChanged: busy ? null : (v) => setState(() => role = v!),
      ),
      CheckboxListTile(
        value: lead,
        onChanged: widget.runtime?.canPublishPolicy == true
            ? (v) => setState(() => lead = v!)
            : null,
        title: const Text('Разрешить назначать и снимать подчинённые роли'),
      ),
      FilledButton(
        onPressed:
            !busy && widget.runtime?.capability?['canManageRoles'] == true
            ? save
            : null,
        child: const Text('Подтвердить назначение'),
      ),
    ],
  );
}
