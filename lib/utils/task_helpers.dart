/// Pure, testable helpers for hierarchical tasks (main + subtasks) and the
/// reminder/repeat feature.
library;

import 'package:free_note/models/task.dart';

/// Return a copy of [tasks] where the main task [mainId] is marked done when
/// [auto] is true AND every one of its subtasks is done. No-op when [auto] is
/// false, the main task is missing, or it has no subtasks.
List<Task> recomputeMainDone(List<Task> tasks, String mainId, bool auto) {
  if (!auto) return tasks;
  final idx = tasks.indexWhere((t) => t.id == mainId && t.parentId == null);
  if (idx < 0) return tasks;
  final main = tasks[idx];
  final subs = tasks.where((t) => t.parentId == mainId).toList();
  if (subs.isEmpty) return tasks;
  final allDone = subs.every((s) => s.done);
  if (allDone == main.done) return tasks;
  final updated = List<Task>.from(tasks);
  updated[idx] = main.copyWith(done: allDone);
  return updated;
}

/// The next occurrence of a repeating reminder, [every] [unit]s after [base].
DateTime nextRepeatDue(DateTime base, RepeatConfig r) {
  switch (r.unit) {
    case 'hour':
      return base.add(Duration(hours: r.every));
    case 'day':
      return base.add(Duration(days: r.every));
    case 'week':
      return base.add(Duration(days: 7 * r.every));
    case 'month':
      return DateTime(
        base.year,
        base.month + r.every,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    case 'year':
      return DateTime(
        base.year + r.every,
        base.month,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    default:
      return base.add(Duration(days: r.every));
  }
}

/// Build a fresh, all-undone copy of a main task and its subtasks, with new
/// ids (subtasks re-parented to the new main id). Used when a repeating task
/// comes due — the original keeps repeating while a clean instance appears.
(String, Task, List<Task>) freshTaskCopy(Task main, List<Task> subs) {
  final newMainId = '${DateTime.now().microsecondsSinceEpoch}_${main.id}';
  final freshMain = main.copyWith(id: newMainId, done: false, parentId: null);
  final freshSubs = subs
      .map(
        (s) => s.copyWith(
          id: '${newMainId}_${s.id}',
          parentId: newMainId,
          done: false,
        ),
      )
      .toList();
  return (newMainId, freshMain, freshSubs);
}
