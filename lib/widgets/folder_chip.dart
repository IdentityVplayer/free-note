import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';

/// Compact folder button (v1.18.1) used in the home app bar and the settings
/// "当前仓库" tile.
///
/// - [onTap] / [onDoubleTap] → open the folder picker (select / edit the folder)
/// - [onLongPress] → reveal the full folder path (the name may be truncated in
///   the chip, so a long-press shows where notes actually live)
class FolderChip extends StatelessWidget {
  final String? folderPath;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final bool compact;

  const FolderChip({
    super.key,
    required this.folderPath,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = folderPath == null
        ? l10n.t('selectFolder')
        : p.basename(folderPath!);
    final theme = Theme.of(context);

    final chip = Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: compact ? VisualDensity.compact : null,
      avatar: Icon(
        Icons.folder,
        size: 18,
        color: folderPath == null
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: chip,
    );
  }
}
