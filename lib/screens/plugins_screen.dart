import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';

/// Plugins management screen — view, toggle, and configure plugins.
class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final plugins = provider.pluginManager.pluginInfoList;

    final typeIcons = {
      'editor': Icons.edit,
      'exporter': Icons.download,
      'importer': Icons.upload,
      'theme': Icons.palette,
      'utility': Icons.build,
    };

    void openSettings(String pluginId) {
      final plugin = provider.pluginManager.plugins[pluginId];
      final settings = plugin?.buildSettings(context, provider);
      if (settings != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => settings),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('plugins'))),
      body: plugins.isEmpty
          ? Center(child: Text(l10n.t('noPlugins')))
          : ListView.builder(
              itemCount: plugins.length,
              itemBuilder: (context, index) {
                final plugin = plugins[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Stack(
                    children: [
                      InkWell(
                        onTap: plugin.hasSettings
                            ? () => openSettings(plugin.id)
                            : null,
                        child: ListTile(
                          // Extra bottom padding leaves room for the gear.
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            28,
                          ),
                          leading: Icon(
                            typeIcons[plugin.type.name] ?? Icons.extension,
                          ),
                          title: Text(
                            plugin.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                      ),
                      // Gear at bottom-left signals editable settings.
                      if (plugin.hasSettings)
                        Positioned(
                          left: 8,
                          bottom: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => openSettings(plugin.id),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.t('pluginSettings'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
