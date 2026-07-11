import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';

/// Shown on first launch (or when no folder is configured) so the user picks
/// the local "repository" folder where `.md` note files are stored.
///
/// Instead of [FilePicker.getDirectoryPath] (which on Android 11+ returns a
/// SAF tree-URI that `dart:io` cannot write to), this is an in-app browser
/// over the *real* filesystem. With all-files access the user can navigate to
/// any folder and we store notes there as ordinary `.md` files.
class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({super.key});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  String _currentPath = '';
  List<String> _folders = [];
  bool _loading = true;
  String? _error;
  String _rootPath = '';

  @override
  void initState() {
    super.initState();
    _initRoot();
  }

  Future<void> _initRoot() async {
    _rootPath = await _resolveRoot();
    await _load(_rootPath);
  }

  Future<String> _resolveRoot() async {
    if (Platform.isAndroid) {
      const emulated = '/storage/emulated/0';
      if (Directory(emulated).existsSync()) return emulated;
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
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

  void _goUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath &&
        (_rootPath.isEmpty || _isWithinRoot(parent))) {
      _load(parent);
    }
  }

  bool _isWithinRoot(String path) {
    final rel = p.relative(path, from: _rootPath);
    return !rel.startsWith('..');
  }

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
      final newPath = p.join(_currentPath, name);
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

  Future<void> _useCurrent() async {
    final msg = await context.read<AppProvider>().chooseFolder(_currentPath);
    if (mounted && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _useDefault() async {
    final provider = context.read<AppProvider>();
    final base = Platform.isAndroid
        ? (await getExternalStorageDirectory())
        : (await getApplicationDocumentsDirectory());
    final path =
        '${base?.path ?? (await getApplicationDocumentsDirectory()).path}/wubianji_notes';
    final msg = await provider.chooseFolder(path);
    if (mounted && msg.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoUp =
        _rootPath.isNotEmpty &&
        _currentPath != _rootPath &&
        _isWithinRoot(_currentPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('selectFolderTitle')),
        leading: canGoUp
            ? IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: l10n.t('up'),
                onPressed: _goUp,
              )
            : null,
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
                  _currentPath.isEmpty ? '…' : _currentPath,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _useCurrent,
                icon: const Icon(Icons.check),
                label: Text(l10n.t('useThisFolder')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _useDefault,
                child: Text(l10n.t('useDefaultFolder')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
