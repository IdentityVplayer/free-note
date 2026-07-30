import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/clipboard_service.dart';

/// In-app "剪切板" widget (v1.18.0): shows the recent clipboard history, lets
/// the user tap an entry to copy it back, delete a single entry, or clear all.
class ClipboardWidget extends StatelessWidget {
  const ClipboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final svc = ClipboardService.instance;

    return StreamBuilder<void>(
      stream: svc.onChange,
      builder: (ctx, _) {
        final items = svc.items;
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n.t('clipboard')),
              subtitle: Text('${items.length} / ${svc.max}'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.delete_sweep),
                label: Text(l10n.t('clear')),
                onPressed: items.isEmpty ? null : () => svc.clear(),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.t('clipboardEmpty'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final text = items[i];
                        return InkWell(
                          onTap: () async {
                            await svc.copyToClipboard(text);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.t('copiedToClipboard')),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: l10n.t('delete'),
                                  onPressed: () => svc.removeAt(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
