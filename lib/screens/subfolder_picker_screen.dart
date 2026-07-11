import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';

/// Lets the user pick a **subfolder inside the already-selected notes folder**
/// to save a note into — without changing the base folder in Settings.
///
/// Navigation is bounded at the base folder: the user can only go *deeper*,
/// never above it. The result is a path relative to [baseFolder]:
/// an empty string means "top level" (save directly in the notes folder).
class SubfolderPickerScreen extends StatefulWidget {
  /// Absolute path of the base notes folder (StorageService.currentFolder).
  final String baseFolder;

  /// Optional current relative path (file or directory) the note already uses,
  /// so the picker opens where the note currently lives.
  final String? initialRelative;

  const SubfolderPickerScreen({
    super.key,
    required this.baseFolder,
    this.initialRelative,
  });

  @override
  State<SubfolderPickerScreen> createState() => _SubfolderPickerScreenState();
}

class _SubfolderPickerScreenState extends State<SubfolderPickerScreen> {
  late String _currentPath;
  List<String> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.baseFolder;
    // Open where the note already lives, if it is inside the base folder.
    if (widget.initialRelative != null &&
        widget.initialRelative!.isNotEmpty &&
        !p.basename(widget.initialRelative!).contains('.')) {
      final candidate = p.join(widget.baseFolder, widget.initialRelative!);
      if (Directory(candidate).existsSync()) _currentPath = candidate;
    } else if (widget.initialRelative != null &&
        widget.initialRelative!.isNotEmpty) {
      final dir = p.dirname(widget.initialRelative!);
      if (dir.isNotEmpty && dir != '.') {
        final candidate = p.join(widget.baseFolder, dir);
        if (Directory(candidate).existsSync()) _currentPath = candidate;
      }
    }
    _load(_currentPath);
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// Relative path of [_currentPath] within the base folder ('' at root).
  String get _relative => p.relative(_currentPath, from: widget.baseFolder);

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final entries = dir
          .listSync()
          .whereType<Directory>()
          .where((d) => !p.basename(d.path).startsWith('.'))
          .toList();
      entries.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );
      setState(() {
        _currentPath = path;
        _folders = entries.map((e) => p.basename(e.path)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '${l10n.t('folderAccessError')}: $e';
        _loading = false;
      });
    }
  }

  void _navigateTo(String name) => _load(p.join(_currentPath, name));

  Future<void> _createFolder() async {
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
    if (name != null && name.isNotEmpty) {
      final clean = name.replaceAll(RegExp(r'[/\\]'), '_');
      final newPath = p.join(_currentPath, clean);
      try {
        await Directory(newPath).create(recursive: true);
        await _load(newPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
  }

  void _useCurrent() {
    // Return the relative path ('' for root / top level).
    Navigator.pop(context, _relative);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atRoot = _relative.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('selectSubfolderTitle')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.t('cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: l10n.t('newFolder'),
            onPressed: _createFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('folderCurrent'),
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  atRoot ? l10n.t('topLevel') : _relative,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : _folders.isEmpty
                ? Center(child: Text(l10n.t('noFolders')))
                : ListView.builder(
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final name = _folders[index];
                      return ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _navigateTo(name),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _useCurrent,
            icon: const Icon(Icons.check),
            label: Text(
              atRoot ? l10n.t('useTopLevel') : l10n.t('useThisSubfolder'),
            ),
          ),
        ),
      ),
    );
  }
}
