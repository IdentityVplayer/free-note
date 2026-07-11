import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';

/// Shown on first launch (or when no folder is configured) so the user picks
/// the local "repository" folder where `.md` note files are stored.
class FolderPickerScreen extends StatelessWidget {
  const FolderPickerScreen({super.key});

  Future<void> _pick(BuildContext context) async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null && context.mounted) {
      await context.read<AppProvider>().chooseFolder(path);
    }
  }

  Future<void> _useDefault(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/wubianji_notes';
    if (context.mounted) {
      await context.read<AppProvider>().chooseFolder(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.t('selectFolderTitle'),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('selectFolderHint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.folder),
                label: Text(l10n.t('selectFolder')),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _useDefault(context),
                child: Text(l10n.t('useDefaultFolder')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
