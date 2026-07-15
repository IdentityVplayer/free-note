/// Editor-side hook that lets plugins insert text without importing
/// [AppProvider] (which would create a circular dependency).
///
/// The editor registers [insertHandler] on init (and clears it on dispose).
/// A plugin's toolbar button calls [insertHandler] to insert its snippet at
/// the caret. Because it is a plain static callback, plugins stay decoupled
/// from app state — the same contract the GitHub Sync plugin uses via
/// [GitHubSyncHost].
class PluginHost {
  /// Set by the editor to insert text at the caret; null when no editor is
  /// active. Plugins must null-check before calling.
  static void Function(String snippet)? insertHandler;
}
