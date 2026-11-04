import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pause_edit_model.dart';
import 'mechanical_wheel.dart';

/// One approved 9:16 composition shared by both pause-editing entry points.
/// Original source PNGs stay byte-for-byte intact. Baked text/sigil are masked
/// at paint time; controls, the timer and rotating metal are live Flutter UI.
class ApprovedPauseClock extends StatelessWidget {
  const ApprovedPauseClock({
    super.key,
    required this.model,
    required this.onCancel,
    required this.onApply,
    this.saving = false,
  });
  final PauseEditModel model;
  final VoidCallback onCancel, onApply;
  final bool saving;
  static Future<ui.Image>? _loading;
  static ui.Image? _art;
  static ui.Image? _sigil;
  static Future<ui.Image> load() => _loading ??= _load();
  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  static Future<ui.Image> _load() async {
    final images = await Future.wait([
      _decode('assets/pause/approved.png'),
      _decode('assets/pause/sigil.png'),
    ]);
    _sigil = images[1];
    _art = images[0];
    return images[0];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, available) {
          final width = math.min(
            available.maxWidth,
            available.maxHeight * 9 / 16,
          );
          final scale = width / 1080;
          Rect scaled(Rect r) => Rect.fromLTWH(
            r.left * scale,
            r.top * scale,
            r.width * scale,
            r.height * scale,
          );
          Widget at(Rect r, Widget child) =>
              Positioned.fromRect(rect: scaled(r), child: child);
          Widget text(
            String value,
            double size, {
            Key? key,
            Color color = const Color(0xFFFFE7A3),
            List<Shadow>? shadows,
            BoxFit fit = BoxFit.scaleDown,
          }) => FittedBox(
            fit: fit,
            child: Text(
              value,
              key: key,
              maxLines: 1,
              style: TextStyle(
                inherit: false,
                fontFamily: 'PauseSerif',
                fontSize: size * scale,
                height: 1,
                color: color,
                shadows: shadows,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          );
          Widget button(
            Rect r,
            String label,
            VoidCallback? action, {
            bool primary = false,
            IconData? icon,
          }) {
            final rect = scaled(r);
            return Positioned.fromRect(
              rect: Rect.fromCenter(
                center: rect.center,
                width: rect.width,
                height: math.max(48, rect.height),
              ),
              child: TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const StadiumBorder(),
                  foregroundColor: primary
                      ? Colors.black
                      : const Color(0xFFFFE7A3),
                ),
                child: Container(
                  height: rect.height,
                  width: rect.width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rect.height / 2),
                    border: Border.all(
                      color: primary
                          ? const Color(0xFFD8FF48)
                          : const Color(0xFFE71271),
                      width: math.max(.8, scale * 2),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: primary
                          ? const [
                              Color(0xFFD4FF29),
                              Color(0xFFAFFF00),
                              Color(0xFFC8FF0A),
                            ]
                          : const [
                              Color(0xFF60092B),
                              Color(0xFF200311),
                              Color(0xFF420A24),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (primary
                                    ? const Color(0xFFB8FF00)
                                    : const Color(0xFFFF0068))
                                .withValues(alpha: .44),
                        blurRadius: 20 * scale,
                        spreadRadius: 2 * scale,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: 52 * scale,
                              color: primary
                                  ? Colors.black
                                  : const Color(0xFFFFE7A3),
                            ),
                            SizedBox(width: 14 * scale),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'PauseSerif',
                              fontSize: 44 * scale,
                              fontWeight: primary
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: primary
                                  ? Colors.black
                                  : const Color(0xFFFFE7A3),
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

          return Center(
            child: SizedBox(
              width: width,
              height: width * 16 / 9,
              child: ListenableBuilder(
                listenable: model,
                builder: (context, _) => FutureBuilder<ui.Image>(
                  future: load(),
                  initialData: _art,
                  builder: (context, image) => Stack(
                    clipBehavior: Clip.none,
                    key: const Key('pause-composition'),
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _ApprovedArtwork(image.data, _sigil),
                            ),
                          ),
                        ),
                      ),
                      at(
                        const Rect.fromLTWH(213, 25, 654, 78),
                        Semantics(
                          header: true,
                          child: text('НАСТРОЙКА ПАУЗЫ', 78, fit: BoxFit.fill),
                        ),
                      ),
                      at(
                        const Rect.fromLTWH(225, 147, 630, 44),
                        text(
                          'Установите длительность паузы',
                          44,
                          fit: BoxFit.fill,
                        ),
                      ),
                      at(
                        const Rect.fromLTWH(287, 197, 506, 44),
                        text('00:00 — пропустить паузу', 44, fit: BoxFit.fill),
                      ),
                      Positioned.fromRect(
                        rect: Rect.fromCenter(
                          center: Offset(94 * scale, 71 * scale),
                          width: math.max(48, 108 * scale),
                          height: math.max(48, 108 * scale),
                        ),
                        child: IconButton(
                          tooltip: 'Назад без сохранения',
                          onPressed: saving ? null : onCancel,
                          padding: EdgeInsets.zero,
                          icon: Container(
                            width: 108 * scale,
                            height: 108 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF31376),
                                width: 2 * scale,
                              ),
                              gradient: const RadialGradient(
                                colors: [Color(0xFF330713), Color(0xFF60072A)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x99FF0068),
                                  blurRadius: 16 * scale,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: const Color(0xFFFFE7A3),
                              size: 62 * scale,
                            ),
                          ),
                        ),
                      ),
                      for (final minute in [true, false])
                        at(
                          minute
                              ? MechanicalWheel.leftBounds
                              : MechanicalWheel.rightBounds,
                          MechanicalWheel(
                            label: minute ? 'Минуты' : 'Секунды',
                            value: '${minute ? model.minutes : model.seconds}',
                            right: !minute,
                            art: image.data,
                            enabled: !saving,
                            increasedValue: minute
                                ? '${math.min(model.minutes + 1, (model.maxSeconds - model.seconds) ~/ 60)}'
                                : '${math.min(model.totalSeconds + 1, model.maxSeconds) % 60}',
                            decreasedValue: minute
                                ? '${math.max(model.minutes - 1, 0)}'
                                : '${math.max(model.totalSeconds - 1, 0) % 60}',
                            onDetent: minute
                                ? model.turnMinutes
                                : model.turnSeconds,
                          ),
                        ),
                      at(
                        const Rect.fromLTWH(386, 1007, 308, 144),
                        Semantics(
                          liveRegion: true,
                          label: 'Длительность паузы',
                          value: model.label,
                          child: ExcludeSemantics(
                            child: SizedBox(
                              key: const Key('pause-time-input'),
                              child: text(
                                model.label,
                                152,
                                key: const Key('pause-duration-value'),
                                color: const Color(0xFFFFE6A0),
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFF6A00),
                                    blurRadius: 21 * scale,
                                  ),
                                  Shadow(
                                    color: const Color(0xFFFFB600),
                                    blurRadius: 6 * scale,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      button(
                        const Rect.fromLTWH(28, 1748, 330, 113),
                        'Обнулить',
                        saving ? null : model.reset,
                        icon: Icons.restart_alt,
                      ),
                      button(
                        const Rect.fromLTWH(385, 1748, 290, 113),
                        'Отмена',
                        saving ? null : onCancel,
                      ),
                      button(
                        const Rect.fromLTWH(700, 1748, 350, 113),
                        'Применить',
                        saving ? null : onApply,
                        primary: true,
                        icon: Icons.check,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ApprovedArtwork extends CustomPainter {
  const _ApprovedArtwork(this.art, this.sigil);
  final ui.Image? art, sigil;
  @override
  void paint(Canvas canvas, Size size) {
    if (art == null) return;
    canvas.save();
    canvas.scale(size.width / 1080, size.height / 1920);
    final source = Rect.fromLTWH(
      0,
      0,
      art!.width.toDouble(),
      art!.height.toDouble(),
    );
    canvas.drawImageRect(
      art!,
      source,
      const Rect.fromLTWH(0, 0, 1080, 1920),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Remove gold baked type while retaining the low-green magenta background.
    // Filtering is restricted to these labels; the approved source is intact.
    final eraseGold = Paint()
      ..colorFilter = const ColorFilter.matrix([
        1,
        -1.2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        -.9,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    for (final rect in [
      const Rect.fromLTWH(172, 10, 880, 96),
      const Rect.fromLTWH(169, 141, 770, 105),
    ]) {
      canvas.drawImageRect(art!, rect, rect, eraseGold);
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 1710, 1080, 210),
      Paint()..color = Colors.black,
    );
    final display = RRect.fromRectAndRadius(
      const Rect.fromLTWH(355, 996, 374, 144),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      display,
      Paint()
        ..color = const Color(0xFF080100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(display, Paint()..color = const Color(0xFF080100));
    if (sigil != null) {
      // Feather the clean face into the approved lid: no repeated patch seams.
      canvas.save();
      canvas.translate(540, 1450);
      canvas.scale(240, 185);
      canvas.drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            const [Color(0xFF160501), Color(0xFF1A0601), Color(0x001A0601)],
            const [0, .86, 1],
          ),
      );
      canvas.restore();
      // The physical hinge sits in front of the lid and stays unmodified.
      const hinge = Rect.fromLTWH(280, 1200, 520, 96);
      canvas.drawImageRect(art!, hinge, hinge, Paint());
      const target = Rect.fromLTWH(337, 1311, 405, 280);
      canvas.saveLayer(target.inflate(2), Paint());
      // Exact source geometry: white paper -> transparent, black ink -> alpha.
      canvas.drawImageRect(
        sigil!,
        const Rect.fromLTWH(135, 205, 1110, 1165),
        target,
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = const ColorFilter.matrix([
            0,
            0,
            0,
            0,
            255,
            0,
            0,
            0,
            0,
            255,
            0,
            0,
            0,
            0,
            255,
            -.2126,
            -.7152,
            -.0722,
            0,
            255,
          ]),
      );
      canvas.drawRect(
        target.inflate(1),
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFDD54),
              Color(0xFFC88E16),
              Color(0xFFFFF1A1),
              Color(0xFFBC790C),
              Color(0xFFFFDE57),
            ],
            stops: [0, .25, .5, .73, 1],
          ).createShader(target),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ApprovedArtwork old) =>
      old.art != art || old.sigil != sigil;
}
