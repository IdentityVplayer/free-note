import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
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
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredNotes.length,
              itemBuilder: (context, index) {
                final note = filteredNotes[index];
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
                            child: Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Colors.blue,
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
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorScreen(noteId: note.id),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
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
