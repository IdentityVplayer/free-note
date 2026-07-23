import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/task.dart';
import '../utils/task_helpers.dart';
import 'storage_service.dart';

/// Persists the user's task list as a JSON file inside the app's config
/// directory (the selected repository's `.config`, falling back to the private
/// app dir), so tasks survive restarts without ever landing in the user-facing
/// notes folder.
class TaskService {
  static final TaskService instance = TaskService._();
  TaskService._();

  /// Test hook: when set, all reads/writes go here instead of the real
  /// config directory. null in production.
  Directory? _overrideDir;

  /// Override the storage directory (used by tests to avoid touching disk).
  void debugSetDir(Directory dir) => _overrideDir = dir;

  Future<Directory> get _dir async {
    if (_overrideDir != null) return _overrideDir!;
    return StorageService.instance.configDir;
  }

  /// Load all tasks, sorted for display (incomplete → priority → due → created).
  Future<List<Task>> loadTasks() async {
    // Migration only applies to the real config location, not an isolated
    // (test) override dir — which has no legacy private-dir files to move.
    if (_overrideDir == null) {
      await StorageService.instance.migrateFileFromPrivate('tasks.json');
    }
    final file = File(p.join((await _dir).path, 'tasks.json'));
    if (!file.existsSync()) return [];
    try {
      final raw = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      final tasks = raw
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      tasks.sort(Task.compareForDisplay);
      return tasks;
    } catch (_) {
      return [];
    }
  }

  /// Persist the full task list. Order is preserved as given.
  Future<void> saveTasks(List<Task> tasks) async {
    final file = File(p.join((await _dir).path, 'tasks.json'));
    try {
      file.writeAsStringSync(jsonEncode(tasks.map((t) => t.toJson()).toList()));
    } catch (_) {
      // Best-effort persistence: a failed write must not crash the UI.
    }
  }

  /// For every *main* task that has a repeat rule and whose reminder is due
  /// (<= now), spawn a fresh, all-undone copy (the new instance for this cycle)
  /// and advance the original's reminder to the next occurrence. Returns the
  /// number of fresh copies created (0 when nothing was due).
  Future<int> respawnDueRepeats() async {
    final tasks = await loadTasks();
    final now = DateTime.now();
    final updated = <Task>[];
    final fresh = <Task>[];

    for (final t in tasks) {
      if (t.parentId != null || t.repeat == null || t.reminder == null) {
        updated.add(t);
        continue;
      }
      if (t.reminder!.isAfter(now)) {
        updated.add(t);
        continue;
      }
      // Due → create a fresh one-off instance (repeat dropped) and advance
      // the original's reminder to the next occurrence.
      final subs = tasks.where((s) => s.parentId == t.id).toList();
      final (_, freshMain, freshSubs) = freshTaskCopy(t, subs);
      fresh.add(freshMain.copyWith(repeat: null));
      fresh.addAll(freshSubs.map((s) => s.copyWith(repeat: null)));
      updated.add(t.copyWith(reminder: nextRepeatDue(t.reminder!, t.repeat!)));
    }

    if (fresh.isNotEmpty) {
      await saveTasks([...updated, ...fresh]);
    }
    return fresh.length;
  }
}
