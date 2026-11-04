import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/audio_asset.dart';
import 'design.dart';
import 'pause_clock_art.dart';

/// A duration value editor. Applying it never alters a pre-track delay.
class PauseTimePicker extends StatefulWidget {
  const PauseTimePicker({
    super.key,
    this.initialSeconds = 0,
    this.manualEnd = false,
  });
  final int initialSeconds;
  final bool manualEnd;
  @override
  State<PauseTimePicker> createState() => _PauseTimePickerState();
}

class _PauseTimePickerState extends State<PauseTimePicker> {
  late int minutes = widget.initialSeconds ~/ 60;
  late int seconds = widget.initialSeconds % 60;
  late bool manualEnd = widget.manualEnd;
  bool _turn(bool minute, int delta) {
    setState(() {
      manualEnd = false;
      if (minute) {
        minutes = (minutes + delta).clamp(0, 999);
      } else {
        seconds = (seconds + delta) % 60;
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройка паузы')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Поворачивайте минуты и секунды вверх или вниз. 00:00 — пропустить паузу.',
            ),
          ),
          if (widget.manualEnd)
            SwitchListTile(
              title: const Text('До завершения вручную'),
              value: manualEnd,
              onChanged: (v) => setState(() => manualEnd = v),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = math.min(box.maxWidth, box.maxHeight / 1.4);
                return Center(
                  child: SizedBox(
                    width: w,
                    height: w * 1.4,
                    child: Column(
                      children: [
                        Expanded(
                          child: ApprovedPauseClock(
                            minutes: minutes,
                            seconds: seconds,
                            onMinutes: (d) => _turn(true, d),
                            onSeconds: (d) => _turn(false, d),
                          ),
                        ),
                        Text(
                          manualEnd
                              ? 'Вручную'
                              : formatPause(minutes * 60 + seconds),
                          key: const Key('pause-duration-value'),
                          style: const TextStyle(
                            fontSize: 30,
                            color: Color(0xFFFFE8A0),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() {
                      minutes = 0;
                      seconds = 0;
                      manualEnd = false;
                    }),
                    child: const Text('Обнулить'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      manualEnd ? -1 : minutes * 60 + seconds,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: neonLime,
                      foregroundColor: ink,
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
