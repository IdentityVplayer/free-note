import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import 'editor_screen.dart';

/// Task planning screen — a flat priority-grouped to-do list with due dates,
/// priority, optional note links, reminders and repetition.
/// Tasks persist via [TaskService].
class TaskPlanScreen extends StatefulWidget {
  /// When true, opens the "new task" dialog on first load (used by the
  /// home-screen FAB so a single tap on the tasks tab creates a task).
  final bool autoAdd;

  /// When true, render only the task list body (no AppBar / FAB) so it can be
  /// embedded inside another screen — e.g. the home-screen "计划任务" dock,
  /// which should show the same full UI as this screen.
  final bool embedded;

  const TaskPlanScreen({
    super.key,
    this.autoAdd = false,
    this.embedded = false,
  });

  @override
  State<TaskPlanScreen> createState() => TaskPlanScreenState();
}

class TaskPlanScreenState extends State<TaskPlanScreen> {
  final List<Task> _tasks = [];
  bool _loading = true;

  /// Reload tasks from disk (used by the home dock to refresh when the user
  /// returns from the full task-plan screen).
  void reloadTasks() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await TaskService.instance.loadTasks();
    if (mounted) {
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasks);
        _loading = false;
      });
    }
    if (widget.autoAdd && mounted) _showTaskDialog();
  }

  /// Persist the current [\_tasks] to disk. Trust the in-memory state as the
  /// user's intent — including an empty list (which means "delete all"). The
  /// previous empty-guard used to silently reload from disk, which actually
  /// **undid** deletions of the last task; that's the bug we just removed.
  Future<void> _persist() async {
    _tasks.sort(Task.compareForDisplay);
    await TaskService.instance.saveTasks(_tasks);
    if (mounted) setState(() {});
  }

  Future<void> _addTask(Task task) async {
    _tasks.add(task);
    await _persist();
    await _scheduleIfNeeded(task);
  }

  Future<void> _updateTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    await _persist();
    // Cancel any prior schedule for this task before re-scheduling (covers
    // the case where the reminder time was edited).
    await NotificationService.instance.cancelTaskReminder(task.id);
    await _scheduleIfNeeded(task);
  }

  Future<void> _removeTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await NotificationService.instance.cancelTaskReminder(id);
    await _persist();
  }

  Future<void> _toggleDone(Task task) async {
    await _updateTask(task.copyWith(done: !task.done));
  }

  Future<void> _scheduleIfNeeded(Task task) async {
    if (task.reminder == null) return;
    await NotificationService.instance.scheduleReminder(
      task,
      title: AppLocalizations.of(context)?.t('reminder') ?? 'Reminder',
    );
  }

  // ── Dialogs ──

  Future<void> _showTaskDialog({Task? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    DateTime? due = existing?.dueDate;
    DateTime? reminder = existing?.reminder;
    RepeatConfig? repeat = existing?.repeat;
    String priority = existing?.priority ?? Task.priorityNormal;
    String? noteId = existing?.noteId;
    String? noteTitle = existing?.noteTitle;
    final everyCtl = TextEditingController(
      text: (existing?.repeat?.every ?? 1).toString(),
    );

    Future<void> pickNote() async {
      final provider = context.read<AppProvider>();
      final chosen = await showDialog<Note>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.t('taskLinkNote')),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.notes.isEmpty
                ? Text(l10n.t('noNotes'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.notes.length,
                    itemBuilder: (_, i) {
                      final n = provider.notes[i];
                      return ListTile(
                        title: Text(n.title),
                        onTap: () => Navigator.pop(ctx, n),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel')),
            ),
          ],
        ),
      );
      if (chosen != null) {
        noteId = chosen.id;
        noteTitle = chosen.title;
      }
    }

    Future<void> pickReminder(StateSetter setInner) async {
      if (!mounted) return;
      final date = await showDatePicker(
        context: context,
        initialDate: reminder ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null) return;
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(reminder ?? DateTime.now()),
      );
      if (time == null) return;
      setInner(
        () => reminder = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(
            existing != null ? l10n.t('editNote') : l10n.t('newTask'),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.t('taskTitleHint'),
                    ),
                    onSubmitted: (_) => Navigator.pop(ctx, true),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          due != null
                              ? '${l10n.t('taskDue')}: ${DateFormat('yyyy-MM-dd').format(due!)}'
                              : l10n.t('taskNoDue'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        tooltip: l10n.t('taskDue'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: due ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setInner(() => due = picked);
                        },
                      ),
                      if (due != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setInner(() => due = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.t('taskPriority')),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: Task.priorityHigh,
                        label: Text(l10n.t('priorityHigh')),
                      ),
                      ButtonSegment(
                        value: Task.priorityNormal,
                        label: Text(l10n.t('priorityNormal')),
                      ),
                      ButtonSegment(
                        value: Task.priorityLow,
                        label: Text(l10n.t('priorityLow')),
                      ),
                    ],
                    selected: {priority},
                    onSelectionChanged: (s) =>
                        setInner(() => priority = s.first),
                  ),
                  const SizedBox(height: 12),
                  // Reminder
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder != null
                              ? '${l10n.t('reminderAt')}: ${DateFormat('yyyy-MM-dd HH:mm').format(reminder!)}'
                              : l10n.t('noReminder'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.alarm, size: 18),
                        tooltip: l10n.t('reminder'),
                        onPressed: () => pickReminder(setInner),
                      ),
                      if (reminder != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setInner(() => reminder = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Repeat
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          repeat != null
                              ? '${l10n.t('repeat')}: ${_repeatLabel(repeat!, l10n)}'
                              : l10n.t('repeatNone'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setInner(
                          () => repeat = repeat == null
                              ? RepeatConfig(every: 1, unit: 'day')
                              : null,
                        ),
                        child: Text(
                          repeat == null
                              ? l10n.t('repeat')
                              : l10n.t('repeatNone'),
                        ),
                      ),
                    ],
                  ),
                  if (repeat != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l10n.t('every')),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56,
                          child: TextField(
                            controller: everyCtl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SegmentedButton<String>(
                            multiSelectionEnabled: false,
                            segments: const [
                              ButtonSegment(value: 'hour', label: Text('h')),
                              ButtonSegment(value: 'day', label: Text('d')),
                              ButtonSegment(value: 'week', label: Text('w')),
                              ButtonSegment(value: 'month', label: Text('m')),
                              ButtonSegment(value: 'year', label: Text('y')),
                            ],
                            selected: {repeat!.unit},
                            onSelectionChanged: (s) => setInner(
                              () => repeat = repeat!.copyWith(unit: s.first),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          noteTitle != null
                              ? '${l10n.t('taskLinkNote')}: $noteTitle'
                              : l10n.t('taskLinkNote'),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (noteId != null) {
                            setInner(() {
                              noteId = null;
                              noteTitle = null;
                            });
                          } else {
                            await pickNote();
                            setInner(() {});
                          }
                        },
                        child: Text(
                          noteId != null
                              ? l10n.t('taskUnlink')
                              : l10n.t('taskLinkNote'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleCtl.text.trim();
    if (title.isEmpty) return;

    final every = int.tryParse(everyCtl.text.trim()) ?? 1;
    final repeatCfg = repeat?.copyWith(every: every < 1 ? 1 : every);

    final task = Task(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: existing?.createdAt ?? DateTime.now(),
      dueDate: due,
      priority: priority,
      noteId: noteId,
      noteTitle: noteTitle,
      reminder: reminder,
      repeat: repeatCfg,
    );

    if (existing != null) {
      await _updateTask(task);
    } else {
      await _addTask(task);
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('delete')),
        content: Text(l10n.t('taskDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) await _removeTask(task.id);
  }

  void _openLinkedNote(String? noteId) {
    if (noteId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(noteId: noteId)),
    );
  }

  String _repeatLabel(RepeatConfig r, AppLocalizations l10n) {
    final unitKey =
        {
          'hour': 'unitHour',
          'day': 'unitDay',
          'week': 'unitWeek',
          'month': 'unitMonth',
          'year': 'unitYear',
        }[r.unit] ??
        'unitDay';
    return '${r.every} ${l10n.t(unitKey)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final mainTasks = List<Task>.from(_tasks)..sort(Task.compareForDisplay);

    // Group main tasks by priority for sectioned display.
    final highTasks = mainTasks
        .where((t) => t.priority == Task.priorityHigh)
        .toList();
    final normalTasks = mainTasks
        .where((t) => t.priority == Task.priorityNormal)
        .toList();
    final lowTasks = mainTasks
        .where(
          (t) =>
              t.priority != Task.priorityHigh &&
              t.priority != Task.priorityNormal,
        )
        .toList();

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _tasks.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.checklist, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  l10n.t('taskEmpty'),
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (highTasks.isNotEmpty) ...[
                _priorityHeader(l10n, Task.priorityHigh, highTasks.length),
                for (final main in highTasks) _buildMainCard(main, l10n, theme),
              ],
              if (normalTasks.isNotEmpty) ...[
                _priorityHeader(l10n, Task.priorityNormal, normalTasks.length),
                for (final main in normalTasks)
                  _buildMainCard(main, l10n, theme),
              ],
              if (lowTasks.isNotEmpty) ...[
                _priorityHeader(l10n, Task.priorityLow, lowTasks.length),
                for (final main in lowTasks) _buildMainCard(main, l10n, theme),
              ],
            ],
          );

    // Embedded mode: caller (e.g. home dock) supplies its own AppBar/FAB.
    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('taskPlan'))),
      body: content,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.t('newTask'),
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Section header for a priority group: icon + label + task count.
  Widget _priorityHeader(AppLocalizations l10n, String priority, int count) {
    final color = switch (priority) {
      Task.priorityHigh => Colors.red.shade700,
      Task.priorityNormal => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };
    final label = switch (priority) {
      Task.priorityHigh => l10n.t('priorityHigh'),
      Task.priorityNormal => l10n.t('priorityNormal'),
      _ => l10n.t('priorityLow'),
    };
    final icon = switch (priority) {
      Task.priorityHigh => Icons.flag,
      Task.priorityNormal => Icons.flag_outlined,
      _ => Icons.flag,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 6),
          Text('($count)', style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMainCard(Task task, AppLocalizations l10n, ThemeData theme) {
    final priorityColor = switch (task.priority) {
      Task.priorityHigh => Colors.red,
      Task.priorityNormal => Colors.orange,
      _ => Colors.green,
    };
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          onChanged: (_) => _toggleDone(task),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: task.done
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      )
                    : const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.t('taskPriority'),
              child: Chip(
                label: Text(
                  task.priority == Task.priorityHigh
                      ? l10n.t('priorityHigh')
                      : task.priority == Task.priorityNormal
                      ? l10n.t('priorityNormal')
                      : l10n.t('priorityLow'),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: priorityColor.withValues(alpha: 0.15),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        subtitle: _buildMetaRow(task, l10n, theme),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _showTaskDialog(existing: task);
                break;
              case 'open':
                _openLinkedNote(task.noteId);
                break;
              case 'delete':
                _confirmDelete(task);
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.t('edit'))),
            if (task.noteId != null)
              PopupMenuItem(
                value: 'open',
                child: Text(l10n.t('taskOpenLinked')),
              ),
            PopupMenuItem(value: 'delete', child: Text(l10n.t('delete'))),
          ],
        ),
      ),
    );
  }

  /// Shared subtitle: due date, reminder, repeat, linked note.
  Widget _buildMetaRow(Task task, AppLocalizations l10n, ThemeData theme) {
    final chips = <Widget>[];
    if (task.dueDate != null) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 14),
            const SizedBox(width: 4),
            Text(
              DateFormat('yyyy-MM-dd').format(task.dueDate!),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    if (task.reminder != null) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm, size: 14),
            const SizedBox(width: 4),
            Text(
              DateFormat('MM-dd HH:mm').format(task.reminder!),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    if (task.repeat != null) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.repeat, size: 14),
            const SizedBox(width: 4),
            Text(
              _repeatLabel(task.repeat!, l10n),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    if (task.noteTitle != null) {
      chips.add(
        InkWell(
          onTap: () => _openLinkedNote(task.noteId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 14),
              const SizedBox(width: 4),
              Text(
                task.noteTitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 4, children: chips);
  }
}
