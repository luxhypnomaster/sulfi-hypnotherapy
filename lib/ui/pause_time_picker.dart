import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pause_edit_model.dart';
import 'pause_clock_art.dart';

/// The same clock used for a Pause item in both module and session editors.
/// No writes occur here; the owning editor receives seconds only on Apply.
class PauseTimePicker extends StatefulWidget {
  const PauseTimePicker({
    super.key,
    this.initialSeconds = 0,
    this.manualEnd = false,
  });
  final int initialSeconds;
  // Kept for source compatibility with existing legacy indefinite work items.
  // Applying a duration explicitly converts that legacy item into a timed one.
  final bool manualEnd;
  @override
  State<PauseTimePicker> createState() => _PauseTimePickerState();
}

class _PauseTimePickerState extends State<PauseTimePicker> {
  bool _closing = false;
  late final _model = PauseEditModel(
    widget.initialSeconds,
    maxSeconds: math.max(5995, widget.initialSeconds),
  );
  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ApprovedPauseClock(
    model: _model,
    saving: _closing,
    onCancel: () => Navigator.maybePop(context),
    onApply: () {
      if (_closing) return;
      setState(() => _closing = true);
      Navigator.pop(context, _model.totalSeconds);
    },
  );
}
