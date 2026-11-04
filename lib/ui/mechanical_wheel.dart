import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

class MechanicalWheel extends StatefulWidget {
  const MechanicalWheel({
    super.key,
    required this.label,
    required this.value,
    required this.onDetent,
    this.secondStep = 5,
  });
  final String label, value;
  final bool Function(int ticks) onDetent;
  final int secondStep;
  @override
  State<MechanicalWheel> createState() => _MechanicalWheelState();
}

class _MechanicalWheelState extends State<MechanicalWheel> {
  double _movement = 0, _offset = 0;
  void _tick(int direction) {
    if (widget.onDetent(direction)) {
      setState(() => _offset += direction * 14);
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    value: widget.value,
    increasedValue:
        '${widget.label == 'Секунды' ? ((int.tryParse(widget.value) ?? 0) + widget.secondStep) % 60 : ((int.tryParse(widget.value) ?? 0) + 1).clamp(0, 99)}',
    decreasedValue:
        '${widget.label == 'Секунды' ? ((int.tryParse(widget.value) ?? 0) - widget.secondStep) % 60 : ((int.tryParse(widget.value) ?? 0) - 1).clamp(0, 99)}',
    onIncrease: () => _tick(1),
    onDecrease: () => _tick(-1),
    child: GestureDetector(
      key: Key('wheel-${widget.label}'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _movement = 0,
      onVerticalDragUpdate: (d) {
        _movement -= d.delta.dy;
        while (_movement.abs() >= 14) {
          final direction = _movement > 0 ? 1 : -1;
          _movement -= direction * 14;
          _tick(direction);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _offset),
              duration: const Duration(milliseconds: 70),
              builder: (context, offset, _) =>
                  CustomPaint(painter: _WheelTicks(offset)),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label == 'Минуты'
                      ? 'мин'
                      : widget.label == 'Секунды'
                      ? 'сек'
                      : widget.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFFFD979),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WheelTicks extends CustomPainter {
  const _WheelTicks(this.offset);
  final double offset;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = const Color(0xFFFFD260).withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double y = offset % 14 - 14; y < size.height + 14; y += 14) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .28, y)
          ..quadraticBezierTo(size.width * .5, y + 5, size.width * .72, y),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelTicks oldDelegate) => oldDelegate.offset != offset;
}
