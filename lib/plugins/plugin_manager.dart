import 'package:flutter/material.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

/// Plugin Manager — handles registration, enabling/disabling, and lifecycle of plugins.
class PluginManager extends ChangeNotifier {
  final Map<String, FreeNotePlugin> _plugins = {};

  Map<String, FreeNotePlugin> get plugins => Map.unmodifiable(_plugins);

  List<FreeNotePlugin> get enabledPlugins =>
      _plugins.values.where((p) => p.isEnabled).toList();

  List<PluginInfo> get pluginInfoList =>
      _plugins.values.map((p) => p.info).toList();

  /// Register a new plugin.
  void register(FreeNotePlugin plugin) {
    _plugins[plugin.id] = plugin;
    if (plugin.isEnabled) plugin.onEnable();
    notifyListeners();
  }

  /// Unregister a plugin.
  void unregister(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin != null) {
      if (plugin.isEnabled) plugin.onDisable();
      _plugins.remove(pluginId);
      notifyListeners();
    }
  }

  /// Enable a plugin.
  void enable(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin != null && !plugin.isEnabled) {
      plugin.isEnabled = true;
      plugin.onEnable();
      notifyListeners();
    }
  }

  /// Disable a plugin.
  void disable(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin != null && plugin.isEnabled) {
      plugin.isEnabled = false;
      plugin.onDisable();
      notifyListeners();
    }
  }

  /// Toggle a plugin's enabled state.
  void toggle(String pluginId) {
    final plugin = _plugins[pluginId];
    if (plugin != null) {
      if (plugin.isEnabled) {
        disable(pluginId);
      } else {
        enable(pluginId);
      }
    }
  }

  /// Process text through all enabled plugins.
  String processText(String input) {
    var result = input;
    for (final plugin in enabledPlugins) {
      final processed = plugin.processText(result);
      if (processed != null) result = processed;
    }
    return result;
  }

  /// Get all widgets from enabled plugins.
  List<Widget> buildWidgets(BuildContext context) {
    return enabledPlugins
        .map((p) => p.buildWidget(context))
        .whereType<Widget>()
        .toList();
  }
}
