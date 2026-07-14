import 'package:flutter/material.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

/// A lightweight, runtime-added plugin created by the user from the Plugins
/// screen's "+" button. It carries the metadata the user entered (name,
/// description, type) and supports enable/disable. It has no custom code hooks
/// today — it exists so users can catalogue and toggle their own plugin slots
/// and so the "+" flow has a real, persistent target.
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

  UserPlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.version = '1.0.0',
    this.author = 'User',
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
    enabled: info.isEnabled,
  );

  /// Whether this plugin id belongs to a user-added plugin.
  static bool isUserPluginId(String id) => id.startsWith('user.');

  @override
  Widget? buildWidget(BuildContext context) => null;
}
