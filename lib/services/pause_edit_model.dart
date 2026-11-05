import 'package:flutter/foundation.dart';

// An editor-local value: database writes happen only via Apply.
class PauseEditModel extends ChangeNotifier {
  PauseEditModel(int seconds, {this.maxSeconds = 5995})
    : _totalSeconds = seconds {
    if (seconds < 0 || seconds > maxSeconds) {
      throw const FormatException('Длительность паузы вне допустимых границ.');
    }
  }
  // The existing validated pre-track limit is 99:55. Do not round old values.
  final int maxSeconds;
  int _totalSeconds;
  int get minutes => _totalSeconds ~/ 60;
  int get seconds => _totalSeconds % 60;
  int get totalSeconds => _totalSeconds;
  String get label =>
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  bool turnMinutes(int ticks) {
    // Clamp whole minutes while preserving the seconds component at both ends.
    final next = (minutes + ticks).clamp(0, (maxSeconds - seconds) ~/ 60);
    return _set(next * 60 + seconds);
  }

  bool turnSeconds(int ticks) {
    return _set((_totalSeconds + ticks).clamp(0, maxSeconds));
  }

  bool _set(int value) {
    if (value == _totalSeconds) return false;
    _totalSeconds = value;
    notifyListeners();
    return true;
  }

  void manual(int minutes, int seconds) {
    if (minutes < 0 ||
        seconds < 0 ||
        seconds > 59 ||
        minutes * 60 + seconds > maxSeconds) {
      throw const FormatException('Длительность паузы вне допустимых границ.');
    }
    _set(minutes * 60 + seconds);
  }

  void reset() {
    _set(0);
  }
}
