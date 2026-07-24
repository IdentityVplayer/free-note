import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/pomodoro_profile.dart';
import '../models/pomodoro_session.dart';
import 'storage_service.dart';

/// Determine the next phase after [current] finishes.
///
/// When a work session completes, [completedWork] is the count *including* the
/// one that just finished, so a long break is taken every [profile.longBreakEvery]
/// completed work sessions — but only if [profile.longBreakEnabled] is true.
String nextPomodoroPhase(
  PomodoroProfile profile,
  String current,
  int completedWork,
) {
  if (current == PomodoroProfile.phaseWork) {
    final takeLong =
        profile.longBreakEnabled &&
        profile.longBreakEvery > 0 &&
        completedWork % profile.longBreakEvery == 0;
    return takeLong ? PomodoroProfile.phaseLong : PomodoroProfile.phaseShort;
  }
  return PomodoroProfile.phaseWork;
}

/// Persists the list of Pomodoro profiles (presets) and which one is active.
class PomodoroService {
  static final PomodoroService instance = PomodoroService._();
  PomodoroService._();

  List<PomodoroProfile> _profiles = [];
  String? _activeId;

  /// Completed-phase log used for the focus / break statistics.
  List<PomodoroSession> _history = [];

  /// Test hook for an alternate storage directory.
  Directory? _overrideDir;
  void debugSetDir(Directory dir) => _overrideDir = dir;

  List<PomodoroProfile> get profiles =>
      List<PomodoroProfile>.from(_profiles, growable: false);

  PomodoroProfile get active {
    if (_profiles.isEmpty) _profiles = [_defaultProfile()];
    return _profiles.firstWhere(
      (p) => p.id == _activeId,
      orElse: () => _profiles.first,
    );
  }

  /// The reserved id of the auto-seeded default profile (whose name is shown
  /// localized in the UI).
  static const String defaultId = 'default';

  Future<Directory> get _dir async {
    if (_overrideDir != null) return _overrideDir!;
    return StorageService.instance.configDir;
  }

