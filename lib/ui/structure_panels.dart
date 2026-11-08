import 'package:flutter/material.dart';

import 'design.dart';

/// Consecutive list rows paint one continuous enclosing phase/module panel.
/// This keeps a single reorderable scroll surface without flattening the
/// visible ownership or wrapping legacy direct items in invented modules.
class StructurePanelSegment extends StatelessWidget {
  const StructurePanelSegment({
    super.key,
    required this.child,
    required this.first,
    required this.last,
    this.module = false,
  });
  final Widget child;
  final bool first, last, module;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PanelPainter(first: first, last: last, module: module),
    child: child,
  );
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter({
    required this.first,
    required this.last,
    required this.module,
  });
  final bool first, last, module;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final edge = module ? .7 : .9;
    final bounds = Rect.fromLTWH(
      edge,
      first ? edge : 0,
      size.width - 2 * edge,
      size.height - (first ? edge : 0) - (last ? edge : 0),
    );
    final radius = module ? 8.0 : 12.0;
    final shape = RRect.fromRectAndCorners(
      bounds,
      topLeft: Radius.circular(first ? radius : 0),
      topRight: Radius.circular(first ? radius : 0),
      bottomLeft: Radius.circular(last ? radius : 0),
      bottomRight: Radius.circular(last ? radius : 0),
    );
    final colors = module
        ? first
              ? const [Color(0xFF69304C), Color(0xFF321020)]
              : const [Color(0xFF210B16), Color(0xFF210B16)]
        : first
        ? const [Color(0xFF5E0834), Color(0xFF2C071A)]
        : const [Color(0xFF1C0610), Color(0xFF1C0610)];
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(bounds),
    );
    final path = Path();
    if (first) {
      path.moveTo(bounds.left, bounds.top + radius);
      path.quadraticBezierTo(
        bounds.left,
        bounds.top,
        bounds.left + radius,
        bounds.top,
      );
      path.lineTo(bounds.right - radius, bounds.top);
      path.quadraticBezierTo(
        bounds.right,
        bounds.top,
        bounds.right,
        bounds.top + radius,
      );
    } else {
      path.moveTo(bounds.right, bounds.top);
    }
    path.lineTo(bounds.right, bounds.bottom - (last ? radius : 0));
    if (last) {
      path.quadraticBezierTo(
        bounds.right,
        bounds.bottom,
        bounds.right - radius,
        bounds.bottom,
      );
      path.lineTo(bounds.left + radius, bounds.bottom);
      path.quadraticBezierTo(
        bounds.left,
        bounds.bottom,
        bounds.left,
        bounds.bottom - radius,
      );
    } else {
      path.moveTo(bounds.left, bounds.bottom);
    }
    path.lineTo(bounds.left, bounds.top + (first ? radius : 0));
    final color = module ? const Color(0xFFE0B9CD) : neonPink;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = module ? 1.8 : 3
        ..color = color.withValues(alpha: module ? .18 : .36)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, module ? 2 : 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = module ? .9 : 1.3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.first != first || old.last != last || old.module != module;
}
