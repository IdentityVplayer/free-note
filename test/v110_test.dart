import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/task_service.dart';
import 'package:free_note/services/pomodoro_service.dart';

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
    test('PomodoroConfig defaults and secondsForPhase', () {
      const cfg = PomodoroConfig();
      expect(cfg.workMinutes, 25);
      expect(cfg.shortBreakMinutes, 5);
      expect(cfg.longBreakMinutes, 15);
      expect(cfg.longBreakEvery, 4);
      expect(cfg.secondsForPhase(PomodoroConfig.phaseWork), 25 * 60);
      expect(cfg.secondsForPhase(PomodoroConfig.phaseShort), 5 * 60);
      expect(cfg.secondsForPhase(PomodoroConfig.phaseLong), 15 * 60);
    });

    test('PomodoroConfig.fromJson clamps invalid values', () {
      final cfg = PomodoroConfig.fromJson({
        'workMinutes': -5,
        'shortBreakMinutes': 0,
        'longBreakMinutes': 'bad',
        'longBreakEvery': 3,
      });
      expect(cfg.workMinutes, 25);
      expect(cfg.shortBreakMinutes, 5);
      expect(cfg.longBreakMinutes, 15);
      expect(cfg.longBreakEvery, 3);
    });

    test('PomodoroService save+load round-trips in an isolated dir', () async {
      final dir = Directory.systemTemp.createTempSync('pomo_test');
      PomodoroService.instance.debugSetDir(dir);
      final cfg = PomodoroConfig(
        workMinutes: 30,
        shortBreakMinutes: 7,
        longBreakMinutes: 20,
        longBreakEvery: 3,
      );
      await PomodoroService.instance.save(cfg);
      final loaded = await PomodoroService.instance.load();
      expect(loaded.workMinutes, 30);
      expect(loaded.shortBreakMinutes, 7);
      expect(loaded.longBreakMinutes, 20);
      expect(loaded.longBreakEvery, 3);
    });

    test('nextPomodoroPhase: long break every N, breaks -> work', () {
      // Work #4 (longBreakEvery=4) -> long break.
      expect(
        nextPomodoroPhase(PomodoroConfig.phaseWork, 4, 4),
        PomodoroConfig.phaseLong,
      );
      // Work #3 -> short break.
      expect(
        nextPomodoroPhase(PomodoroConfig.phaseWork, 3, 4),
        PomodoroConfig.phaseShort,
      );
      // Any break -> work.
      expect(
        nextPomodoroPhase(PomodoroConfig.phaseShort, 1, 4),
        PomodoroConfig.phaseWork,
      );
    });
  });
}
