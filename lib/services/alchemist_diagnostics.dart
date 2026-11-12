import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_plan.dart';

/// Bounded RAM-only measurements; no URL, parameters, claims, title or token.
class AlchemistDiagnostics extends ChangeNotifier {
  static final instance = AlchemistDiagnostics();
  final List<Map<String, Object?>> _events = [];
  List<Map<String, Object?>> get events => List.unmodifiable(_events);
  String begin() => newId();
  void record(
    String traceId,
    String operation,
    String phase,
    int elapsedMs, {
    int attempt = 0,
    int? status,
    String? code,
  }) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(traceId) ||
        !RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+$').hasMatch(operation) ||
        !RegExp(r'^[a-z_]{1,32}$').hasMatch(phase)) {
      return;
    }
    _events.add({
      'traceId': traceId,
      if (Zone.current[#alchemistTask] case final String taskId
          when RegExp(r'^[a-f0-9]{32}$').hasMatch(taskId))
        'taskId': taskId,
      'operation': operation,
      'phase': phase,
      'elapsedMs': elapsedMs,
      'attempt': attempt,
      'status': ?status,
      if (code != null && RegExp(r'^[A-Z0-9_]{1,80}$').hasMatch(code))
        'code': code,
    });
    if (_events.length > 200) _events.removeAt(0);
    notifyListeners();
  }
}
