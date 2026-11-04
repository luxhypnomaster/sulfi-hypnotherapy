import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mechanical_wheel.dart';

/// Unmodified approved ornament, clipped at paint time. Its example values are
/// masked; only real Flutter labels and gesture controls occupy the clock face.
class ApprovedPauseClock extends StatelessWidget {
  const ApprovedPauseClock({
    super.key,
    required this.minutes,
    required this.seconds,
    required this.onMinutes,
    required this.onSeconds,
    this.secondStep = 1,
  });
  final int minutes, seconds;
  final int secondStep;
  final bool Function(int) onMinutes, onSeconds;
  static Future<ui.Image>? _image;
  static Future<ui.Image> load() => _image ??= _load();
  static Future<ui.Image> _load() async {
    final data = await rootBundle.load('assets/art/pause_approved.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<ui.Image>(
            future: load(),
            builder: (_, snapshot) => ExcludeSemantics(
              child: CustomPaint(painter: _PauseOrnament(snapshot.data)),
            ),
          ),
        ),
        Positioned(
          left: box.maxWidth * .18,
          top: box.maxHeight * .44,
          width: box.maxWidth * .16,
          height: box.maxHeight * .12,
          child: _digits(minutes, 'МИН'),
        ),
        Positioned(
          left: box.maxWidth * .70,
          top: box.maxHeight * .44,
          width: box.maxWidth * .16,
          height: box.maxHeight * .12,
          child: _digits(seconds, 'СЕК'),
        ),
        Positioned(
          left: box.maxWidth * .14,
          top: box.maxHeight * .60,
          width: math.max(48, box.maxWidth * .19),
          height: math.max(48, box.maxHeight * .16),
          child: MechanicalWheel(
            label: 'Минуты',
            value: '$minutes',
            onDetent: onMinutes,
          ),
        ),
        Positioned(
          right: box.maxWidth * .11,
          top: box.maxHeight * .60,
          width: math.max(48, box.maxWidth * .19),
          height: math.max(48, box.maxHeight * .16),
          child: MechanicalWheel(
            label: 'Секунды',
            value: '$seconds',
            secondStep: secondStep,
            onDetent: onSeconds,
          ),
        ),
      ],
    ),
  );
  Widget _digits(int n, String label) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$n'.padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 28,
            color: Color(0xFF542031),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF542031)),
        ),
      ],
    ),
  );
}

class _PauseOrnament extends CustomPainter {
  const _PauseOrnament(this.image);
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    canvas.save();
    canvas.scale(size.width / 640, size.height / 835);
    final outline = Path()
      ..addOval(const Rect.fromLTWH(20, 155, 590, 530))
      ..addRect(const Rect.fromLTWH(190, 0, 450, 300))
      ..addOval(const Rect.fromLTWH(0, 640, 640, 195));
    canvas.clipPath(outline);
    canvas.drawImageRect(
      image!,
      const Rect.fromLTWH(250, 0, 640, 835),
      const Rect.fromLTWH(0, 0, 640, 835),
      Paint(),
    );
    for (final rect in [
      const Rect.fromLTWH(125, 365, 95, 95),
      const Rect.fromLTWH(440, 365, 105, 95),
    ]) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFF3D6CC), Color(0xFFECD5C9), Color(0x00ECD5C9)],
            stops: [0, .72, 1],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PauseOrnament old) => image != old.image;
}
