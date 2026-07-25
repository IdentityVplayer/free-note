import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/services/task_service.dart';

/// Regression test for the v1.13.8 bug: when `saveTasks` is called rapidly
/// while the in-memory list is being mutated (e.g. toggling a task while the
/// previous save is still in-flight), tasks must not be silently dropped.
/// After v1.15.4 the hierarchical subtask model was removed; this test now
/// verifies the same safety property for plain top-level tasks.
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

  test('toggle ONE task done — all tasks remain after save+reload', () async {
    final t1 = Task(id: 't1', title: 'A', createdAt: DateTime.now());
    final t2 = Task(id: 't2', title: 'B', createdAt: DateTime.now());
    final t3 = Task(id: 't3', title: 'C', createdAt: DateTime.now());

    await TaskService.instance.saveTasks([t1, t2, t3]);
    var raw = readFileRaw();
    expect(raw.length, 3);

    var tasks = await TaskService.instance.loadTasks();
    expect(tasks.length, 3);

    // Toggle t2 done, save, verify nothing is lost.
    final t2Loaded = tasks.firstWhere((t) => t.id == 't2');
    final idx = tasks.indexWhere((t) => t.id == t2Loaded.id);
    tasks[idx] = t2Loaded.copyWith(done: true);
    await TaskService.instance.saveTasks(tasks);

    raw = readFileRaw();
    expect(raw.length, 3, reason: '完成 1 个任务不应清空文件');
    expect(raw.map((j) => j['id'] as String).toSet(), {'t1', 't2', 't3'});
  });

  test('_persist does not race with concurrent saves (no data loss)', () async {
    final m = Task(id: 'mm', title: 'M', createdAt: DateTime.now());
    final s = Task(id: 'ss', title: 'S', createdAt: DateTime.now());
    await TaskService.instance.saveTasks([m, s]);

    var tasks = await TaskService.instance.loadTasks();

    // Toggle done.
    var sub = tasks.firstWhere((t) => t.id == 'ss');
    var i = tasks.indexWhere((t) => t.id == sub.id);
    tasks[i] = sub.copyWith(done: true);
    await TaskService.instance.saveTasks(tasks);

    await Future.delayed(const Duration(milliseconds: 50));

    final loaded = await TaskService.instance.loadTasks();
    expect(loaded.length, 2, reason: '即使连续 save 也不应丢失任务');
  });
}
