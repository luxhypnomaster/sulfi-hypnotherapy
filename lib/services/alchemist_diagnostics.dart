import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/session_plan.dart';

/// Bounded RAM-only measurements; no URL, parameters, claims, title or token.
class AlchemistDiagnostics extends ChangeNotifier {
  AlchemistDiagnostics({
    bool enabled = false,
    Duration ttl = const Duration(minutes: 20),
  }) : _enabled = enabled && kDebugMode,
       // ignore: prefer_initializing_formals
       _ttl = ttl;
  bool _enabled;
  String _build = 'unknown';
  void setBuild(String value) {
    if (RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(value)) _build = value;
  }

  final Duration _ttl;
  final Stopwatch _age = Stopwatch()..start();
  bool get enabled => _enabled;
  void enable(bool value) {
    _enabled = value && kDebugMode;
    if (!_enabled) _events.clear();
    notifyListeners();
  }

  void stage(String code, {bool? ownerEqual}) {
    if (!RegExp(r'^[A-Z_]{1,64}$').hasMatch(code)) return;
    record(begin(), 'auth.queue', 'state', 0, code: code);
    if (enabled && _events.isNotEmpty && ownerEqual != null) {
      _events.last['ownerEqual'] = ownerEqual;
    }
  }

  String export() => jsonEncode({
    'kind': 'SULFI_QA_REDACTED_TRACE',
    'build': _build,
    'events': events
        .map((e) => Map<String, Object?>.from(e)..remove('taskId'))
        .toList(),
  });
  void _prune() {
    _events.removeWhere(
      (e) =>
          _age.elapsedMilliseconds - (e['atMs'] as int) > _ttl.inMilliseconds,
    );
  }

  static final instance = AlchemistDiagnostics();
  final List<Map<String, Object?>> _events = [];
  Map<String, Object?>? _measurement;
  Map<String, Object?>? get lastMeasurement =>
      _measurement == null ? null : Map.unmodifiable(_measurement!);
  List<Map<String, Object?>> get events {
    _prune();
    return List.unmodifiable(
      _events.map((e) => Map<String, Object?>.unmodifiable(e)),
    );
  }

  String begin() => newId();
  void record(
    String traceId,
    String operation,
    String phase,
    int elapsedMs, {
    int attempt = 0,
    int? status,
    int? confirmedBytes,
    String? code,
  }) {
    _prune();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(traceId) ||
        !RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+$').hasMatch(operation) ||
        !RegExp(r'^[a-z_]{1,32}$').hasMatch(phase)) {
      return;
    }
    final event = <String, Object?>{
      'atMs': _age.elapsedMilliseconds,
      'traceId': traceId,
      if (Zone.current[#alchemistTask] case final String taskId
          when RegExp(r'^[a-f0-9]{32}$').hasMatch(taskId))
        'taskId': taskId,
      'operation': operation,
      'phase': phase,
      'elapsedMs': elapsedMs,
      'attempt': attempt,
      'status': ?status,
      if (confirmedBytes != null && confirmedBytes >= 0)
        'confirmedBytes': confirmedBytes,
      if (code != null && RegExp(r'^[A-Z0-9_]{1,80}$').hasMatch(code))
        'code': code,
    };
    _measurement = event;
    if (enabled) _events.add(event);
    if (_events.length > 200) _events.removeAt(0);
    notifyListeners();
  }
}
