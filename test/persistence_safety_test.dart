import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/pomodoro_profile.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/pomodoro_service.dart';
import 'package:free_note/services/task_service.dart';
import 'package:path/path.dart' as p;

/// Regression tests for the "data might get cleared" bug: persistence now uses
/// atomic writes (temp file + rename) with a `.bak` backup, and reads fall back
/// to the backup when the primary file is corrupt — so a crash mid-write can
/// never silently drop the user's tasks / pomodoro data.
void main() {
  group('TaskService persistence safety', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('tasks_safety');
      TaskService.instance.debugSetDir(dir);
    });

    tearDown(() {
      TaskService.instance.debugSetDir(Directory.systemTemp);
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'saveTasks writes a .bak and recovers from it when primary is corrupt',
      () async {
        final tasks = [
          Task(id: '1', title: 'A', createdAt: DateTime.now()),
          Task(id: '2', title: 'B', createdAt: DateTime.now()),
        ];
        await TaskService.instance.saveTasks(tasks);
        final primary = File(p.join(dir.path, 'tasks.json'));
        final bak = File('${primary.path}.bak');
        expect(primary.existsSync(), isTrue);
        expect(bak.existsSync(), isTrue, reason: 'a backup must be kept');

        // Simulate a crash that truncated / corrupted the live file.
        primary.writeAsStringSync('{ this is not valid json ');

        final recovered = await TaskService.instance.loadTasks();
        expect(recovered.length, tasks.length);
        expect(recovered.map((t) => t.id).toSet(), {'1', '2'});
      },
    );

    test(
      'loadTasks is safe (empty, not crash) when both files are corrupt',
      () async {
        final primary = File(p.join(dir.path, 'tasks.json'));
        primary.writeAsStringSync('garbage');
        final bak = File('${primary.path}.bak');
        bak.writeAsStringSync('also garbage');
        final loaded = await TaskService.instance.loadTasks();
        expect(loaded, isEmpty);
      },
    );
  });

  group('PomodoroService persistence safety', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('pomo_safety');
      PomodoroService.instance.debugSetDir(dir);
    });

    tearDown(() {
      PomodoroService.instance.debugSetDir(Directory.systemTemp);
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
      'profiles persist with backup and recover when primary is corrupt',
      () async {
        await PomodoroService.instance.load();
        final profile = PomodoroProfile(
          id: 'x',
          name: 'x',
          workMinutes: 30,
          shortBreakMinutes: 5,
          longBreakMinutes: 15,
          longBreakEvery: 4,
        );
        await PomodoroService.instance.saveProfiles([profile], 'x');
        final primary = File(p.join(dir.path, 'pomodoro_profiles.json'));
        final bak = File('${primary.path}.bak');
        expect(primary.existsSync(), isTrue);
        expect(bak.existsSync(), isTrue, reason: 'a backup must be kept');

        primary.writeAsStringSync('not json at all');
        final loaded = await PomodoroService.instance.load();
        expect(loaded.map((e) => e.id).contains('x'), isTrue);
      },
    );

    test(
      'history persists with backup and recovers when primary is corrupt',
      () async {
        await PomodoroService.instance.load();
        await PomodoroService.instance.recordSession(
          PomodoroProfile.phaseWork,
          1500,
        );
        final primary = File(p.join(dir.path, 'pomodoro_history.json'));
        final bak = File('${primary.path}.bak');
        expect(primary.existsSync(), isTrue);
        expect(bak.existsSync(), isTrue, reason: 'a backup must be kept');

        primary.writeAsStringSync('corrupted');
        await PomodoroService.instance.load();
        final stats = PomodoroService.instance.stats();
        expect(stats['today']!.focusSeconds, 1500);
      },
    );
  });
}
