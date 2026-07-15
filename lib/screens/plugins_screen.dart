import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/plugin.dart';
import '../plugins/user_plugin.dart';
import '../l10n/app_localizations.dart';

/// Plugins management screen — view, toggle, configure, add, and remove plugins.
class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();

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
        Navigator.push(context, MaterialPageRoute(builder: (_) => settings));
      }
    }

    Future<void> removePlugin(String pluginId) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: Text(l10n.t('deletePlugin')),
          content: Text(l10n.t('deletePluginConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(l10n.t('removePlugin')),
            ),
          ],
        ),
      );
      if (ok == true) {
        provider.removeUserPlugin(pluginId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('pluginRemoved'))),
          );
        }
      }
    }

    Future<void> showAddDialog() async {
      final nameCtl = TextEditingController();
      final descCtl = TextEditingController();
      final snippetCtl = TextEditingController();
      PluginType selected = PluginType.utility;

      await showDialog<void>(
        context: context,
        builder: (dctx) => StatefulBuilder(
          builder: (dctx, setDState) => AlertDialog(
            title: Text(l10n.t('newPlugin')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: InputDecoration(
                      labelText: l10n.t('pluginName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    decoration: InputDecoration(
                      labelText: l10n.t('pluginDescription'),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PluginType>(
                    initialValue: selected,
                    decoration: InputDecoration(
                      labelText: l10n.t('pluginType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: PluginType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(_typeLabel(t, l10n)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDState(() => selected = v!),
                  ),
                  if (selected == PluginType.editor) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: snippetCtl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.t('pluginSnippet'),
                        hintText: l10n.t('pluginSnippetHint'),
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final snippet = snippetCtl.text.trim();
                  final id = provider.addUserPlugin(
                    name: nameCtl.text,
                    description: descCtl.text,
                    type: selected,
                    snippet: snippet.isEmpty ? null : snippet,
                  );
                  Navigator.pop(dctx);
                  if (id != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.t('pluginAdded'))),
                    );
                  }
                },
                child: Text(l10n.t('create')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('plugins')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.t('addPlugin'),
            onPressed: showAddDialog,
          ),
        ],
      ),
      // Listen to the PluginManager directly so toggles update in real time
      // (AppProvider only notifies on its own changes, not the manager's).
      body: ListenableBuilder(
        listenable: provider.pluginManager,
        builder: (context, _) {
          final plugins = provider.pluginManager.pluginInfoList;

          return plugins.isEmpty
              ? Center(child: Text(l10n.t('noPlugins')))
              : ListView.builder(
                  itemCount: plugins.length,
                  itemBuilder: (context, index) {
                    final plugin = plugins[index];
                    final isUser = UserPlugin.isUserPluginId(plugin.id);

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
                            onLongPress: isUser
                                ? () => removePlugin(plugin.id)
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
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      plugin.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isUser)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plugin.description),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l10n.t('version')}: ${plugin.version}  ·  ${l10n.t('author')}: ${plugin.author}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                          // Custom gear at bottom-left signals editable settings.
                          if (plugin.hasSettings)
                            Positioned(
                              left: 6,
                              bottom: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => openSettings(plugin.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Image.asset(
                                    'lib/assets/icons/plugin_gear.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  String _typeLabel(PluginType t, dynamic l10n) {
    switch (t) {
      case PluginType.editor:
        return l10n.t('typeEditor');
      case PluginType.exporter:
        return l10n.t('typeExporter');
      case PluginType.importer:
        return l10n.t('typeImporter');
      case PluginType.theme:
        return l10n.t('typeTheme');
      case PluginType.utility:
        return l10n.t('typeUtility');
    }
  }
}
