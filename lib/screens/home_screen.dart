import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import '../services/pomodoro_service.dart';
import '../services/notification_service.dart';
import '../l10n/app_localizations.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'plugins_screen.dart';
import 'ai_assistant_screen.dart';
import 'task_plan_screen.dart';
import 'pomodoro_screen.dart';
import '../plugins/ai_context_plugin.dart';
import '../route_observer.dart';

/// Main screen — shows a list of notes with search, app bar actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  String _searchQuery = '';
  bool _fabOpen = false;

  /// True once we've subscribed to [routeObserver] (subscribing twice would
  /// double-fire [didPopNext]).
  bool _routeSubscribed = false;

  /// Key for the embedded task-plan dock, so we can call [reloadTasks] when
  /// the user returns from the standalone task-plan screen.
  final GlobalKey<TaskPlanScreenState> _taskPlanKey =
      GlobalKey<TaskPlanScreenState>();

  /// Bottom dock tab: 0 = 计划任务 (left), 1 = 笔记 (center), 2 = 番茄钟 (right).
  int _bottomIndex = 1;

  /// Folder keys that are currently expanded (collapsed by default).
  final Set<String> _expanded = {};

  /// Top-level folder names scanned from the notes directory tree,
  /// **including empty folders**, so a folder the user just created shows up
  /// on the home list even before it holds any note. null until the first
  /// scan completes. Merged with the folders derived from notes below, so
  /// both "folders with notes" and "empty folders" appear.
  Set<String>? _scannedFolders;
  String? _lastFolder;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
    final cur = StorageService.instance.currentFolder;
    if (cur != _lastFolder) {
      _lastFolder = cur;
      _loadFolders();
    }
  }

  @override
  void didPopNext() {
    // Returned from a sub-screen (e.g. TaskPlanScreen). Reload the embedded
    // task dock so tasks added/edited there show up immediately.
    _taskPlanKey.currentState?.reloadTasks();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Scan the notes directory tree and collect every top-level folder name
  /// (excluding folders whose name contains a dot, e.g. `.config`). Empty
  /// folders are included so they remain visible on the home list.
  Future<void> _loadFolders() async {
    final base = StorageService.instance.currentFolder;
    final result = <String>{};
    if (base != null && base.isNotEmpty) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        try {
          for (final entity in dir.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is! Directory) continue;
            final rel = p.relative(entity.path, from: dir.path);
            if (rel == '.' || rel.isEmpty) continue;
            final top = p.split(rel).first;
            if (!top.contains('.')) result.add(top);
          }
        } catch (_) {
          // Ignore unreadable folders; we fall back to note-derived groups.
        }
      }
    }
    if (mounted) setState(() => _scannedFolders = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();

    final filteredNotes = provider.sortedNotes.where((note) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(q) ||
          note.content.toLowerCase().contains(q) ||
          note.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    // Group notes by their top-level folder. Folders whose name contains a dot
    // (e.g. ".config") are hidden entirely — both the header and their notes.
    final visibleNotes = filteredNotes
        .where((n) => !_hiddenByDotFolder(n))
        .toList();
    final rootNotes = visibleNotes.where((n) => _groupKey(n).isEmpty).toList();
    final folders = <String, List<Note>>{};
    for (final n in visibleNotes) {
      final key = _groupKey(n);
      if (key.isNotEmpty) folders.putIfAbsent(key, () => []).add(n);
    }
    final folderKeys = <String>{...folders.keys};
    if (_scannedFolders != null) folderKeys.addAll(_scannedFolders!);
    final sortedKeys = folderKeys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('appTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.t('aiAssistant'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l10n.t('taskPlan'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaskPlanScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: l10n.t('pomodoro'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PomodoroScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.extension),
            tooltip: l10n.t('plugins'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PluginsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              provider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: l10n.t('darkMode'),
            onPressed: provider.toggleDarkMode,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.t('settings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            tooltip: l10n.t('syncNow'),
            onPressed: provider.isLoading ? null : () => _syncNow(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.t('searchHint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: _bottomIndex == 1
          ? _buildNotesList(
              l10n,
              provider,
              filteredNotes,
              rootNotes,
              folders,
              sortedKeys,
            )
          : _bottomIndex == 0
          ? _buildTasksDock(l10n)
          : _buildPomodoroDock(l10n),
      floatingActionButton: _bottomIndex == 1
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_fabOpen) ...[
                  _fabItem(Icons.note_add, l10n.t('newNote'), () {
                    setState(() => _fabOpen = false);
                    _showNewNoteDialog(context);
                  }),
                  const SizedBox(height: 12),
                  _fabItem(
                    Icons.create_new_folder,
                    l10n.t('newRepository'),
                    () {
                      setState(() => _fabOpen = false);
                      _createFolder(context);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton(
                  onPressed: () => setState(() => _fabOpen = !_fabOpen),
                  tooltip: l10n.t('add'),
                  child: Icon(_fabOpen ? Icons.close : Icons.add),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: () {
                if (_bottomIndex == 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskPlanScreen(autoAdd: true),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PomodoroScreen(autoAdd: true),
                    ),
                  );
                }
              },
              tooltip: _bottomIndex == 0
                  ? l10n.t('newTask')
                  : l10n.t('newPomodoro'),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) => setState(() => _bottomIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.checklist),
            label: l10n.t('taskPlan'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.note),
            label: l10n.t('notes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.timer),
            label: l10n.t('pomodoro'),
          ),
        ],
      ),
    );
  }

  /// Show a pre-creation dialog for new notes: choose name and subfolder.
  Future<void> _showNewNoteDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();
    final nameCtl = TextEditingController();
    String? targetFolder;

    // Scan top-level folders from the notes directory.
    final base = StorageService.instance.currentFolder;
    final folders = <String>[];
    if (base != null) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        for (final e in dir.listSync()) {
          if (e is Directory && !e.path.contains('.config')) {
            final name = p.basename(e.path);
            if (!name.startsWith('.')) folders.add(name);
          }
        }
      }
      folders.sort();
    }
    folders.insert(0, l10n.t('topLevel'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(l10n.t('newNote')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.t('noteNameHint'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: targetFolder ?? folders.first,
                decoration: InputDecoration(
                  labelText: l10n.t('subfolder'),
                  border: const OutlineInputBorder(),
                ),
                items: folders
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setInner(() => targetFolder = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('create')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtl.text.trim();
    if (name.isEmpty) return;
    final note = provider.createNote(title: name);
    final noteId = note.id;
    final folder = (targetFolder != null && targetFolder != l10n.t('topLevel'))
        ? targetFolder!
        : null;
    if (folder != null) {
      provider.updateNote(
        note.copyWith(relativePath: p.join(folder, note.fileName)),
      );
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(noteId: noteId)),
    );
  }

  /// Notes list (center dock tab) — the original home body.
  Widget _buildNotesList(
    AppLocalizations l10n,
    AppProvider provider,
    List<Note> filteredNotes,
    List<Note> rootNotes,
    Map<String, List<Note>> folders,
    List<String> sortedKeys,
  ) {
    if (provider.isLoading && provider.notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('noNotes'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('noNotesHint'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ...rootNotes.map(
          (note) => _buildNoteCard(context, l10n, provider, note),
        ),
        ...sortedKeys.expand(
          (key) => [
            _buildFolderHeader(context, key),
            if (_expanded.contains(key))
              ...(folders[key]?.isEmpty ?? true
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          l10n.t('repositoryEmpty'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ]
                  : folders[key]!
                        .map(
                          (note) =>
                              _buildNoteCard(context, l10n, provider, note),
                        )
                        .toList()),
          ],
        ),
      ],
    );
  }

  /// Task Planning view (left dock tab): the full planner, embedded without
  /// its own AppBar/FAB. The home FAB (when this tab is active) handles
  /// "new task", and the app-bar checklist icon opens it standalone.
  Widget _buildTasksDock(AppLocalizations l10n) {
    return TaskPlanScreen(embedded: true, key: _taskPlanKey);
  }

  /// Pomodoro quick view (right dock tab): shows the active profile's
  /// intervals and opens the full timer. No redundant "pomodoro" header tile.
  Widget _buildPomodoroDock(AppLocalizations l10n) {
    final cfg = PomodoroService.instance.active;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _pomoRow(
                  l10n,
                  Icons.work,
                  l10n.t('pomodoroFocus'),
                  cfg.workMinutes,
                ),
                const Divider(),
                _pomoRow(
                  l10n,
                  Icons.coffee,
                  l10n.t('pomodoroShortBreak'),
                  cfg.shortBreakMinutes,
                ),
                const Divider(),
                _pomoRow(
                  l10n,
                  Icons.weekend,
                  l10n.t('pomodoroLongBreak'),
                  cfg.longBreakMinutes,
                ),
                const Divider(),
                _pomoRow(
                  l10n,
                  Icons.repeat,
                  l10n.t('pomodoroInterval'),
                  cfg.longBreakEvery,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.t('pomodoroStart')),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PomodoroScreen()),
          ),
        ),
      ],
    );
  }

  Widget _pomoRow(
    AppLocalizations l10n,
    IconData icon,
    String label,
    int value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text('$value ${l10n.t('minutesUnit')}'),
      ],
    );
  }

  /// Top-level folder segment a note belongs to, or '' if it lives at root.
  String _groupKey(Note note) {
    final rel = note.relativePath ?? '';
    if (rel.isEmpty) return '';
    final dir = p.dirname(rel);
    if (dir == '.' || dir.isEmpty) return '';
    return p.split(dir).first;
  }

  /// True if any folder segment in the note's path contains a dot
  /// (e.g. the ".config" metadata directory). Such notes are hidden on the
  /// home list so internal config files are never shown to the user.
  bool _hiddenByDotFolder(Note note) {
    final rel = note.relativePath ?? '';
    if (rel.isEmpty) return false;
    final dir = p.dirname(rel);
    if (dir == '.' || dir.isEmpty) return false;
    return p.split(dir).any((seg) => seg.contains('.'));
  }

  /// Collapsible folder header; tap to reveal/hide the notes inside it.
  Widget _buildFolderHeader(BuildContext context, String folderKey) {
    final open = _expanded.contains(folderKey);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(
          folderKey,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
        onTap: () => setState(() {
          if (open) {
            _expanded.remove(folderKey);
          } else {
            _expanded.add(folderKey);
          }
        }),
        onLongPress: () => _showFolderContextMenu(context, folderKey),
      ),
    );
  }

  /// Long-press context menu for a folder header.
  void _showFolderContextMenu(BuildContext context, String folderKey) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.t('delete')),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFolder(context, folderKey);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    String folderKey,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.t('delete')} $folderKey'),
        content: Text(l10n.t('deleteConfirm')),
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
    if (ok == true) {
      final base = StorageService.instance.currentFolder;
      if (base != null) {
        final dir = Directory('$base/$folderKey');
        if (dir.existsSync()) {
          try {
            dir.deleteSync(recursive: true);
            _loadFolders();
            if (mounted) setState(() {});
          } catch (_) {}
        }
      }
    }
  }

  /// A single note's card (extracted from the old flat list item).
  Widget _buildNoteCard(
    BuildContext context,
    AppLocalizations l10n,
    AppProvider provider,
    Note note,
  ) {
    // AI chat notes (content starts with the magic line) get a badge and a
    // "resume chat" affordance when the AI plugin is enabled.
    final isAiChat = AiContextPlugin().isAiChat(note.content);
    final aiEnabled = provider.pluginManager.isPluginEnabled(
      'builtin.aicontext',
    );

    return Card(
      child: GestureDetector(
        onLongPress: () => _showNoteContextMenu(context, l10n, provider, note),
        child: ListTile(
          leading: isAiChat
              ? Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                )
              : (note.isFavorite
                    ? const Icon(Icons.star, color: Colors.amber)
                    : const Icon(Icons.note_outlined)),
          title: Row(
            children: [
              if (note.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 16, color: Colors.blue),
                ),
              if (isAiChat)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    label: const Text('AI', style: TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              Expanded(
                child: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (provider.syncedNoteIds.contains(note.id))
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: note.tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAiChat && aiEnabled)
                IconButton(
                  icon: const Icon(Icons.chat),
                  tooltip: l10n.t('resumeChat'),
                  onPressed: () => _resumeAiChat(note, l10n),
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'resume':
                      _resumeAiChat(note, l10n);
                      break;
                    case 'pin':
                      provider.togglePin(note.id);
                      break;
                    case 'favorite':
                      provider.toggleFavorite(note.id);
                      break;
                    case 'delete':
                      _confirmDelete(context, provider, note.id);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (isAiChat && aiEnabled)
                    PopupMenuItem(
                      value: 'resume',
                      child: Text(l10n.t('resumeChat')),
                    ),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(
                      note.isPinned ? l10n.t('unpin') : l10n.t('pin'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      note.isFavorite
                          ? l10n.t('unfavorite')
                          : l10n.t('favorite'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.t('deleteNote')),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(noteId: note.id)),
          ),
        ),
      ),
    );
  }

  /// Long-press context menu for a note card.
  void _showNoteContextMenu(
    BuildContext context,
    AppLocalizations l10n,
    AppProvider provider,
    Note note,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.t('rename')),
              onTap: () {
                Navigator.pop(ctx);
                _renameNote(context, provider, note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.t('move')),
              onTap: () {
                Navigator.pop(ctx);
                _moveNote(context, provider, note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: Text(l10n.t('copy')),
              onTap: () {
                Navigator.pop(ctx);
                _copyNote(context, provider, note);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.t('delete')),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, provider, note.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameNote(
    BuildContext context,
    AppProvider provider,
    Note note,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ctl = TextEditingController(text: note.title);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('rename')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(l10n.t('rename')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != note.title) {
      provider.updateNote(note.copyWith(title: name));
    }
  }

  Future<void> _moveNote(
    BuildContext context,
    AppProvider provider,
    Note note,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final base = StorageService.instance.currentFolder;
    if (base == null) return;
    final folders = <String>[''];
    final dir = Directory(base);
    if (dir.existsSync()) {
      for (final e in dir.listSync()) {
        if (e is Directory && !e.path.contains('.config')) {
          final name = p.basename(e.path);
          if (!name.startsWith('.')) folders.add(name);
        }
      }
    }
    String? target =
        note.relativePath != null && note.relativePath!.contains('/')
        ? p.dirname(note.relativePath!)
        : '';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('move')),
        content: DropdownButtonFormField<String>(
          initialValue: target,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: folders
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.isEmpty ? l10n.t('topLevel') : f),
                ),
              )
              .toList(),
          onChanged: (v) => target = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, target),
            child: Text(l10n.t('move')),
          ),
        ],
      ),
    );
    if (picked != null) {
      final newRel = picked.isEmpty
          ? note.fileName
          : '$picked/${note.fileName}';
      if (newRel != note.relativePath) {
        provider.updateNote(note.copyWith(relativePath: newRel));
      }
    }
  }

  Future<void> _copyNote(
    BuildContext context,
    AppProvider provider,
    Note note,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ctl = TextEditingController(text: '${note.title} (copy)');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('copy')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(l10n.t('copy')),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final copy = provider.createNote(title: name, content: note.content);
      provider.updateNote(
        copy.copyWith(
          relativePath: note.relativePath != null
              ? '${p.dirname(note.relativePath!)}/${copy.fileName}'
              : copy.fileName,
        ),
      );
    }
  }

  /// Resume an AI chat note from the home screen: open the in-file dialog with
  /// its conversation pre-loaded. Closing auto-saves the conversation back into
  /// the note (handled inside AIAssistantScreen when [noteId] is set).
  void _resumeAiChat(Note note, AppLocalizations l10n) {
    final messages = AiContextPlugin().parseMessages(note.content);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      pageBuilder: (ctx, _, _) => AIAssistantScreen(
        initialMessages: messages,
        noteId: note.id,
        initialContextName: note.relativePath ?? note.title,
      ),
    ).then((result) {
      if (result is String && result.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('aiNoteAutoSaved'))));
      }
    });
  }

  /// A labelled mini action shown above the main FAB when the menu is open.
  Widget _fabItem(IconData icon, String label, VoidCallback onTap) {
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  /// Create a new folder directly under the selected notes folder.
  Future<void> _createFolder(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('newRepository')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.t('folderName')),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.t('create')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final base = StorageService.instance.currentFolder;
    if (base == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('repositoryNeedFolder'))));
      }
      return;
    }
    final dir = Directory(p.join(base, name.replaceAll(RegExp(r'[/\\]'), '_')));
    try {
      await dir.create(recursive: true);
      _loadFolders();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('newRepository')}: $name')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();
    NotificationService.instance.showSync(l10n.t('syncNow'), '开始上传…');
    final msg = await provider.syncToGitHub();
    final success = !msg.startsWith('同步失败') && !msg.startsWith('GitHub 未配置');
    NotificationService.instance.showSync(success ? '上传成功' : '上传失败', msg);
  }

  void _confirmDelete(
    BuildContext context,
    AppProvider provider,
    String noteId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('deleteNote')),
        content: Text(l10n.t('deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNote(noteId);
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
  }
}
