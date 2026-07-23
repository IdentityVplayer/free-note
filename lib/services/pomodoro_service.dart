import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/pomodoro_profile.dart';
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

  /// Load the saved profiles (falls back to a single default when none /
  /// corrupt). Migrates the legacy single `pomodoro.json` config into a
  /// default profile on first run.
  Future<List<PomodoroProfile>> load() async {
    if (_overrideDir == null) {
      await StorageService.instance.migrateFileFromPrivate('pomodoro.json');
    }
    final dir = await _dir;
    final file = File(p.join(dir.path, 'pomodoro_profiles.json'));
    if (!file.existsSync()) {
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
      return _profiles;
    }
    try {
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final list = (map['profiles'] as List? ?? [])
          .map((e) => PomodoroProfile.fromJson(e))
          .toList();
      _profiles = list.isNotEmpty ? list : [_defaultProfile()];
      _activeId = map['activeId'] as String? ?? _profiles.first.id;
    } catch (_) {
      _profiles = [_defaultProfile()];
      _activeId = _profiles.first.id;
    }
    return _profiles;
  }

  Future<void> _persist() async {
    final dir = await _dir;
    final file = File(p.join(dir.path, 'pomodoro_profiles.json'));
    try {
      file.writeAsStringSync(
        jsonEncode({
          'activeId': _activeId,
          'profiles': _profiles.map((p) => p.toJson()).toList(),
        }),
      );
    } catch (_) {
      // best-effort
    }
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
