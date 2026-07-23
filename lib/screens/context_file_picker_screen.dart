import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/storage_service.dart';
import '../models/note.dart';
import '../l10n/app_localizations.dart';

/// Picks a markdown file to use as AI context.
///
/// Files are grouped by their containing folder: top-level `.md` files are
/// shown directly, while files inside a subfolder appear under a collapsible
/// folder header — tap the folder to reveal its files. **Every** folder under
/// the notes directory is listed (even empty ones), because we scan the real
/// directory tree rather than only notes that already carry metadata.
class ContextFilePickerScreen extends StatefulWidget {
  const ContextFilePickerScreen({super.key});

  @override
  State<ContextFilePickerScreen> createState() =>
      _ContextFilePickerScreenState();
}

/// A node in the notes-folder tree.
class _TreeNode {
  final String name;
  final String relativePath;
  final bool isDir;
  final List<_TreeNode> children;

  _TreeNode({
    required this.name,
    required this.relativePath,
    required this.isDir,
    this.children = const [],
  });
}

class _ContextFilePickerScreenState extends State<ContextFilePickerScreen> {
  List<_TreeNode> _root = [];
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
      final base = StorageService.instance.currentFolder;
      if (base == null || base.isEmpty) {
        _root = [];
      } else {
        final dir = Directory(base);
        if (!dir.existsSync()) {
          _root = [];
        } else {
          _root = _buildTree(dir, '').children;
        }
      }
    } catch (e) {
      _error = '${l10n.t('folderAccessError')}: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Recursively build the folder tree, skipping hidden entries (e.g. the
  /// `.config` metadata directory). Dirs sort before files; both by name.
  _TreeNode _buildTree(Directory dir, String rel) {
    final entries =
        dir
            .listSync()
            .whereType<FileSystemEntity>()
            .where((e) => !p.basename(e.path).startsWith('.'))
            .toList()
          ..sort((a, b) {
            final aDir = a is Directory;
            final bDir = b is Directory;
            if (aDir != bDir) return aDir ? -1 : 1;
            return p
                .basename(a.path)
                .toLowerCase()
                .compareTo(p.basename(b.path).toLowerCase());
          });

    final children = <_TreeNode>[];
    for (final e in entries) {
      final name = p.basename(e.path);
      final childRel = rel.isEmpty ? name : p.join(rel, name);
      if (e is Directory) {
        children.add(
          _TreeNode(
            name: name,
            relativePath: childRel,
            isDir: true,
            children: _buildTree(e, childRel).children,
          ),
        );
      } else if (e is File && e.path.endsWith('.md')) {
        children.add(
          _TreeNode(name: name, relativePath: childRel, isDir: false),
        );
      }
    }
    return _TreeNode(
      name: p.basename(dir.path),
      relativePath: rel,
      isDir: true,
      children: children,
    );
  }

  Future<void> _pickFile(String relativePath) async {
    final base = StorageService.instance.currentFolder;
    if (base == null) return;
    final file = File(p.join(base, relativePath));
    if (!file.existsSync()) return;
    final content = file.readAsStringSync();
    final note = Note.fromMarkdownFileOrAdopt(content, relativePath);
    if (mounted) Navigator.pop(context, note);
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
                      l10n.t('repositoryNeedFolder'),
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
          : _root.isEmpty
          ? Center(child: Text(l10n.t('noNotes')))
          : ListView(children: _renderNodes(_root)),
    );
  }

  List<Widget> _renderNodes(List<_TreeNode> nodes, {int depth = 0}) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      if (node.isDir) {
        final open = _expanded.contains(node.relativePath);
        widgets.add(
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(node.name),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 16),
            onTap: () => setState(() {
              if (open) {
                _expanded.remove(node.relativePath);
              } else {
                _expanded.add(node.relativePath);
              }
            }),
          ),
        );
        if (open) widgets.addAll(_renderNodes(node.children, depth: depth + 1));
      } else {
        widgets.add(
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(node.name),
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 16),
            onTap: () => _pickFile(node.relativePath),
          ),
        );
      }
    }
    return widgets;
  }
}
