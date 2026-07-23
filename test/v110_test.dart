import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/pomodoro_profile.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/pomodoro_service.dart';
import 'package:free_note/services/task_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('v1.11.0 — Task Planning', () {
    test('Task round-trips through JSON (incl. due/priority/link)', () {
      final due = DateTime(2026, 8, 1, 9, 30);
      final task = Task(
        id: 't1',
        title: 'Write report',
        done: false,
        createdAt: DateTime(2026, 7, 1),
        dueDate: due,
        priority: Task.priorityHigh,
        noteId: 'n9',
        noteTitle: 'Notes for report',
      );
      final json = task.toJson();
      final back = Task.fromJson(json);
      expect(back.id, 't1');
      expect(back.title, 'Write report');
      expect(back.done, isFalse);
      expect(back.dueDate, due);
      expect(back.priority, Task.priorityHigh);
      expect(back.noteId, 'n9');
      expect(back.noteTitle, 'Notes for report');
    });

    test('Task.fromJson falls back to defaults for bad data', () {
      final back = Task.fromJson({
        'id': 'x',
        'title': 't',
        'done': 'not-bool',
        'priority': 'weird',
      });
      expect(back.done, isFalse);
      expect(back.priority, Task.priorityNormal);
      expect(back.dueDate, isNull);
    });

    test('Task.copyWith only changes the given fields', () {
      final base = Task(
        id: 'a',
        title: 'A',
        createdAt: DateTime(2026, 1, 1),
        priority: Task.priorityLow,
      );
      final updated = base.copyWith(done: true, priority: Task.priorityHigh);
      expect(updated.done, isTrue);
      expect(updated.priority, Task.priorityHigh);
      expect(updated.title, 'A');
      expect(updated.id, 'a');
    });

    test('compareForDisplay: open before done, high priority first', () {
      final open = Task(
        id: '1',
        title: 'o',
        createdAt: DateTime(2026, 1, 1),
        priority: Task.priorityLow,
      );
      final done = open.copyWith(done: true);
      expect(Task.compareForDisplay(open, done), lessThan(0));

      final high = Task(
        id: '2',
        title: 'h',
        createdAt: DateTime(2026, 1, 2),
        priority: Task.priorityHigh,
      );
      final low = Task(
        id: '3',
        title: 'l',
        createdAt: DateTime(2026, 1, 3),
        priority: Task.priorityLow,
      );
      expect(Task.compareForDisplay(high, low), lessThan(0));
    });

    test('TaskService save+load round-trips in an isolated dir', () async {
      final dir = Directory.systemTemp.createTempSync('tasks_test');
      TaskService.instance.debugSetDir(dir);
      final tasks = [
        Task(
          id: '1',
          title: 'Alpha',
          createdAt: DateTime(2026, 1, 1),
          priority: Task.priorityHigh,
        ),
        Task(
          id: '2',
          title: 'Beta',
          createdAt: DateTime(2026, 1, 2),
          done: true,
        ),
      ];
      await TaskService.instance.saveTasks(tasks);
      final loaded = await TaskService.instance.loadTasks();
      expect(loaded.length, 2);
      // Default sort: open (Alpha) before done (Beta).
      expect(loaded.first.id, '1');
      expect(loaded.last.done, isTrue);
    });
  });

  group('v1.11.0 — Pomodoro Timer', () {
    test('PomodoroProfile defaults and secondsForPhase', () {
      const cfg = PomodoroProfile(id: 'x', name: 'x');
      expect(cfg.workMinutes, 25);
      expect(cfg.shortBreakMinutes, 5);
      expect(cfg.longBreakMinutes, 15);
      expect(cfg.longBreakEvery, 4);
      expect(cfg.longBreakEnabled, isTrue);
      expect(cfg.secondsForPhase(PomodoroProfile.phaseWork), 25 * 60);
      expect(cfg.secondsForPhase(PomodoroProfile.phaseShort), 5 * 60);
      expect(cfg.secondsForPhase(PomodoroProfile.phaseLong), 15 * 60);
    });

    test('PomodoroProfile.fromJson clamps invalid values', () {
      final cfg = PomodoroProfile.fromJson({
        'id': 'x',
        'name': 'x',
        'workMinutes': -5,
        'shortBreakMinutes': 0,
        'longBreakMinutes': 'bad',
        'longBreakEvery': 3,
      });
      expect(cfg.workMinutes, 25);
      expect(cfg.shortBreakMinutes, 5);
      expect(cfg.longBreakMinutes, 15);
      expect(cfg.longBreakEvery, 3);
      expect(cfg.longBreakEnabled, isTrue);
    });

    test(
      'PomodoroService save+load round-trips profiles in an isolated dir',
      () async {
        final dir = Directory.systemTemp.createTempSync('pomo_test');
        PomodoroService.instance.debugSetDir(dir);
        final a = PomodoroProfile(
          id: 'a',
          name: 'Work',
          workMinutes: 30,
          shortBreakMinutes: 7,
          longBreakMinutes: 20,
          longBreakEvery: 3,
        );
        final b = PomodoroProfile(
          id: 'b',
          name: 'Deep',
          longBreakEnabled: false,
        );
        await PomodoroService.instance.saveProfiles([a, b], 'b');
        final loaded = await PomodoroService.instance.load();
        expect(loaded.length, 2);
        expect(PomodoroService.instance.active.id, 'b');
        final aLoaded = loaded.firstWhere((p) => p.id == 'a');
        expect(aLoaded.workMinutes, 30);
        expect(aLoaded.shortBreakMinutes, 7);
        expect(aLoaded.longBreakMinutes, 20);
        expect(aLoaded.longBreakEvery, 3);
        expect(loaded.firstWhere((p) => p.id == 'b').longBreakEnabled, isFalse);
      },
    );

    test(
      'PomodoroService migrates legacy pomodoro.json to a default profile',
      () async {
        final dir = Directory.systemTemp.createTempSync('pomo_mig');
        PomodoroService.instance.debugSetDir(dir);
        final legacy = File(p.join(dir.path, 'pomodoro.json'));
        legacy.writeAsStringSync(
          jsonEncode({
            'workMinutes': 40,
            'shortBreakMinutes': 8,
            'longBreakMinutes': 25,
            'longBreakEvery': 2,
          }),
        );
        final loaded = await PomodoroService.instance.load();
        expect(loaded.length, 1);
        expect(loaded.first.workMinutes, 40);
        expect(loaded.first.id, PomodoroService.defaultId);
      },
    );

    test('nextPomodoroPhase respects longBreakEnabled', () {
      final profile = PomodoroProfile(
        id: 'p',
        name: 'p',
        longBreakEvery: 4,
        longBreakEnabled: true,
      );
      // Work #4 (longBreakEvery=4, enabled) -> long break.
      expect(
        nextPomodoroPhase(profile, PomodoroProfile.phaseWork, 4),
        PomodoroProfile.phaseLong,
      );
      // Disabled -> always short break.
      final disabled = profile.copyWith(longBreakEnabled: false);
      expect(
        nextPomodoroPhase(disabled, PomodoroProfile.phaseWork, 4),
        PomodoroProfile.phaseShort,
      );
      // Work #3 -> short break.
      expect(
        nextPomodoroPhase(profile, PomodoroProfile.phaseWork, 3),
        PomodoroProfile.phaseShort,
      );
      // Any break -> work.
      expect(
        nextPomodoroPhase(profile, PomodoroProfile.phaseShort, 1),
        PomodoroProfile.phaseWork,
      );
    });
  });
}
