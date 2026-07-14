import 'package:flutter/material.dart';
import 'plugin_base.dart';
import '../models/plugin.dart';
import 'github_sync_host.dart';
import '../screens/github_sync_settings_screen.dart';

/// Built-in GitHub Sync plugin. Login uses the GitHub Device flow; the repo
/// picker auto-loads the logged-in user's repositories (public + private).
/// Tapping the plugin (or its gear) opens [GitHubSyncSettingsScreen].
class GitHubSyncPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.githubsync';

  @override
  String get name => 'GitHub Sync';

  @override
  String get description =>
      'Sync notes to GitHub via Device login. Tap to choose your repository.';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Borderless Notes';

  @override
  PluginType get type => PluginType.utility;

  @override
  bool get hasSettings => true;

  @override
  Widget? buildSettings(BuildContext context, [GitHubSyncHost? host]) =>
      host != null ? GitHubSyncSettingsScreen(host: host) : null;
}
