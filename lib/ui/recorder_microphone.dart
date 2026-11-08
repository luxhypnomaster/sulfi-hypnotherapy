import 'package:flutter/material.dart';

import 'design.dart';

/// Live recorder control: glowing microphone outline and original Sulfi spiral.
class RecorderMicrophone extends StatelessWidget {
  const RecorderMicrophone({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    height: 102,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          width: 48,
          height: 72,
          child: CustomPaint(
            painter: _Capsule(),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Image.asset('assets/brand/spiral.png'),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _Stand())),
      ],
    ),
  );
}

class _Capsule extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(25),
    );
    for (final glow in [true, false]) {
      final p = Paint()
        ..color = neonPink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (glow) p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(shape, p);
    }
  }

  @override
  bool shouldRepaint(_Capsule oldDelegate) => false;
}

class _Stand extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(7, 46)
      ..lineTo(7, 55)
      ..cubicTo(7, 94, s.width - 7, 94, s.width - 7, 55)
      ..lineTo(s.width - 7, 46);
    final stem = Path()
      ..moveTo(s.width / 2, 82)
      ..lineTo(s.width / 2, 99)
      ..moveTo(23, 99)
      ..lineTo(s.width - 23, 99);
    for (final blur in [true, false]) {
      final p = Paint()
        ..color = neonPink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      if (blur) p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, p);
      canvas.drawPath(stem, p);
    }
  }

  @override
  bool shouldRepaint(_Stand oldDelegate) => false;
}
