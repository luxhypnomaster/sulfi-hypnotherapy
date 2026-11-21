enum VitrineSplashMode { fullCycle, betweenEntries }

/// Wire v1 proposal. Timer bounds approved; ratio/N ceilings are technical
/// safeguards, not a new owner-approved product policy (see reports/task20).
class VitrineConfig {
  const VitrineConfig({
    this.splashSeconds = 3,
    this.entrySeconds = 7,
    this.splashMode = VitrineSplashMode.fullCycle,
    this.highWeight = 1,
    this.normalWeight = 1,
    this.pinnedEveryNth = 3,
  });
  final int splashSeconds,
      entrySeconds,
      highWeight,
      normalWeight,
      pinnedEveryNth;
  final VitrineSplashMode splashMode;
  void validate() {
    if (splashSeconds < 1 ||
        splashSeconds > 60 ||
        entrySeconds < 1 ||
        entrySeconds > 60 ||
        highWeight < 1 ||
        highWeight > 100 ||
        normalWeight < 1 ||
        normalWeight > 100 ||
        pinnedEveryNth < 1 ||
        pinnedEveryNth > 1000) {
      throw const FormatException('Недопустимые параметры витрины');
    }
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'splashSeconds': splashSeconds,
    'entrySeconds': entrySeconds,
    'splashMode': splashMode.name,
    'highWeight': highWeight,
    'normalWeight': normalWeight,
    'pinnedEveryNth': pinnedEveryNth,
  };
  factory VitrineConfig.fromMap(Map m) {
    if (m['schemaVersion'] != 1) {
      throw const FormatException('UNSUPPORTED_VITRINE_CONFIG');
    }
    final v = VitrineConfig(
      splashSeconds: m['splashSeconds'] as int,
      entrySeconds: m['entrySeconds'] as int,
      splashMode: VitrineSplashMode.values.byName(m['splashMode'] as String),
      highWeight: m['highWeight'] as int,
      normalWeight: m['normalWeight'] as int,
      pinnedEveryNth: m['pinnedEveryNth'] as int,
    );
    v.validate();
    return v;
  }
}
