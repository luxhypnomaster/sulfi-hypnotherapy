import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A vertically dragged cylinder: the supplied metal surface is reprojected
/// around a horizontal axle. No numerical labels or tap-to-change arrows.
class MechanicalWheel extends StatefulWidget {
  const MechanicalWheel({
    super.key,
    required this.label,
    required this.value,
    required this.onDetent,
    this.secondStep = 1,
    this.art,
    this.right = false,
    this.enabled = true,
    this.increasedValue,
    this.decreasedValue,
  });
  final String label, value;
  final String? increasedValue, decreasedValue;
  final bool Function(int ticks) onDetent;
  final int secondStep;
  final ui.Image? art;
  final bool right, enabled;
  static const detentExtent = 14.0; // logical pixels, independent of screen DPI
  static const leftBounds = Rect.fromLTWH(44, 730, 340, 420);
  static const rightBounds = Rect.fromLTWH(696, 730, 340, 420);
  @override
  State<MechanicalWheel> createState() => _MechanicalWheelState();
}

class _MechanicalWheelState extends State<MechanicalWheel>
    with SingleTickerProviderStateMixin {
  late final _phase = AnimationController.unbounded(vsync: this);
  double _movement = 0;
  double? _lastY;

  void _tick(int direction, {bool animate = false}) {
    if (!widget.enabled || !widget.onDetent(direction)) return;
    unawaited(HapticFeedback.selectionClick()); // OS selection feedback policy
    if (animate) {
      unawaited(
        _phase.animateTo(
          _phase.value + direction * .22,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _start(DragStartDetails details) {
    _phase.stop();
    _movement = 0;
    _lastY = details.localPosition.dy;
  }

  void _drag(DragUpdateDetails details) {
    final delta =
        details.localPosition.dy - (_lastY ?? details.localPosition.dy);
    _lastY = details.localPosition.dy;
    _movement -= delta;
    final radius = math.max(1.0, context.size!.height * .5);
    _phase.value -= delta / radius;
    while (_movement.abs() >= MechanicalWheel.detentExtent) {
      final direction = _movement > 0 ? 1 : -1;
      _movement -= direction * MechanicalWheel.detentExtent;
      _tick(direction);
    }
  }

  void _finish() {
    _movement = 0;
    _lastY = null;
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value: widget.value,
    enabled: widget.enabled,
    increasedValue:
        widget.increasedValue ??
        '${(int.tryParse(widget.value) ?? 0) + widget.secondStep}',
    decreasedValue:
        widget.decreasedValue ??
        '${math.max(0, (int.tryParse(widget.value) ?? 0) - widget.secondStep)}',
    onIncrease: widget.enabled ? () => _tick(1, animate: true) : null,
    onDecrease: widget.enabled ? () => _tick(-1, animate: true) : null,
    child: ClipOval(
      child: GestureDetector(
        key: Key('wheel-${widget.label}'),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onVerticalDragStart: widget.enabled ? _start : null,
        onVerticalDragUpdate: widget.enabled ? _drag : null,
        onVerticalDragEnd: (_) => _finish(),
        onVerticalDragCancel: _finish,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _CylinderPainter(widget.art, widget.right, _phase),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _CylinderPainter extends CustomPainter {
  _CylinderPainter(this.art, this.right, this.phase) : super(repaint: phase);
  final ui.Image? art;
  final bool right;
  final Animation<double> phase;

  // Source coordinates follow the approved convex ribbed metal band.
  (double, double) _edges(double y) {
    final t = ((y - 768) / 350).clamp(0.0, 1.0);
    final left = 224 - 38 * math.sin(math.pi * t) + 21 * t;
    final edge = 303 - 22 * math.sin(math.pi * t) + 16 * t;
    return right ? (1080 - edge, 1080 - left) : (left, edge);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = right
        ? MechanicalWheel.rightBounds
        : MechanicalWheel.leftBounds;
    canvas.save();
    canvas.scale(size.width / bounds.width, size.height / bounds.height);
    canvas.translate(-bounds.left, -bounds.top);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (art != null) {
      canvas.drawImageRect(
        art!,
        Rect.fromLTWH(0, 0, art!.width.toDouble(), art!.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1080, 1920),
        paint,
      );
      _surface(canvas, paint);
      if (phase.value.abs() > .00001) _endCap(canvas, paint);
    } else {
      canvas.drawOval(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF512300), Color(0xFFFFD55A), Color(0xFF804000)],
          ).createShader(bounds),
      );
    }
    canvas.restore();
  }

  void _surface(Canvas canvas, Paint paint) {
    // Project individual, photo-textured metal teeth onto a cylinder. Front
    // teeth have a broad face; teeth shrink as they pass the top/bottom rim.
    // Their spacing changes with rotation, while the lighting remains fixed.
    const top = 768.0, height = 350.0, tooth = math.pi * 2 / 28;
    final band = Path();
    for (double y = top; y <= top + height; y += 2) {
      final (l, _) = _edges(y);
      if (y == top) {
        band.moveTo(l, y);
      } else {
        band.lineTo(l, y);
      }
    }
    for (double y = top + height; y >= top; y -= 2) {
      final (_, r) = _edges(y);
      band.lineTo(r, y);
    }
    band.close();
    canvas.save();
    canvas.clipPath(band);
    canvas.drawPath(band, Paint()..color = const Color(0xFF6C3503));
    final source = right
        ? const Rect.fromLTWH(779, 810, 90, 30)
        : const Rect.fromLTWH(211, 810, 90, 30);
    for (var k = -9; k <= 9; k++) {
      final a = k * tooth - phase.value % tooth;
      final b = a + tooth;
      if (b <= -math.pi / 2 || a >= math.pi / 2) continue;
      final y0 =
          top + (math.sin(a.clamp(-math.pi / 2, math.pi / 2)) + 1) * height / 2;
      final y1 =
          top + (math.sin(b.clamp(-math.pi / 2, math.pi / 2)) + 1) * height / 2;
      final (l0, r0) = _edges(y0);
      final (l1, r1) = _edges(y1);
      final left = math.min(l0, l1) - 2, edge = math.max(r0, r1) + 2;
      canvas.drawImageRect(
        art!,
        source,
        Rect.fromLTWH(left, y0, edge - left, y1 - y0 + .5),
        paint,
      );
    }
    final rect = band.getBounds();
    canvas.drawPath(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xAA160400),
            Color(0x00000000),
            Color(0x70130500),
            Color(0xB0130500),
            Color(0x25000000),
          ],
          stops: [0, .22, .52, .8, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _endCap(Canvas canvas, Paint paint) {
    final cx = right ? 746.0 : 334.0;
    const cy = 946.0, rx = 27.0, ry = 120.0;
    final oval = Rect.fromCenter(
      center: Offset(cx, cy),
      width: rx * 2,
      height: ry * 2,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    canvas.translate(cx, cy);
    canvas.scale(rx, ry);
    canvas.rotate(-phase.value);
    canvas.scale(1 / rx, 1 / ry);
    canvas.drawImageRect(
      art!,
      oval,
      const Rect.fromLTWH(-rx, -ry, rx * 2, ry * 2),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CylinderPainter old) =>
      old.art != art || old.right != right;
}
