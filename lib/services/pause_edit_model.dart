import 'package:flutter/foundation.dart';

// An editor-local value: database writes happen only via Apply.
class PauseEditModel extends ChangeNotifier {
  PauseEditModel(int seconds)
    : _minutes = seconds ~/ 60,
      _seconds = seconds % 60;
  int _minutes, _seconds;
  int get minutes => _minutes;
  int get seconds => _seconds;
  int get totalSeconds => _minutes * 60 + _seconds;
  String get label =>
      '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}';
  bool turnMinutes(int ticks) {
    final next = (_minutes + ticks).clamp(0, 99);
    if (next == _minutes) return false;
    _minutes = next;
    notifyListeners();
    return true;
  }

  bool turnSeconds(int ticks) {
    final next = ((_seconds ~/ 5 + ticks) % 12) * 5;
    if (next == _seconds) return false;
    _seconds = next;
    notifyListeners();
    return true;
  }

  void manual(int minutes, int seconds) {
    if (minutes < 0 || minutes > 99 || seconds < 0 || seconds > 59) {
      throw const FormatException('Минуты 0–99, секунды 0–59.');
    }
    _minutes = minutes;
    _seconds = ((seconds / 5).round() * 5).clamp(0, 55);
    notifyListeners();
  }

  void reset() {
    _minutes = 0;
    _seconds = 0;
    notifyListeners();
  }
}
