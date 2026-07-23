import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/task_service.dart';
import '../l10n/app_localizations.dart';
import 'editor_screen.dart';

/// Task planning screen — a lightweight to-do list with due dates, priority,
/// and optional links back to notes. Tasks persist via [TaskService].
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
  }

  void _updateTask(Task task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) _tasks[idx] = task;
    _persist();
  }

  void _removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _persist();
  }

  Future<void> _toggleDone(Task task) async {
    _updateTask(task.copyWith(done: !task.done));
  }

  // ── Dialogs ──

  Future<void> _showTaskDialog({Task? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    final titleCtl = TextEditingController(text: existing?.title ?? '');
    DateTime? due = existing?.dueDate;
    String priority = existing?.priority ?? Task.priorityNormal;
    String? noteId = existing?.noteId;
    String? noteTitle = existing?.noteTitle;

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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(existing != null ? l10n.t('editNote') : l10n.t('newTask')),
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
                    onSelectionChanged: (s) => setInner(() => priority = s.first),
                  ),
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

    if (existing != null) {
      _updateTask(
        existing.copyWith(
          title: title,
          dueDate: due,
          priority: priority,
          noteId: noteId,
          noteTitle: noteTitle,
        ),
      );
    } else {
      _addTask(
        Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          createdAt: DateTime.now(),
          dueDate: due,
          priority: priority,
          noteId: noteId,
          noteTitle: noteTitle,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

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
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (_, i) => _buildTaskCard(_tasks[i], l10n, theme),
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.t('newTask'),
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskCard(
    Task task,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
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
        subtitle: Row(
          children: [
            if (task.dueDate != null)
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
            if (task.noteTitle != null) ...[
              const SizedBox(width: 8),
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
            ],
          ],
        ),
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
            PopupMenuItem(
              value: 'edit',
              child: Text(l10n.t('edit')),
            ),
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
      ),
    );
  }
}
