import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';

const neonPink = Color(0xFFFF168F);
const neonLime = Color(0xFFDFFF00);
const antiqueGold = Color(0xFFD6A452);
const ink = Color(0xFF0A0509);

Color categoryColor(AudioCategory category) => switch (category) {
  AudioCategory.preparation => const Color(0xFFF5EFE9),
  AudioCategory.induction => const Color(0xFFFF6172),
  AudioCategory.deepener => const Color(0xFFFFA349),
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
    appBar: AppBar(title: Text(title), actions: actions),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [Color(0xFF3C0624), ink],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomPaint(
              painter: const _LeatherPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 28, 6, 8),
                child: Column(
                  children: [
                    Expanded(child: child),
                    ?bottom,
                  ],
                ),
              ),
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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .6)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF300C21), Color(0xFF100A0E)],
      ),
      boxShadow: glow
          ? [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 16)]
          : null,
    ),
    child: child,
  );
}

class LeatherBoard extends StatelessWidget {
  const LeatherBoard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _LeatherPainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 24),
      child: child,
    ),
  );
}

class _LeatherPainter extends CustomPainter {
  const _LeatherPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF25131C), Color(0xFF100B0F), Color(0xFF21101B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipRRect(rect);
    final noise = math.Random(17);
    final grain = Paint()
      ..color = const Color(0xFFAE7290).withValues(alpha: .065);
    for (var i = 0; i < 1000; i++) {
      final p = Offset(
        noise.nextDouble() * size.width,
        noise.nextDouble() * size.height,
      );
      canvas.drawCircle(p, .4 + noise.nextDouble() * .4, grain);
    }
    canvas.restore();
    canvas.drawRRect(
      rect.deflate(2),
      Paint()
        ..color = neonPink.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final seam = Paint()
      ..color = const Color(0xFF8A4D57)
      ..strokeWidth = 1;
    for (double x = 16; x < size.width - 16; x += 8) {
      canvas.drawLine(Offset(x, 10), Offset(x + 4, 10), seam);
      canvas.drawLine(
        Offset(x, size.height - 10),
        Offset(x + 4, size.height - 10),
        seam,
      );
    }
    for (double y = 20; y < size.height - 20; y += 8) {
      canvas.drawLine(Offset(9, y), Offset(9, y + 4), seam);
      canvas.drawLine(
        Offset(size.width - 9, y),
        Offset(size.width - 9, y + 4),
        seam,
      );
    }
    final clip = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 12),
        width: 142,
        height: 24,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      clip,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF5C371E),
            Color(0xFFE9C983),
            Color(0xFF765029),
            Color(0xFFE2BC71),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(clip.outerRect),
    );
    canvas.drawRRect(
      clip.deflate(3),
      Paint()
        ..color = const Color(0xFF684325)
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_LeatherPainter oldDelegate) => false;
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
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary, compact, stacked;
  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: Size(48, compact ? 48 : 54),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 18, vertical: 12),
      textStyle: stacked
          ? Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600)
          : null,
      backgroundColor: primary ? neonLime : const Color(0xFF4B0B32),
      foregroundColor: primary ? ink : const Color(0xFFFFE9F5),
      side: BorderSide(
        color: primary ? neonLime : neonPink.withValues(alpha: .8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
    if (stacked) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 19 : 23),
      label: Text(label, textAlign: TextAlign.center),
      style: style,
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