  /// Atomically write [name] inside the (possibly test-overridden) config dir,
  /// keeping a `.bak` backup so a crash mid-write or a full disk can be
  /// recovered on the next read (the temp file is fully written before the
  /// live file is replaced, so the data is never truncated in place).
  Future<void> _writeAtomic(String name, Object object) async {
    final dir = await _dir;
    final target = File(p.join(dir.path, name));
    final tmp = File('${target.path}.tmp');
    try {
      // Write the full payload to a temp file first, then copy the (still-good)
      // live file to `.bak` before replacing it — so a crash mid-replace never
      // leaves the live file truncated. The post-write copy guarantees a backup
      // exists after every successful save.
      tmp.writeAsStringSync(jsonEncode(object));
      if (tmp.existsSync()) {
        if (target.existsSync()) target.copySync('${target.path}.bak');
        target.writeAsStringSync(tmp.readAsStringSync());
        tmp.deleteSync();
        if (target.existsSync()) target.copySync('${target.path}.bak');
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Read [name]; on a parse error fall back to its `.bak` backup. Returns null
  /// when neither exists or both are unreadable.
  Future<dynamic> _readWithBackup(String name) async {
    final dir = await _dir;
    final target = File(p.join(dir.path, name));
    if (target.existsSync()) {
      try {
        return jsonDecode(target.readAsStringSync());
      } catch (_) {
        // fall through to backup
      }
    }
    final bak = File('${target.path}.bak');
    if (bak.existsSync()) {
      try {
        return jsonDecode(bak.readAsStringSync());
      } catch (_) {}
    }
    return null;
  }

  /// Load the saved profiles (falls back to a single default when none /
  /// corrupt). Migrates the legacy single `pomodoro.json` config into a
  /// default profile on first run.
  Future<List<PomodoroProfile>> load() async {
    if (_overrideDir == null) {
      await StorageService.instance.migrateFileFromPrivate('pomodoro.json');
    }
    final dir = await _dir;
    final raw = await _readWithBackup('pomodoro_profiles.json');
    if (raw == null) {
      final legacy = File(p.join(dir.path, 'pomodoro.json'));
      PomodoroProfile initial;
      if (legacy.existsSync()) {
        try {
          final json =
              jsonDecode(legacy.readAsStringSync()) as Map<String, dynamic>;
          int clamp(v, int d) => (v is int && v > 0) ? v : d;
          initial = PomodoroProfile(
            id: defaultId,
            name: defaultId,
            workMinutes: clamp(json['workMinutes'], 25),
            shortBreakMinutes: clamp(json['shortBreakMinutes'], 5),
            longBreakMinutes: clamp(json['longBreakMinutes'], 15),
            longBreakEvery: clamp(json['longBreakEvery'], 4),
          );
        } catch (_) {
          initial = _defaultProfile();
        }
      } else {
        initial = _defaultProfile();
      }
      _profiles = [initial];
      _activeId = initial.id;
      await _persist();
      await _loadHistory();
      return _profiles;
    }
    try {
      final map = raw as Map<String, dynamic>;
      final list = (map['profiles'] as List? ?? [])
          .map((e) => PomodoroProfile.fromJson(e))
          .toList();
      _profiles = list.isNotEmpty ? list : [_defaultProfile()];
      _activeId = map['activeId'] as String? ?? _profiles.first.id;
    } catch (_) {
      _profiles = [_defaultProfile()];
      _activeId = _profiles.first.id;
    }
    await _loadHistory();
    return _profiles;
  }

  /// Load the completed-phase history (best-effort; missing/corrupt → empty).
  /// Falls back to the `.bak` backup when the primary file is unreadable.
  Future<void> _loadHistory() async {
    final raw = await _readWithBackup('pomodoro_history.json');
    if (raw == null) {
      _history = [];
      return;
    }
    try {
      _history = (raw as List<dynamic>)
          .map((e) => PomodoroSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _history = [];
    }
  }

  Future<void> _persistHistory() async {
    // Keep the log bounded so it can't grow without limit.
    final trimmed = _history.length > 5000
        ? _history.sublist(_history.length - 5000)
        : _history;
    await _writeAtomic(
      'pomodoro_history.json',
      trimmed.map((s) => s.toJson()).toList(),
    );
  }

  /// Record a completed phase so it shows up in the statistics. [phase] is one
  /// of [PomodoroProfile.phaseWork] / [phaseShort] / [phaseLong]; [seconds] is
  /// the phase's duration.
  Future<void> recordSession(String phase, int seconds) async {
    if (seconds <= 0) return;
    _history.add(
      PomodoroSession(phase: phase, seconds: seconds, at: DateTime.now()),
    );
    await _persistHistory();
  }

  /// Aggregate focus (work) and break (short+long) seconds for four periods:
  /// today, this week (last 7 days), this month, and this year.
  Map<String, PomodoroStats> stats() {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    int todayFocus = 0, todayBreak = 0;
    int weekFocus = 0, weekBreak = 0;
    int monthFocus = 0, monthBreak = 0;
    int yearFocus = 0, yearBreak = 0;
    for (final s in _history) {
      final secs = s.seconds;
      final isFocus = s.isFocus;
      final f = isFocus ? secs : 0;
      final b = isFocus ? 0 : secs;
      if (_sameDay(s.at, now)) {
        todayFocus += f;
        todayBreak += b;
      }
      if (!s.at.isBefore(weekStart)) {
        weekFocus += f;
        weekBreak += b;
      }
      if (s.at.year == now.year && s.at.month == now.month) {
        monthFocus += f;
        monthBreak += b;
      }
      if (s.at.year == now.year) {
        yearFocus += f;
        yearBreak += b;
      }
    }
    return {
      'today': PomodoroStats(
        focusSeconds: todayFocus,
        breakSeconds: todayBreak,
      ),
      'week': PomodoroStats(focusSeconds: weekFocus, breakSeconds: weekBreak),
      'month': PomodoroStats(
        focusSeconds: monthFocus,
        breakSeconds: monthBreak,
      ),
      'year': PomodoroStats(focusSeconds: yearFocus, breakSeconds: yearBreak),
    };
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _persist() async {
    await _writeAtomic('pomodoro_profiles.json', {
      'activeId': _activeId,
      'profiles': _profiles.map((p) => p.toJson()).toList(),
    });
  }

  /// Replace the whole list and the active id (used by the profile manager).
  Future<void> saveProfiles(
    List<PomodoroProfile> profiles,
    String activeId,
  ) async {
    _profiles = List<PomodoroProfile>.from(profiles, growable: false);
    _activeId = activeId;
    await _persist();
  }

  Future<void> addProfile(PomodoroProfile profile) async {
    _profiles = [..._profiles, profile];
    await _persist();
  }

  Future<void> updateProfile(PomodoroProfile profile) async {
    _profiles = _profiles.map((p) => p.id == profile.id ? profile : p).toList();
    await _persist();
  }

  /// Remove a profile, keeping at least one. If the active one is removed the
  /// first remaining profile becomes active.
  Future<void> removeProfile(String id) async {
    if (_profiles.length <= 1) return;
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_activeId == id) _activeId = _profiles.first.id;
    await _persist();
  }

  Future<void> setActive(String id) async {
    if (_profiles.any((p) => p.id == id)) {
      _activeId = id;
      await _persist();
    }
  }

  PomodoroProfile _defaultProfile() => const PomodoroProfile(
    id: defaultId,
    name: defaultId,
    workMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    longBreakEvery: 4,
    longBreakEnabled: true,
  );
}
