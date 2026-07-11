import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/storage_service.dart';
import '../models/note.dart';
import '../l10n/app_localizations.dart';

/// Picks a markdown file to use as AI context.
///
/// Files are grouped by their containing folder (relative to the notes
/// folder): top-level `.md` files are shown directly, while files inside a
/// subfolder appear under a collapsible folder header — tap the folder to
/// reveal its files.
class ContextFilePickerScreen extends StatefulWidget {
  const ContextFilePickerScreen({super.key});

  @override
  State<ContextFilePickerScreen> createState() =>
      _ContextFilePickerScreenState();
}

class _ContextFilePickerScreenState extends State<ContextFilePickerScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _notes = await StorageService.instance.loadNotes();
    } catch (e) {
      _error = '${l10n.t('folderAccessError')}: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Note> get _topLevel {
    final list = <Note>[];
    for (final n in _notes) {
      final dir = p.dirname(n.relativePath ?? '');
      if (dir == '.' || dir.isEmpty) list.add(n);
    }
    return list;
  }

  Map<String, List<Note>> get _folders {
    final map = <String, List<Note>>{};
    for (final n in _notes) {
      final dir = p.dirname(n.relativePath ?? '');
      if (dir == '.' || dir.isEmpty) continue;
      map.putIfAbsent(dir, () => []).add(n);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final base = StorageService.instance.currentFolder;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('selectContextFile'))),
      body: base == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t('contextNeedFolder'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : _notes.isEmpty
          ? Center(child: Text(l10n.t('noNotes')))
          : _buildList(l10n),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    final folders = _folders;
    final folderNames = folders.keys.toList()..sort();
    final children = <Widget>[];

    // Top-level files shown directly.
    for (final note in _topLevel) {
      children.add(_fileTile(note));
    }

    // Folder groups (collapsible).
    for (final name in folderNames) {
      final isOpen = _expanded.contains(name);
      children.add(
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text(name),
          trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() {
            if (isOpen) {
              _expanded.remove(name);
            } else {
              _expanded.add(name);
            }
          }),
        ),
      );
      if (isOpen) {
        for (final note in folders[name]!) {
          children.add(_fileTile(note, indent: true));
        }
      }
    }

    return ListView(children: children);
  }

  Widget _fileTile(Note note, {bool indent = false}) {
    final rp = note.relativePath ?? '${note.id}.md';
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(p.basename(rp)),
      subtitle: note.title != p.basenameWithoutExtension(rp)
          ? Text(note.title)
          : null,
      contentPadding: indent
          ? const EdgeInsets.only(left: 32, right: 16)
          : null,
      onTap: () => Navigator.pop(context, note),
    );
  }
}
