import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

/// Only ornament pixels from the approved reference. UI labels and controls are
/// never included in these clips; the fluid and clock face are live Flutter paint.
class PlayerArt extends StatefulWidget {
  const PlayerArt({super.key, required this.flask, this.liquid = 1});
  final bool flask;
  final double liquid;
  static Future<ui.Image>? _image;
  static Future<ui.Image> load() => _image ??= _PlayerArtState._load();
  @override
  State<PlayerArt> createState() => _PlayerArtState();
}

class _PlayerArtState extends State<PlayerArt> {
  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: PlayerArt.load(),
    builder: (context, s) => ExcludeSemantics(
      child: CustomPaint(
        painter: _ArtPainter(s.data, widget.flask, widget.liquid),
        size: Size.infinite,
      ),
    ),
  );
  static Future<ui.Image> _load() async {
    final bytes = await rootBundle.load('assets/player/approved.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.source, this.flask, this.liquid);
  final ui.Image? source;
  final bool flask;
  final double liquid;
  @override
  void paint(Canvas canvas, Size size) {
    if (flask) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xff050004),
      );
      canvas.save();
      canvas.scale(size.width / 190, size.height / 1517);
      final shape = Path()
        ..moveTo(57, 130)
        ..lineTo(112, 130)
        ..lineTo(112, 1270)
        ..cubicTo(114, 1330, 184, 1380, 170, 1445)
        ..cubicTo(166, 1520, 10, 1510, 11, 1445)
        ..cubicTo(7, 1390, 56, 1330, 57, 1270)
        ..close();
      canvas.save();
      final ornamentalClip = Path.combine(
        PathOperation.union,
        shape,
        Path()
          ..addRect(const Rect.fromLTWH(0, 0, 190, 145))
          ..addRect(const Rect.fromLTWH(0, 120, 65, 500))
          ..addRect(const Rect.fromLTWH(0, 1440, 185, 77)),
      );
      canvas.clipPath(ornamentalClip);
      // The old profile head ends above y=145. Keep only its lower body.
      canvas.clipRect(const Rect.fromLTRB(0, 145, 190, 1517));
      if (source != null) {
        canvas.drawImageRect(
          source!,
          const Rect.fromLTWH(0, 136, 190, 1517),
          const Rect.fromLTWH(0, 0, 190, 1517),
          Paint()..blendMode = BlendMode.screen,
        );
      }
      canvas.restore();
      final inside = Path()
        ..moveTo(70, 160)
        ..lineTo(102, 160)
        ..lineTo(102, 1275)
        ..cubicTo(104, 1336, 157, 1393, 151, 1440)
        ..cubicTo(150, 1480, 30, 1480, 27, 1440)
        ..cubicTo(25, 1400, 69, 1330, 70, 1275)
        ..close();
      canvas.save();
      canvas.clipPath(inside);
      canvas.drawRect(
        const Rect.fromLTWH(0, 150, 190, 1330),
        Paint()..color = const Color(0xff071307),
      );
      final top = 1475 - 1315 * liquid.clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTRB(0, top, 190, 1480),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xffd9ff16), Color(0xff5bc900), Color(0xffc5ed00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(const Rect.fromLTWH(0, 0, 190, 1480)),
      );
      for (var i = 0; i < 28; i++) {
        final y = 1460.0 - i * 44;
        if (y > top) {
          canvas.drawCircle(
            Offset(74.0 + (i * 17 % 25), y),
            1.6 + i % 3,
            Paint()
              ..color = const Color(0xFFFFE044).withValues(alpha: .7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      }
      canvas.drawLine(
        Offset(0, top),
        Offset(190, top),
        Paint()
          ..color = neonLime
          ..strokeWidth = 6,
      );
      canvas.restore();
      canvas.restore();
    } else {
      // Golden pocket-watch case/chain; mask the original illustrative display.
      canvas.save();
      canvas.scale(size.width / 470, size.height / 595);
      if (source != null) {
        canvas.drawImageRect(
          source!,
          const Rect.fromLTWH(470, 250, 470, 595),
          const Rect.fromLTWH(0, 0, 470, 595),
          Paint(),
        );
      }
      final face = const Rect.fromLTWH(60, 157, 323, 323);
      canvas.drawOval(
        face,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xff2a061d), Color(0xff050004)],
          ).createShader(face),
      );
      if (source != null) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(const Rect.fromLTWH(101, 178, 244, 86)),
        );
        canvas.drawImageRect(
          source!,
          const Rect.fromLTWH(571, 428, 244, 86),
          const Rect.fromLTWH(101, 178, 244, 86),
          Paint(),
        );
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.source != source || old.liquid != liquid || old.flask != flask;
}
