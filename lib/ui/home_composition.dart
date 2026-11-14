import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import '../models/modular_plan.dart';
import '../models/plan_duration.dart';
import '../models/session_plan.dart';
import '../services/session_controller.dart';
import 'booking.dart';
import 'design.dart';
import 'changed_content_name.dart';
import 'space_sheet.dart';
import 'session_actions.dart';
import '../services/preview_player.dart';
import 'preview_bar.dart';
import 'diary_home.dart';
import 'home_start_art.dart';

const _lime = Color(0xFFDFFF00);

/// The reference supplies only its non-interactive brand/portrait region.
/// Source pixels below y=185 (diary tab, board, controls) are never displayed.
class HomeReferenceHeader extends StatelessWidget {
  const HomeReferenceHeader({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Самогипноз. Сульфи. Ваш внутренний навигатор.',
    image: true,
    child: LayoutBuilder(
      builder: (context, box) {
        Widget source() => OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: box.maxWidth,
          maxWidth: box.maxWidth,
          minHeight: box.maxWidth * 1280 / 683,
          maxHeight: box.maxWidth * 1280 / 683,
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/art/home_reference.jpg',
              width: box.maxWidth,
              height: box.maxWidth * 1280 / 683,
              fit: BoxFit.fill,
              alignment: Alignment.topCenter,
            ),
          ),
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              source(),
              // Recolour only the existing sulfur pixels; original geometry and
              // source position remain exact. The original JPEG is not edited.
              ClipPath(
                clipper: _SulfurClipper(),
                child: ColorFiltered(
                  key: const Key('home-yellow-sulfur'),
                  colorFilter: const ColorFilter.matrix([
                    1,
                    0,
                    0,
                    0,
                    0,
                    224 / 255,
                    18 / 255,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    4,
                    0,
                    0,
                    0,
                    -204,
                  ]),
                  child: source(),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SulfurClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final scale = size.width / 683;
    var region = Path()
      ..moveTo(290, 16)
      ..lineTo(334, 88)
      ..lineTo(246, 88)
      ..close();
    for (final shape in [
      Path()..addRect(const Rect.fromLTRB(276, 76, 306, 134)),
      Path()..addRect(const Rect.fromLTRB(260, 90, 319, 112)),
      Path()..addOval(const Rect.fromLTRB(272, 105, 309, 141)),
    ]) {
      region = Path.combine(PathOperation.union, region, shape);
    }
    return region.transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
  }

  @override
  bool shouldReclip(_SulfurClipper old) => false;
}

class HomeComposition extends StatelessWidget {
  const HomeComposition({
    super.key,
    required this.controller,
    required this.busy,
    required this.onStructure,
    required this.onTemplates,
    required this.onLibrary,
    required this.onHistory,
    required this.onNotes,
    required this.onStart,
    required this.onPreview,
    required this.clock,
    this.player,
  });
  final SessionController controller;
  final PreviewPlayer? player;
  final bool busy;
  final VoidCallback onStructure, onTemplates, onLibrary, onHistory, onNotes;
  final VoidCallback? onStart;
  final Future<void> Function(SessionStep) onPreview;
  final Widget clock;

  @override
  Widget build(BuildContext context) {
    final plan = modularize(controller.draft.plan);
    return Scaffold(
      backgroundColor: ink,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (player != null)
                PreviewBar(
                  player: player!,
                  library: controller.library,
                  compact: true,
                ),
              TransformationButton(onPressed: onStart),
              const SizedBox(height: 4),
              Row(
                key: const Key('home-navigation'),
                children: [
                  _NavButton(
                    label: BookingConfig.label.replaceFirst(' к ', '\nк '),
                    master: true,
                    onPressed: busy ? null : () => showBooking(context),
                  ),
                  _NavButton(
                    label: 'Библиотека',
                    icon: Icons.headphones,
                    onPressed: busy ? null : onLibrary,
                  ),
                  _NavButton(
                    label: 'Программы\nи модули',
                    icon: Icons.layers_outlined,
                    onPressed: busy ? null : onTemplates,
                  ),
                  _NavButton(
                    label: 'История',
                    icon: Icons.history,
                    onPressed: busy ? null : onHistory,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final headerHeight = box.maxHeight < 300
                ? 0.0
                : (box.maxWidth * 185 / 683).clamp(0.0, box.maxHeight * .24);
            return Column(
              children: [
                SizedBox(
                  key: const Key('home-portrait'),
                  height: headerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const HomeReferenceHeader(),
                      Positioned(
                        top: 0,
                        right: 4,
                        child: IconButton(
                          key: const Key('home-space'),
                          tooltip: 'Аккаунт, права и данные',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: busy || player == null
                              ? null
                              : () => showSpaceSheet(
                                  context,
                                  library: controller.library,
                                  controller: controller,
                                  player: player!,
                                  onReset: () =>
                                      showActionError(context, () async {
                                        if (!await confirmAction(
                                          context,
                                          'Удалить все данные?',
                                          'Библиотека, программы, текущая конфигурация и история будут удалены с этого устройства. Исходные файлы останутся на месте.',
                                          confirm: 'Удалить всё',
                                        )) {
                                          return;
                                        }
                                        await player!.stop();
                                        await controller.library.reset();
                                        await controller.reload();
                                      }),
                                ),
                          icon: const Icon(Icons.shield_outlined),
                          color: transferYellow,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DiaryHomeBoard(
                    diary: controller.diary,
                    child: LayoutBuilder(
                      builder: (context, content) {
                        final compact = content.maxHeight < 240;
                        final heading = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SessionStrip(
                              controller: controller,
                              clock: clock,
                              onNotes: busy ? null : onNotes,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: busy ? null : onStructure,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.only(left: 3),
                                      minimumSize: const Size(48, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: const Color(0xFFF5F0EE),
                                    ),
                                    child: const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Структура сессии',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Открыть конструктор',
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: busy ? null : onStructure,
                                  icon: const Icon(
                                    Icons.open_in_full,
                                    color: neonPink,
                                    size: 23,
                                  ),
                                ),
                              ],
                            ),
                            Semantics(
                              label: PlanDuration.plan(plan).semantics,
                              child: Wrap(
                                spacing: 5,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _counts(plan),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.15,
                                    ),
                                  ),
                                  const Text(
                                    'Длительность',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  Text(
                                    PlanDuration.plan(plan).label,
                                    key: const Key('home-duration'),
                                    style: const TextStyle(
                                      color: _lime,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.diary != null)
                              DiaryHomeMessage(diary: controller.diary!),
                            if (controller.saveError != null)
                              Text(
                                controller.saveError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                              ),
                            const SizedBox(height: 7),
                          ],
                        );
                        final overview = HomePlanOverview(
                          plan: plan,
                          moduleDiffers: controller.moduleDiffersFromSource,
                          player: player,
                          unavailableStepIds:
                              controller.draft.unavailableStepIds,
                          onStructure: busy ? null : onStructure,
                          onPreview: busy ? null : onPreview,
                        );
                        final template = _TemplateStrip(
                          controller: controller,
                          onPressed: busy ? null : onTemplates,
                        );
                        if (compact) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                heading,
                                overview,
                                const SizedBox(height: 12),
                                template,
                              ],
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heading,
                            Expanded(
                              child: SingleChildScrollView(child: overview),
                            ),
                            const SizedBox(height: 5),
                            template,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _counts(SessionPlan plan) => [
    structureCount(
      plan.phases!.where((p) => p.enabled).length,
      'фаза',
      'фазы',
      'фаз',
    ),
    structureCount(
      plan.phases!
          .where((p) => p.enabled)
          .expand((p) => p.children)
          .where((c) => c.enabled && c.isModule)
          .length,
      'модуль',
      'модуля',
      'модулей',
    ),
    structureCount(
      plan.steps.where((s) => s.kind == StepKind.audio).length,
      'трек',
      'трека',
      'треков',
    ),
  ].join(' · ');
}

class _SessionStrip extends StatelessWidget {
  const _SessionStrip({
    required this.controller,
    required this.clock,
    required this.onNotes,
  });
  final SessionController controller;
  final Widget clock;
  final VoidCallback? onNotes;
  @override
  Widget build(BuildContext context) => NeonPanel(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    glow: true,
    child: SizedBox(
      key: const Key('home-session-strip'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * .26),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Сессия №${controller.nextNumber}',
                    style: const TextStyle(
                      color: _lime,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * .29),
                child: FittedBox(fit: BoxFit.scaleDown, child: clock),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 4,
                child: Tooltip(
                  message: controller.draft.topicText.isEmpty
                      ? 'Тема / запрос и заметка'
                      : controller.draft.topicText,
                  child: TextButton(
                    onPressed: onNotes,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      controller.draft.topicText.isEmpty
                          ? 'Тема / запрос'
                          : controller.draft.topicText,
                      key: const Key('home-topic'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFEBD8E0),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 26,
                child: PopupMenuButton<String>(
                  tooltip: 'Действия сессии',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(26, 36),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  enabled: onNotes != null,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: neonPink, size: 21),
                  onSelected: (_) => onNotes?.call(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'notes',
                      child: Text('Тема и заметка'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomePlanOverview extends StatefulWidget {
  const HomePlanOverview({
    super.key,
    required this.plan,
    required this.onStructure,
    required this.onPreview,
    this.player,
    this.unavailableStepIds = const [],
    this.moduleDiffers,
  });
  final bool Function(PhaseChild)? moduleDiffers;
  final SessionPlan plan;
  final PreviewPlayer? player;
  final List<String> unavailableStepIds;
  final VoidCallback? onStructure;
  final Future<void> Function(SessionStep)? onPreview;
  @override
  State<HomePlanOverview> createState() => _HomePlanOverviewState();
}

class _HomePlanOverviewState extends State<HomePlanOverview> {
  final Map<String, bool> expanded = {};
  @override
  Widget build(BuildContext context) => widget.player == null
      ? _overview(context)
      : ListenableBuilder(
          listenable: widget.player!,
          builder: (context, _) => _overview(context),
        );
  Widget _overview(BuildContext context) {
    final phases = widget.plan.phases!.where((p) => p.enabled).toList();
    if (phases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: TextButton(
          onPressed: widget.onStructure,
          child: const Text(
            'Добавьте фазу и свои аудиотреки\nОткрыть конструктор',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < phases.length; i++)
          _phase(phases[i], i + 1, phases.length),
        const Divider(height: 20, color: Color(0xFFB29AA5), thickness: .6),
      ],
    );
  }

  Widget _phase(PhaseInstance p, int number, int count) {
    final open = expanded[p.id] ?? (count == 1 || p.typeId == 'induction');
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: NeonPanel(
        key: ValueKey('home-phase-${p.id}'),
        padding: EdgeInsets.zero,
        glow: open,
        child: Column(
          children: [
            InkWell(
              key: ValueKey('home-expand-${p.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => expanded[p.id] = !open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 19,
                        height: 19,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC7A5B7)),
                        ),
                        child: FittedBox(
                          child: Text(
                            '$number',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Фаза: ${p.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: open ? _lime : const Color(0xFFF8EAF1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Semantics(
                        label: PlanDuration.phase(p).semantics,
                        child: Text(
                          PlanDuration.phase(p).label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 23,
                        color: neonPink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 1, 7, 6),
                child: Column(
                  children: [
                    for (final child in p.children.where((c) => c.enabled))
                      if (child.isModule)
                        _module(child)
                      else
                        ...child.items.where((s) => s.enabled).map(_track),
                    if (p.children.every(
                      (c) =>
                          !c.enabled || c.items.where((s) => s.enabled).isEmpty,
                    ))
                      TextButton(
                        onPressed: widget.onStructure,
                        child: const Text(
                          'Добавить содержимое',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _module(PhaseChild c) {
    final open = expanded[c.id] ?? true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBD93A8), width: .7),
        borderRadius: BorderRadius.circular(7),
        color: const Color(0x661C0611),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded[c.id] = !open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 27),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.layers_outlined,
                      color: neonPink,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: ChangedContentName(
                      title: 'Модуль: ${c.title}',
                      changed: widget.moduleDiffers?.call(c) == true,
                      markerKey: ValueKey('module-changed-${c.id}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.moduleDiffers?.call(c) == true
                            ? neonPink
                            : null,
                        fontStyle: widget.moduleDiffers?.call(c) == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      PlanDuration.child(c).label,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 30,
                    child: PopupMenuButton<String>(
                      tooltip: 'Действия модуля ${c.title}',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_vert,
                        size: 19,
                        color: neonPink,
                      ),
                      onSelected: (_) => widget.onStructure?.call(),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'structure',
                          child: Text('Открыть в структуре'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...c.items.where((s) => s.enabled).map(_track),
        ],
      ),
    );
  }

  Widget _track(SessionStep s) => Column(
    children: [
      if (s.delayBeforeSeconds > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: widget.onStructure,
            child: Text(
              'Пауза перед треком: ${formatPause(s.delayBeforeSeconds)}',
              style: const TextStyle(fontSize: 10, color: antiqueGold),
            ),
          ),
        ),
      Row(
        children: [
          SizedBox(
            width: 33,
            height: 28,
            child: IconButton(
              tooltip: s.kind == StepKind.audio
                  ? (widget.player?.current?.id == s.audioAssetId &&
                            (widget.player?.playing ?? false)
                        ? 'Пауза прослушивания'
                        : 'Прослушать ${s.title}')
                  : s.kind.label,
              onPressed: s.kind == StepKind.audio && widget.onPreview != null
                  ? () => widget.onPreview!(s)
                  : widget.onStructure,
              padding: EdgeInsets.zero,
              icon: Icon(
                s.kind == StepKind.audio
                    ? (widget.player?.current?.id == s.audioAssetId &&
                              (widget.player?.playing ?? false)
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline)
                    : Icons.pause_circle_outline,
                color: s.kind == StepKind.audio ? neonPink : antiqueGold,
                size: 21,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.onStructure,
              child: Text(
                '${widget.unavailableStepIds.contains(s.id) ? '⚠ Недоступен · ' : ''}${s.kind == StepKind.audio ? s.title : s.kind.label}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              s.durationMs == null ? '—:—' : formatDuration(s.durationMs!),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    ],
  );
}

class _TemplateStrip extends StatelessWidget {
  const _TemplateStrip({required this.controller, required this.onPressed});
  final SessionController controller;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final title =
        controller.baseTemplate?.name ??
        (controller.draft.archiveName == null
            ? null
            : 'Архивный · ${controller.draft.archiveName}') ??
        controller.draft.baseTemplateName ??
        'Выбрать программу';
    return Tooltip(
      message: title,
      child: InkWell(
        key: const Key('active-template'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: NeonPanel(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          glow: true,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 17, color: ink),
                    SizedBox(width: 3),
                    Text(
                      'Программа',
                      style: TextStyle(
                        fontSize: 10,
                        color: ink,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: ChangedContentName(
                      title: title,
                      changed: controller.templateDiffersFromSource,
                      markerKey: const Key('template-changed'),
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: controller.templateDiffersFromSource
                            ? neonPink
                            : null,
                        fontStyle: controller.templateDiffersFromSource
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ),
              ),
              if (controller.templateDiffersFromSource &&
                  controller.draft.baseTemplateId != null)
                const Tooltip(
                  message: 'Текущая конфигурация изменена',
                  child: Icon(Icons.edit_outlined, color: _lime, size: 14),
                ),
              const Icon(Icons.chevron_right, color: neonPink, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.master = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool master;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF160710),
          border: Border.all(
            color: master ? _lime : neonPink.withValues(alpha: .7),
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: master
              ? [BoxShadow(color: _lime.withValues(alpha: .25), blurRadius: 7)]
              : null,
        ),
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 83 : 51,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              foregroundColor: master ? _lime : const Color(0xFFE8DDE4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (master)
                  Image.asset(
                    'assets/brand/spiral.png',
                    width: 23,
                    height: 23,
                    color: _lime,
                  )
                else
                  Icon(icon, color: neonPink, size: 22),
                const SizedBox(height: 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.04,
                        fontStyle: master ? FontStyle.italic : null,
                        fontWeight: master ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
