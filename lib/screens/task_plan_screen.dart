import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../utils/task_helpers.dart';
import '../l10n/app_localizations.dart';
import 'editor_screen.dart';

/// Task planning screen — a hierarchical to-do list (main tasks + subtasks)
/// with due dates, priority, optional note links, reminders and repetition.
/// Tasks persist via [TaskService].
class TaskPlanScreen extends StatefulWidget {
  const TaskPlanScreen({super.key});

  @override
  State<TaskPlanScreen> createState() => _TaskPlanScreenState();
}

class _TaskPlanScreenState extends State<TaskPlanScreen> {
  final List<Task> _tasks = [];
  bool _loading = true;

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
  }

  Future<void> _persist() async {
    _tasks.sort(Task.compareForDisplay);
    await TaskService.instance.saveTasks(_tasks);
    if (mounted) setState(() {});
  }

  void _addTask(Task task) {
    _tasks.add(task);
    _persist();
    _scheduleIfNeeded(task);
  }

  void _updateTask(Task task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    _persist();
    _scheduleIfNeeded(task);
  }

  void _removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id || t.parentId == id);
    _persist();
  }

  Future<void> _toggleDone(Task task) async {
    _updateTask(task.copyWith(done: !task.done));
    // Auto-complete the parent main task when all its subtasks are done.
    if (task.parentId != null) {
      final auto = context.read<AppProvider>().settings.autoCompleteMainTasks;
      if (auto) {
        final updated = recomputeMainDone(_tasks, task.parentId!, auto);
        _tasks
          ..clear()
          ..addAll(updated);
        await _persist();
      }
    }
  }

  void _scheduleIfNeeded(Task task) {
    if (task.reminder != null) {
      NotificationService.instance.scheduleReminder(
        task,
        title: AppLocalizations.of(context)?.t('reminder') ?? 'Reminder',
      );
    }
  }

  // ── Dialogs ──

  Future<void> _showTaskDialog({Task? existing, String? parentId}) async {
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
            existing != null
                ? l10n.t('editNote')
                : (parentId != null ? l10n.t('addSubtask') : l10n.t('newTask')),
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
      parentId: parentId ?? existing?.parentId,
      reminder: reminder,
      repeat: repeatCfg,
    );

    if (existing != null) {
      _updateTask(task);
    } else {
      _addTask(task);
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('deleteNote')),
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
    if (ok == true) _removeTask(task.id);
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

    final mainTasks = _tasks.where((t) => t.parentId == null).toList()
      ..sort(Task.compareForDisplay);
    List<Task> subtasksOf(String id) =>
        _tasks.where((t) => t.parentId == id).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('taskPlan'))),
      body: _loading
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
                for (final main in mainTasks) ...[
                  _buildMainCard(main, l10n, theme),
                  for (final sub in subtasksOf(main.id))
                    _buildSubCard(sub, l10n, theme),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.t('newTask'),
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.t('addSubtask'),
              onPressed: () => _showTaskDialog(parentId: task.id),
            ),
            PopupMenuButton<String>(
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
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.t('deleteNote')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard(Task task, AppLocalizations l10n, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Checkbox(
            value: task.done,
            onChanged: (_) => _toggleDone(task),
          ),
          title: Text(
            task.title,
            style: task.done
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  )
                : null,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: _buildMetaRow(task, l10n, theme),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _showTaskDialog(existing: task);
                  break;
                case 'delete':
                  _confirmDelete(task);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.t('edit'))),
              PopupMenuItem(value: 'delete', child: Text(l10n.t('deleteNote'))),
            ],
          ),
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
