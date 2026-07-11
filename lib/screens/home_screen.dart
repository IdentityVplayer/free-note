import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'plugins_screen.dart';
import 'ai_assistant_screen.dart';

/// Main screen — shows a list of notes with search, app bar actions.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  bool _fabOpen = false;

  /// Folder keys that are currently expanded (collapsed by default).
  final Set<String> _expanded = {};

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
    final folderKeys = folders.keys.toList()..sort();

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
      body: provider.isLoading && provider.notes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filteredNotes.isEmpty
          ? Center(
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
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                ...rootNotes.map(
                  (note) => _buildNoteCard(context, l10n, provider, note),
                ),
                ...folderKeys.expand(
                  (key) => [
                    _buildFolderHeader(context, key),
                    if (_expanded.contains(key))
                      ...folders[key]!.map(
                        (note) => _buildNoteCard(context, l10n, provider, note),
                      ),
                  ],
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabOpen) ...[
            _fabItem(Icons.note_add, l10n.t('newNote'), () {
              setState(() => _fabOpen = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditorScreen()),
              );
            }),
            const SizedBox(height: 12),
            _fabItem(Icons.create_new_folder, l10n.t('newFolder'), () {
              setState(() => _fabOpen = false);
              _createFolder(context);
            }),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            onPressed: () => setState(() => _fabOpen = !_fabOpen),
            tooltip: l10n.t('add'),
            child: Icon(_fabOpen ? Icons.close : Icons.add),
          ),
        ],
      ),
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
      ),
    );
  }

  /// A single note's card (extracted from the old flat list item).
  Widget _buildNoteCard(
    BuildContext context,
    AppLocalizations l10n,
    AppProvider provider,
    Note note,
  ) {
    return Card(
      child: ListTile(
        leading: note.isFavorite
            ? const Icon(Icons.star, color: Colors.amber)
            : const Icon(Icons.note_outlined),
        title: Row(
          children: [
            if (note.isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin, size: 16, color: Colors.blue),
              ),
            Expanded(
              child: Text(
                note.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
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
            PopupMenuItem(
              value: 'pin',
              child: Text(note.isPinned ? l10n.t('unpin') : l10n.t('pin')),
            ),
            PopupMenuItem(
              value: 'favorite',
              child: Text(
                note.isFavorite ? l10n.t('unfavorite') : l10n.t('favorite'),
              ),
            ),
            PopupMenuItem(value: 'delete', child: Text(l10n.t('deleteNote'))),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditorScreen(noteId: note.id)),
        ),
      ),
    );
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
        title: Text(l10n.t('newFolder')),
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
        ).showSnackBar(SnackBar(content: Text(l10n.t('contextNeedFolder'))));
      }
      return;
    }
    final dir = Directory(p.join(base, name.replaceAll(RegExp(r'[/\\]'), '_')));
    try {
      await dir.create(recursive: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('newFolder')}: $name')),
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
    final provider = context.read<AppProvider>();
    final msg = await provider.syncToGitHub();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
