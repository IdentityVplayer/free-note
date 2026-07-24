import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/task_service.dart';
import 'package:free_note/utils/task_helpers.dart';

/// Reproduces the exact TaskPlanScreen._toggleDone flow (toggle a subtask,
/// then auto-complete the parent) to verify NO tasks are lost.
Future<List<Task>> _toggleSubtask(
  List<Task> tasks,
  String subId,
  String mainId,
) async {
  // Mirror _updateTask (in-memory replace) + recomputeMainDone + _persist.
  final flipped = tasks
      .map((t) => t.id == subId ? t.copyWith(done: true) : t)
      .toList();
  final recomputed = recomputeMainDone(flipped, mainId, true);
  await TaskService.instance.saveTasks(recomputed);
  return recomputed;
}

void main() {
  test('completing all subtasks keeps every task (no deletion)', () async {
    final dir = Directory.systemTemp.createTempSync('taskrepro');
    TaskService.instance.debugSetDir(dir);

    final m = Task(id: 'm', title: 'Main', createdAt: DateTime.now());
    final s1 = Task(
      id: 's1',
      title: 'Sub1',
      createdAt: DateTime.now(),
      parentId: 'm',
    );
    final s2 = Task(
      id: 's2',
      title: 'Sub2',
      createdAt: DateTime.now(),
      parentId: 'm',
    );
    var tasks = [m, s1, s2];
    await TaskService.instance.saveTasks(tasks);

    tasks = await _toggleSubtask(tasks, 's1', 'm');
    tasks = await _toggleSubtask(tasks, 's2', 'm');

    final loaded = await TaskService.instance.loadTasks();
    expect(loaded.length, 3, reason: 'all three tasks must remain');
    expect(
      loaded.firstWhere((t) => t.id == 'm').done,
      isTrue,
      reason: 'main auto-completed',
    );
    expect(
      loaded.where((t) => t.parentId == 'm').length,
      2,
      reason: 'both subtasks remain',
    );
  });
}
