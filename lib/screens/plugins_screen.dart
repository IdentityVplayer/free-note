import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';

/// Plugins management screen — view and toggle plugins.
class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final plugins = provider.pluginManager.pluginInfoList;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('plugins')),
      ),
      body: plugins.isEmpty
          ? Center(child: Text(l10n.t('noPlugins')))
          : ListView.builder(
              itemCount: plugins.length,
              itemBuilder: (context, index) {
                final plugin = plugins[index];
                final typeIcons = {
                  'editor': Icons.edit,
                  'exporter': Icons.download,
                  'importer': Icons.upload,
                  'theme': Icons.palette,
                  'utility': Icons.build,
                };

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(typeIcons[plugin.type.name] ?? Icons.extension),
                    title: Text(plugin.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plugin.description),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.t('version')}: ${plugin.version}  ·  ${l10n.t('author')}: ${plugin.author}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: Switch(
                      value: plugin.isEnabled,
                      onChanged: (value) {
                        provider.pluginManager.toggle(plugin.id);
                      },
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
