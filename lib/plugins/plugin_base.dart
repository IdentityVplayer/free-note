import 'package:flutter/material.dart';
import '../models/plugin.dart';

/// Abstract base class for Free Note plugins.
/// Plugins can extend the app's functionality with custom features.
abstract class FreeNotePlugin {
  /// Unique identifier for this plugin.
  String get id;

  /// Human-readable name.
  String get name;

  /// Short description of what the plugin does.
  String get description;

  /// Plugin version string.
  String get version;

  /// Author name.
  String get author;

  /// The type of plugin.
  PluginType get type;

  /// Whether the plugin is currently enabled.
  bool isEnabled = true;

  /// Called when the plugin is first loaded.
  void onEnable() {}

  /// Called when the plugin is disabled.
  void onDisable() {}

  /// Build any UI widget the plugin provides (e.g. a toolbar button).
  /// Return null if the plugin has no UI.
  Widget? buildWidget(BuildContext context) => null;

  /// Process text — plugins can transform note content.
  /// e.g. word count, format conversion, etc.
  String? processText(String input) => null;

  /// Get plugin info model.
  PluginInfo get info => PluginInfo(
        id: id,
        name: name,
        description: description,
        version: version,
        author: author,
        isEnabled: isEnabled,
        type: type,
      );
}
