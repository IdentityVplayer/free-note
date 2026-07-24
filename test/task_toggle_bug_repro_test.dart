import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/task_service.dart';
import 'package:free_note/utils/task_helpers.dart';

/// Exact reproduction of the reported bug:
/// 1. Create main task + multiple subtasks
/// 2. Save to file
/// 3. Reload (simulate returning to the screen)
/// 4. Toggle ONE subtask done (not all)
/// 5. Verify the file still has all tasks (no deletion/clearing)
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('task_bug_repro');
    TaskService.instance.debugSetDir(dir);
  });

  tearDown(() {
    TaskService.instance.debugSetDir(Directory.systemTemp);
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Directly read the JSON file to detect file-level clearing.
  List<dynamic> readFileRaw() {
    final f = File('${dir.path}/tasks.json');
    if (!f.existsSync()) return [];
    return jsonDecode(f.readAsStringSync()) as List<dynamic>;
  }

  test(
    'toggle ONE subtask done — all tasks remain (the reported "全部删除" bug)',
    () async {
      final m = Task(id: 'm1', title: 'Main', createdAt: DateTime.now());
      final s1 = Task(
        id: 's1',
        title: 'Sub1',
        createdAt: DateTime.now(),
        parentId: 'm1',
      );
      final s2 = Task(
        id: 's2',
        title: 'Sub2',
        createdAt: DateTime.now(),
        parentId: 'm1',
      );
      final s3 = Task(
        id: 's3',
        title: 'Sub3',
        createdAt: DateTime.now(),
        parentId: 'm1',
      );

      // Step 1: Save initial tasks (simulating creating main + 3 subs).
      await TaskService.instance.saveTasks([m, s1, s2, s3]);
      var raw = readFileRaw();
      expect(raw.length, 4);

      // Step 2: Reload (simulate what _load does in TaskPlanScreen).
      var tasks = await TaskService.instance.loadTasks();
      expect(tasks.length, 4);

      // Step 3: Toggle ONE subtask done — mirror _toggleDone + _updateTask.
      // This simulates toggling s1 done with autoCompleteMainTasks = true.
      final sub1 = tasks.firstWhere((t) => t.id == 's1');
      var idx = tasks.indexWhere((t) => t.id == sub1.id);
      expect(idx, greaterThanOrEqualTo(0));
      tasks[idx] = sub1.copyWith(done: true);

      // recomputeMainDone (only matters if autoCompleteMainTasks is on).
      final recomputed = recomputeMainDone(tasks, 'm1', true);
      expect(recomputed.length, tasks.length); // same length
      expect(recomputed.where((t) => t.done).length, 1); // only s1 is done

      // Persist the result.
      await TaskService.instance.saveTasks(recomputed);

      // Step 4: Verify file still has all 4 tasks.
      raw = readFileRaw();
      expect(raw.length, 4, reason: '必须保留全部4个任务！完成了1个子任务不应清空文件');
      expect(raw.map((j) => j['id'] as String).toSet(), {
        'm1',
        's1',
        's2',
        's3',
      }, reason: '所有任务ID必须都在文件中');

      // Step 5: Simulate a second reload and re-toggle (another subtask).
      tasks = await TaskService.instance.loadTasks();
      expect(tasks.length, 4);

      // Toggle a different subtask.
      final sub2 = tasks.firstWhere((t) => t.id == 's2');
      idx = tasks.indexWhere((t) => t.id == sub2.id);
      tasks[idx] = sub2.copyWith(done: true);
      final recomputed2 = recomputeMainDone(tasks, 'm1', true);
      await TaskService.instance.saveTasks(recomputed2);

      raw = readFileRaw();
      expect(raw.length, 4, reason: '完成第二个子任务后必须仍然保留全部4个任务');
    },
  );

  test('_updateTask fire-and-forget does not race with _toggleDone', () async {
    // Scenario: _updateTask (called by _toggleDone) persists without await,
    // while _toggleDone modifies the list. Simulate this exact pattern.
    final m = Task(id: 'mm', title: 'M', createdAt: DateTime.now());
    final s = Task(
      id: 'ss',
      title: 'S',
      createdAt: DateTime.now(),
      parentId: 'mm',
    );
    await TaskService.instance.saveTasks([m, s]);

    var tasks = await TaskService.instance.loadTasks();

    // _toggleDone equivalent:
    // 1. _updateTask — fire-and-forget persist
    var sub = tasks.firstWhere((t) => t.id == 'ss');
    var i = tasks.indexWhere((t) => t.id == 'ss');
    tasks[i] = sub.copyWith(done: true);
    // Fire-and-forget persist (not awaited):
    TaskService.instance.saveTasks(tasks);

    // 2. Immediately continue with recomputeMainDone (as _toggleDone does).
    final recomputed = recomputeMainDone(tasks, 'mm', true);
    expect(recomputed.length, 2);

    // 3. Await persist (the second persist in _toggleDone).
    await TaskService.instance.saveTasks(recomputed);

    // 4. Wait a tick for the fire-and-forget to finish.
    await Future.delayed(const Duration(milliseconds: 50));

    final loaded = await TaskService.instance.loadTasks();
    expect(
      loaded.length,
      2,
      reason: '即使 _updateTask fire-and-forget persist 后立即修改列表，也不应丢失任务',
    );
  });
}
