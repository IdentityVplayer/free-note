import '../models/settings.dart';
import '../services/github_sync_service.dart';

/// Minimal surface the GitHub Sync settings screen needs from the app.
///
/// Defined separately from [AppProvider] so the settings screen can use it
/// without importing `app_provider.dart` — which would create an import cycle
/// (app_provider → plugin → settings screen → app_provider). `AppProvider`
/// implements this interface.
abstract class GitHubSyncHost {
  AppSettings get settings;
  GitHubSyncService get githubService;

  /// Persist GitHub auth fields (token / username / repo / clientId / autoSync).
  Future<void> updateGitHubAuth({
    String? token,
    String? username,
    String? repo,
    String? clientId,
    bool? autoSync,
  });

  /// Immediate sync to GitHub.
  Future<String> syncToGitHub();

  /// Pull notes from GitHub.
  Future<String> pullFromGitHub();
}
