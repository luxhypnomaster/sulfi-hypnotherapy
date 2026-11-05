import 'dart:async';

import 'package:sulfi_hypnotherapy/services/session_transport.dart';

class TestTransport implements SessionTransport {
  final controller = StreamController<String>.broadcast();
  int plays = 0, stops = 0, pauses = 0;
  final List<String> loaded = [];
  Completer<void>? pendingLoad;
  @override
  Duration position = Duration.zero;
  @override
  bool completed = false;
  @override
  Stream<String> get events => controller.stream;
  @override
  Future<void> load(String path) async {
    loaded.add(path);
    position = Duration.zero;
    completed = false;
    await pendingLoad?.future;
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    completed = false;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (pendingLoad != null && !pendingLoad!.isCompleted) {
      pendingLoad!.completeError(StateError('load cancelled'));
    }
  }

  @override
  Future<void> close() => controller.close();
}
