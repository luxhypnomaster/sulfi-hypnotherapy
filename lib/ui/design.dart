import 'package:flutter/material.dart';

import '../models/audio_asset.dart';

const transferYellow = Color(0xFFFFFF00);
const neonPink = Color(0xFFFF168F);
const neonLime = Color(0xFFA6FF2E);
const antiqueGold = Color(0xFFD6A452);
const ink = Color(0xFF0A0509);

Color categoryColor(AudioCategory category) => switch (category) {
  AudioCategory.preparation => const Color(0xFFF5EFE9),
  AudioCategory.induction => const Color(0xFFFF6172),
  AudioCategory.deepener => const Color(0xFFFFA349),
  AudioCategory.safePlace => const Color(0xFFEEC960),
  AudioCategory.progression => const Color(0xFF82C5FF),
  AudioCategory.suggestions => const Color(0xFFDA91FF),
  AudioCategory.work => const Color(0xFFFFE66A),
  AudioCategory.integration => const Color(0xFFA9EC75),
  AudioCategory.exit => const Color(0xFF7ADFE8),
  AudioCategory.freeform => const Color(0xFFC99DF5),
};

class LeatherScaffold extends StatelessWidget {
  const LeatherScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LeatherBoard(
            child: Column(
              children: [
                Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: neonPink,
                      ),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              letterSpacing: .5,
                            ),
                      ),
                    ),
                    ...?actions,
                  ],
                ),
                Expanded(child: child),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = neonPink,
    this.glow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool glow;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: .6)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xDD300C21), Color(0xD910070C)],
      ),
      boxShadow: glow
          ? [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 16)]
          : null,
    ),
    child: child,
  );
}

/// Decorative materials only. All labels, rows and controls remain real widgets.
class LeatherBoard extends StatelessWidget {
  const LeatherBoard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/art/leather_board.png'),
        fit: BoxFit.fill,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 42, 22, 22),
      child: child,
    ),
  );
}

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.compact = false,
    this.stacked = false,
    this.fitLabel = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary, compact, stacked, fitLabel;
  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: Size(48, compact ? 48 : 56),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 18,
        vertical: compact ? 7 : 12,
      ),
      textStyle: compact
          ? Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: stacked ? 11 : 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
            )
          : Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: const Color(0xFF291F27),
      shadowColor: Colors.transparent,
      foregroundColor: primary ? ink : const Color(0xFFFFE9F5),
      side: BorderSide(
        color: primary ? neonLime : neonPink.withValues(alpha: .8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
    Widget decorate(Widget button) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: onPressed == null
              ? [const Color(0xFF291F27), const Color(0xFF1A1218)]
              : primary
              ? [const Color(0xFFC4FF82), neonLime, const Color(0xFF7DE51D)]
              : [
                  const Color(0xFF67123D),
                  const Color(0xFF280A1A),
                  const Color(0xFF16090F),
                ],
        ),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: (primary ? neonLime : neonPink).withValues(alpha: .22),
                  blurRadius: 10,
                ),
              ],
      ),
      child: button,
    );
    if (stacked) {
      return decorate(
        FilledButton(
          onPressed: onPressed,
          style: style,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return decorate(
      FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 19 : 23),
        label: fitLabel
            ? FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))
            : Text(label, textAlign: TextAlign.center),
        style: style,
      ),
    );
  }
}

class CategoryLabel extends StatelessWidget {
  const CategoryLabel(this.category, {super.key});
  final AudioCategory category;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 7, color: categoryColor(category)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          category.label,
          style: TextStyle(color: categoryColor(category), fontSize: 12),
        ),
      ),
    ],
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String confirm = 'Подтвердить',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

Future<({String name, String description})?> askDetails(
  BuildContext context, {
  required String title,
  String name = '',
  String description = '',
  String nameLabel = 'Название',
  String descriptionLabel = 'Описание',
  String? hint,
}) => showDialog<({String name, String description})>(
  context: context,
  builder: (_) => _DetailsDialog(
    title: title,
    name: name,
    description: description,
    nameLabel: nameLabel,
    descriptionLabel: descriptionLabel,
    hint: hint,
  ),
);

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({
    required this.title,
    required this.name,
    required this.description,
    required this.nameLabel,
    required this.descriptionLabel,
    this.hint,
  });
  final String title, name, description, nameLabel, descriptionLabel;
  final String? hint;
  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _description = TextEditingController(text: widget.description);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    widget.hint!,
                    style: const TextStyle(color: antiqueGold),
                  ),
                ),
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: InputDecoration(labelText: widget.nameLabel),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLength: 2000,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: widget.descriptionLabel),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              name: _name.text.trim(),
              description: _description.text.trim(),
            ));
          }
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
