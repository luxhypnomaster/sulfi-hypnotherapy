import 'dart:io';

import 'package:sulfi_hypnotherapy/services/recorder_service.dart';

class FakeCapture implements CaptureBackend {
  bool granted = true, fail = false;
  String? path;
  int starts = 0, pauses = 0, resumes = 0, cancels = 0;
  @override
  Future<bool> permission() async => granted;
  @override
  Future<void> start(String value) async {
    if (fail) throw StateError('busy mic');
    starts++;
    path = value;
    await File(value).writeAsBytes([1, 2, 3, 4]);
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Stream<double> get amplitude => const Stream.empty();
  @override
  Future<void> dispose() async {}
}
