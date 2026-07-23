import 'package:flutter/material.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';
import 'plugin_host.dart';

/// A lightweight, runtime-added plugin created by the user from the Plugins
/// screen's "+" button. It carries the metadata the user entered (name,
/// description, type) plus an optional [snippet] (for "editor"-type plugins),
/// and supports enable/disable.
///
/// When an "editor"-type user plugin has a [snippet], it registers a real
/// toolbar button in the editor that inserts that text at the caret — so a
/// user plugin is no longer a metadata-only shell but a functional insert
/// tool. Other plugin types remain toggles (no safe declarative UI yet).
class UserPlugin extends FreeNotePlugin {
  @override
  final String id;

  @override
  final String name;

  @override
  final String description;

  @override
  final String version;

  @override
  final String author;

  @override
  final PluginType type;

  /// Optional insert text injected by the editor toolbar button. Only used
  /// when [type] is [PluginType.editor] and this is non-empty.
  final String? snippet;

  UserPlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.version = '1.0.0',
    this.author = 'User',
    this.snippet,
    bool enabled = true,
  }) {
    isEnabled = enabled;
  }

  /// Build a [UserPlugin] from its persisted [PluginInfo].
  factory UserPlugin.fromInfo(PluginInfo info) => UserPlugin(
    id: info.id,
    name: info.name,
    description: info.description,
    type: info.type,
    version: info.version,
    author: info.author,
    snippet: info.snippet,
    enabled: info.isEnabled,
  );

  /// Whether this plugin id belongs to a user-added plugin.
  static bool isUserPluginId(String id) => id.startsWith('user.');

  @override
  PluginInfo get info => PluginInfo(
    id: id,
    name: name,
    description: description,
    version: version,
    author: author,
    isEnabled: isEnabled,
    type: type,
    hasSettings: hasSettings,
    snippet: snippet,
  );

  @override
  Widget? buildWidget(BuildContext context) {
    // "editor"-type user plugins with a snippet get a real toolbar button.
    if (type == PluginType.editor && snippet != null && snippet!.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.extension),
        tooltip: name,
        onPressed: () => PluginHost.insertHandler?.call(snippet!),
      );
    }
    return null;
  }
}
