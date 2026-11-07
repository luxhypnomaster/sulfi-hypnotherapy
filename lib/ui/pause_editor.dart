import 'dart:async';

import 'package:flutter/material.dart';

import '../services/pause_edit_model.dart';
import '../services/preview_player.dart';
import '../services/session_controller.dart';
import 'pause_clock_art.dart';
export 'mechanical_wheel.dart' show MechanicalWheel;

/// Adapter for the existing pre-track delay. Only Apply writes to the draft.
class PauseEditor extends StatefulWidget {
  const PauseEditor({
    super.key,
    required this.controller,
    required this.stepId,
    required this.player,
  });
  final SessionController controller;
  final String stepId;
  final PreviewPlayer player;
  @override
  State<PauseEditor> createState() => _PauseEditorState();
}

class _PauseEditorState extends State<PauseEditor> {
  late final _model = PauseEditModel(
    widget.controller.draft.plan.allSteps
        .firstWhere((s) => s.id == widget.stepId)
        .delayBeforeSeconds,
  );
  bool _saving = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.controller.setDelay(widget.stepId, _model.totalSeconds);
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить паузу. Повторите попытку.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving || _allowPop,
    child: ApprovedPauseClock(
      model: _model,
      saving: _saving,
      onCancel: () => Navigator.maybePop(context),
      onApply: _apply,
    ),
  );
}
