import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'storage_service.dart';

/// Tunable durations for the Pomodoro timer.
class PomodoroConfig {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  /// After this many completed work sessions, take a long break instead of a
  /// short one (the classic "4 pomodoros → long break" rhythm).
  final int longBreakEvery;

  const PomodoroConfig({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakEvery = 4,
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

  PomodoroConfig copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakEvery,
  }) {
    return PomodoroConfig(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      longBreakEvery: longBreakEvery ?? this.longBreakEvery,
    );
  }

  Map<String, dynamic> toJson() => {
    'workMinutes': workMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'longBreakEvery': longBreakEvery,
  };

  factory PomodoroConfig.fromJson(Map<String, dynamic> json) {
    int clamp(v, int d) => (v is int && v > 0) ? v : d;
    return PomodoroConfig(
      workMinutes: clamp(json['workMinutes'], 25),
      shortBreakMinutes: clamp(json['shortBreakMinutes'], 5),
      longBreakMinutes: clamp(json['longBreakMinutes'], 15),
      longBreakEvery: clamp(json['longBreakEvery'], 4),
    );
  }
}

/// Determine the next phase after [current] finishes.
///
/// When a work session completes, [completedWork] is the count *including* the
/// one that just finished, so a long break is taken every [longBreakEvery]
/// completed work sessions.
String nextPomodoroPhase(
  String current,
  int completedWork,
  int longBreakEvery,
) {
  if (current == PomodoroConfig.phaseWork) {
    final takeLong = longBreakEvery > 0 && completedWork % longBreakEvery == 0;
    return takeLong ? PomodoroConfig.phaseLong : PomodoroConfig.phaseShort;
  }
  return PomodoroConfig.phaseWork;
}

/// Persists the Pomodoro configuration (durations / rhythm).
class PomodoroService {
  static final PomodoroService instance = PomodoroService._();
  PomodoroService._();

  PomodoroConfig _config = const PomodoroConfig();

  /// Test hook for an alternate storage directory.
  Directory? _overrideDir;
  void debugSetDir(Directory dir) => _overrideDir = dir;

  PomodoroConfig get config => _config;

  Future<Directory> get _dir async {
    if (_overrideDir != null) return _overrideDir!;
    return StorageService.instance.configDir;
  }

  /// Load the saved config (falls back to defaults when none / corrupt).
  Future<PomodoroConfig> load() async {
    // Migration only applies to the real config location, not an isolated
    // (test) override dir — which has no legacy private-dir files to move.
    if (_overrideDir == null) {
      await StorageService.instance.migrateFileFromPrivate('pomodoro.json');
    }
    final file = File(p.join((await _dir).path, 'pomodoro.json'));
    if (!file.existsSync()) {
      _config = const PomodoroConfig();
      return _config;
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _config = PomodoroConfig.fromJson(json);
    } catch (_) {
      _config = const PomodoroConfig();
    }
    return _config;
  }

  Future<void> save(PomodoroConfig config) async {
    _config = config;
    final file = File(p.join((await _dir).path, 'pomodoro.json'));
    try {
      file.writeAsStringSync(jsonEncode(config.toJson()));
    } catch (_) {
      // best-effort
    }
  }
}
