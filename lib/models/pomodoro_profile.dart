/// A named Pomodoro preset.
///
/// The app supports multiple profiles so the user can keep different rhythms
/// (e.g. 25/5, 50/10, 90/20) and switch between them. One profile is active
/// at a time and drives the timer. Each profile can carry its own background
/// image and an independent long-break toggle.
class PomodoroProfile {
  final String id;
  final String name;

  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  /// After this many completed work sessions, take a long break instead of a
  /// short one (the classic "4 pomodoros → long break" rhythm).
  final int longBreakEvery;

  /// When false, the timer never takes a long break (always short).
  final bool longBreakEnabled;

  /// Absolute path to a user-picked background image, or null for none.
  final String? backgroundPath;

  const PomodoroProfile({
    required this.id,
    required this.name,
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
    this.longBreakEnabled = true,
    this.backgroundPath,
  });

  static const String phaseWork = 'work';
  static const String phaseShort = 'short';
  static const String phaseLong = 'long';

  /// Duration (in seconds) for [phase].
  int secondsForPhase(String phase) {
    switch (phase) {
      case phaseWork:
        return workMinutes * 60;
      case phaseShort:
        return shortBreakMinutes * 60;
      case phaseLong:
        return longBreakMinutes * 60;
      default:
        return workMinutes * 60;
    }
  }

  PomodoroProfile copyWith({
    String? id,
    String? name,
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakEvery,
    bool? longBreakEnabled,
    String? backgroundPath,
    bool clearBackground = false,
  }) {
    return PomodoroProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      longBreakEvery: longBreakEvery ?? this.longBreakEvery,
      longBreakEnabled: longBreakEnabled ?? this.longBreakEnabled,
      backgroundPath: clearBackground
          ? null
          : (backgroundPath ?? this.backgroundPath),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'workMinutes': workMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'longBreakEvery': longBreakEvery,
    'longBreakEnabled': longBreakEnabled,
    'backgroundPath': backgroundPath,
  };

  factory PomodoroProfile.fromJson(Map<String, dynamic> json) {
    int clamp(v, int d) => (v is int && v > 0) ? v : d;
    return PomodoroProfile(
      id:
          (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Pomodoro',
      workMinutes: clamp(json['workMinutes'], 25),
      shortBreakMinutes: clamp(json['shortBreakMinutes'], 5),
      longBreakMinutes: clamp(json['longBreakMinutes'], 15),
      longBreakEvery: clamp(json['longBreakEvery'], 4),
      longBreakEnabled: json['longBreakEnabled'] as bool? ?? true,
      backgroundPath: json['backgroundPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          workMinutes == other.workMinutes &&
          shortBreakMinutes == other.shortBreakMinutes &&
          longBreakMinutes == other.longBreakMinutes &&
          longBreakEvery == other.longBreakEvery &&
          longBreakEnabled == other.longBreakEnabled &&
          backgroundPath == other.backgroundPath;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    workMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    longBreakEvery,
    longBreakEnabled,
    backgroundPath,
  );
}
