/// A single completed Pomodoro phase, recorded so the app can show focus /
/// break statistics over time (today / this week / this month / this year).
class PomodoroSession {
  /// One of [PomodoroProfile.phaseWork] / [phaseShort] / [phaseLong].
  final String phase;

  /// Duration of the phase that actually elapsed, in seconds.
  final int seconds;

  /// When the phase completed.
  final DateTime at;

  const PomodoroSession({
    required this.phase,
    required this.seconds,
    required this.at,
  });

  /// True for the focus (work) phase.
  bool get isFocus => phase == 'work';

  Map<String, dynamic> toJson() => {
    'phase': phase,
    'seconds': seconds,
    'at': at.toIso8601String(),
  };

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    return PomodoroSession(
      phase: (json['phase'] as String?) ?? 'work',
      seconds: (json['seconds'] as int?) ?? 0,
      at: at != null
          ? DateTime.parse(at)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Aggregated focus / break time for one reporting period.
class PomodoroStats {
  /// Total focused (work) seconds in the period.
  final int focusSeconds;

  /// Total break seconds (short + long) in the period.
  final int breakSeconds;

  const PomodoroStats({this.focusSeconds = 0, this.breakSeconds = 0});
}
