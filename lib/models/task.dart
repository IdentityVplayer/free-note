/// How often a task repeats. [every] is the interval count, [unit] one of
/// 'hour' | 'day' | 'week' | 'month' | 'year'.
class RepeatConfig {
  final int every;
  final String unit;

  const RepeatConfig({this.every = 1, required this.unit});

  factory RepeatConfig.fromJson(Map<String, dynamic> json) => RepeatConfig(
    every: (json['every'] as int?) ?? 1,
    unit: (json['unit'] as String?) ?? 'day',
  );

  Map<String, dynamic> toJson() => {'every': every, 'unit': unit};

  RepeatConfig copyWith({int? every, String? unit}) =>
      RepeatConfig(every: every ?? this.every, unit: unit ?? this.unit);
}

/// A single task in the planning list.
///
/// Tasks are kept lightweight: a title, completion flag, optional due date,
/// a priority level, an *optional* link back to a note (so a task can
/// point at the note it belongs to), and — for hierarchical planning — an
/// optional [parentId] that makes a task a *subtask* of a main task.
///
/// Reminders ([reminder]) and repetition ([repeat]) drive the notification /
/// auto-respawn feature.
class Task {
  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;
  final DateTime? dueDate;

  /// One of [priorityLow], [priorityNormal], [priorityHigh].
  final String priority;

  /// Optional note this task is linked to (display-only copy of the title).
  final String? noteId;
  final String? noteTitle;

  /// Parent main-task id. null means this is a top-level (main) task.
  final String? parentId;

  /// When to remind the user (local time). null = no reminder.
  final DateTime? reminder;

  /// Repetition rule. null = one-off.
  final RepeatConfig? repeat;

  static const String priorityLow = 'low';
  static const String priorityNormal = 'normal';
  static const String priorityHigh = 'high';

  static const List<String> priorities = [
    priorityHigh,
    priorityNormal,
    priorityLow,
  ];

  const Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
    this.dueDate,
    this.priority = priorityNormal,
    this.noteId,
    this.noteTitle,
    this.parentId,
    this.reminder,
    this.repeat,
  });

  Task copyWith({
    String? id,
    String? title,
    bool? done,
    DateTime? dueDate,
    String? priority,
    String? noteId,
    String? noteTitle,
    String? parentId,
    DateTime? reminder,
    RepeatConfig? repeat,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      noteId: noteId ?? this.noteId,
      noteTitle: noteTitle ?? this.noteTitle,
      parentId: parentId ?? this.parentId,
      reminder: reminder ?? this.reminder,
      repeat: repeat ?? this.repeat,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority,
    'noteId': noteId,
    'noteTitle': noteTitle,
    'parentId': parentId,
    'reminder': reminder?.toIso8601String(),
    'repeat': repeat?.toJson(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'] as String?;
    final due = json['dueDate'] as String?;
    final priority = json['priority'] as String?;
    final repeat = json['repeat'] as Map<String, dynamic>?;
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      done: json['done'] == true,
      createdAt: created != null
          ? DateTime.parse(created)
          : DateTime.fromMillisecondsSinceEpoch(0),
      dueDate: due != null ? DateTime.parse(due) : null,
      priority: priority != null && Task.priorities.contains(priority)
          ? priority
          : Task.priorityNormal,
      noteId: json['noteId'] as String?,
      noteTitle: json['noteTitle'] as String?,
      parentId: json['parentId'] as String?,
      reminder: json['reminder'] != null
          ? DateTime.parse(json['reminder'] as String)
          : null,
      repeat: repeat != null ? RepeatConfig.fromJson(repeat) : null,
    );
  }

  /// Sort weight for ordering: incomplete before done, then by priority
  /// (high first), then by due date (earliest first), then by creation.
  static int compareForDisplay(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final pa = Task.priorities.indexOf(a.priority);
    final pb = Task.priorities.indexOf(b.priority);
    if (pa != pb) return pa.compareTo(pb);

    // Tasks without a due date sort after those with one.
    if (a.dueDate != null && b.dueDate != null) {
      final c = a.dueDate!.compareTo(b.dueDate!);
      if (c != 0) return c;
    } else if (a.dueDate != null) {
      return -1;
    } else if (b.dueDate != null) {
      return 1;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          done == other.done &&
          dueDate == other.dueDate &&
          priority == other.priority &&
          noteId == other.noteId &&
          noteTitle == other.noteTitle &&
          parentId == other.parentId &&
          reminder == other.reminder &&
          repeat == other.repeat;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    done,
    dueDate,
    priority,
    noteId,
    noteTitle,
    parentId,
    reminder,
    repeat,
  );

  @override
  String toString() => 'Task($id, "$title", done=$done, priority=$priority)';
}
