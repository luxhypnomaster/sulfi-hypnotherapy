import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';

/// Only the decorative vortex is sampled from the approved reference.
/// No baked caption, button, or navigation control is displayed from this JPEG.
class HomeVortex extends StatelessWidget {
  const HomeVortex({super.key});
  static const source = Rect.fromLTWH(70, 1545, 220, 220);
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipOval(
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = box.maxWidth / source.width;
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 1080 * scale,
            maxWidth: 1080 * scale,
            minHeight: 1920 * scale,
            maxHeight: 1920 * scale,
            child: Transform.translate(
              offset: Offset(-source.left * scale, -source.top * scale),
              child: Image.asset(
                'assets/art/home_task3_reference.jpg',
                width: 1080 * scale,
                height: 1920 * scale,
                fit: BoxFit.fill,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class TransformationButton extends StatelessWidget {
  const TransformationButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('home-start'),
    height: 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 18,
          right: 2,
          top: 4,
          bottom: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: onPressed == null
                    ? const [Color(0xFF737B40), Color(0xFF53572C)]
                    : const [
                        Color(0xFFE5FF30),
                        Color(0xFFDFFF00),
                        Color(0xFFB3FF00),
                      ],
              ),
              boxShadow: onPressed == null
                  ? []
                  : [
                      BoxShadow(
                        color: neonPink.withValues(alpha: .45),
                        blurRadius: 9,
                      ),
                      const BoxShadow(color: Color(0x66DFFF00), blurRadius: 5),
                    ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: onPressed == null ? .18 : 1,
              child: CustomPaint(painter: _EnergyThreads()),
            ),
          ),
        ),
        Positioned(
          left: -2,
          top: -5,
          width: 66,
          height: 66,
          child: IgnorePointer(
            child: Opacity(
              opacity: onPressed == null ? .3 : 1,
              child: const HomeVortex(),
            ),
          ),
        ),
        Positioned.fill(
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: ink,
              disabledForegroundColor: const Color(0xFF25251C),
              padding: const EdgeInsets.fromLTRB(64, 3, 9, 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'НАЧАТЬ ТРАНСФОРМАЦИЮ',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Icon(Icons.double_arrow, size: 23),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EnergyThreads extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boundary = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(17, 4, size.width - 2, size.height - 4),
          const Radius.circular(27),
        ),
      );
    final metric = boundary.computeMetrics().first;
    for (var strand = 0; strand < 3; strand++) {
      final path = Path();
      for (var i = 0; i <= 220; i++) {
        final tangent = metric.getTangentForOffset(metric.length * i / 220)!;
        final wave =
            math.sin(i * .61 + strand * 2) * 1.4 +
            math.sin(i * .17 + strand) * 1.1;
        final point =
            tangent.position +
            Offset(-math.sin(tangent.angle), math.cos(tangent.angle)) * wave;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      final color = strand == 0
          ? neonPink
          : strand == 1
          ? const Color(0xFFDFFF00)
          : const Color(0xFFFFF200);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_EnergyThreads old) => false;
}
