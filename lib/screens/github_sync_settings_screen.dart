import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import '../plugins/github_sync_host.dart';
import '../l10n/app_localizations.dart';
import '../services/github_sync_service.dart';

/// Settings page for the GitHub Sync plugin. Opened from the plugin card.
///
/// Provides:
///  - GitHub Device login (shows the user code + verification URL, then polls).
///  - A repository picker auto-populated from the logged-in user's repos.
///  - Disconnect and an auto-sync preference.
class GitHubSyncSettingsScreen extends StatefulWidget {
  final GitHubSyncHost host;

  const GitHubSyncSettingsScreen({super.key, required this.host});

  @override
  State<GitHubSyncSettingsScreen> createState() =>
      _GitHubSyncSettingsScreenState();
}

class _GitHubSyncSettingsScreenState extends State<GitHubSyncSettingsScreen> {
  late TextEditingController _clientIdController;
  List<GitHubRepo> _repos = [];
  String? _selectedRepo;
  bool _loadingRepos = false;
  bool _busy = false;
  String? _status;

  /// Set true to abort an in-flight device-code poll.
  bool _cancelPolling = false;

  @override
  void initState() {
    super.initState();
    final s = widget.host.settings;
    _clientIdController = TextEditingController(
      text: s.githubClientId ?? GitHubSyncService.defaultClientId,
    );
    _selectedRepo = s.githubRepo;
    if (s.githubToken != null && s.githubToken!.isNotEmpty) {
      _loadRepos(s.githubToken!);
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  String get _effectiveClientId =>
      (_clientIdController.text.trim().isEmpty
          ? GitHubSyncService.defaultClientId
          : _clientIdController.text.trim());

  Future<void> _persistClientId() async {
    await widget.host.updateGitHubAuth(clientId: _effectiveClientId);
  }

  Future<void> _loadRepos(String token) async {
    if (!mounted) return;
    setState(() {
      _loadingRepos = true;
      _status = null;
    });
    try {
      final repos = await widget.host.githubService.listUserRepos(token);
      if (!mounted) return;
      setState(() {
        _repos = repos;
        // Keep selection valid; fall back to stored value if still present.
        if (_selectedRepo != null &&
            !repos.any((r) => r.fullName == _selectedRepo)) {
          // stored repo may not be in list (e.g. collaborator filtered) — keep.
        }
      });
    } on GitHubAuthException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = '加载仓库失败: $e');
    } finally {
      if (mounted) setState(() => _loadingRepos = false);
    }
  }

  Future<void> _startLogin() async {
    final l10n = AppLocalizations.of(context)!;
    await _persistClientId();
    final clientId = _effectiveClientId;
    if (clientId.isEmpty) {
      setState(() => _status = l10n.t('githubClientIdRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final dc = await widget.host.githubService.requestDeviceCode(clientId);
      _cancelPolling = false;
      _showDeviceCodeDialog(dc);
      final token = await widget.host.githubService.pollForToken(
        clientId: clientId,
        deviceCode: dc.deviceCode,
        interval: dc.interval,
        expiresIn: dc.expiresIn,
        shouldCancel: () => _cancelPolling,
      );
      // Success — fetch the user and (re)load repositories.
      final user = await widget.host.githubService.getAuthenticatedUser(token);
      await widget.host.updateGitHubAuth(
        token: token,
        username: user.login,
        clientId: clientId,
      );
      await _loadRepos(token);
      if (mounted) {
        setState(() => _status = l10n.tArgs('githubLoggedInAs', [user.login]));
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } on GitHubAuthException catch (e) {
      if (mounted && !e.cancelled) setState(() => _status = e.message);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _status = '登录失败: $e');
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showDeviceCodeDialog(DeviceCodeResponse dc) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('githubDeviceCode')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('githubDeviceCodeHint')),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                dc.userCode,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.t('githubOpenAuth')}: ${dc.verificationUri}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('githubWaitingAuth'),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _cancelPolling = true;
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('cancel')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(l10n.t('githubCopyCode')),
            onPressed: () async {
              // Best-effort: copy the code to the clipboard and open the URL.
              await _copyAndOpen(dc);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _copyAndOpen(DeviceCodeResponse dc) async {
    // Clipboard copy + open the verification URL in the browser.
    try {
      // ignore: deprecated_member_use
      await Clipboard.setData(ClipboardData(text: dc.userCode));
    } catch (_) {
      // Clipboard may be unavailable on some platforms; ignore.
    }
    final uri = Uri.tryParse(dc.verificationUri);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _disconnect() async {
    await widget.host.updateGitHubAuth(
      token: '',
      username: '',
      repo: _selectedRepo ?? '',
    );
    if (mounted) {
      setState(() {
        _repos = [];
        _status = null;
      });
    }
  }

  Future<void> _syncNow() async {
    final msg = await widget.host.syncToGitHub();
    if (mounted) setState(() => _status = msg);
  }

  Future<void> _pullNow() async {
    final msg = await widget.host.pullFromGitHub();
    if (mounted) setState(() => _status = msg);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = widget.host.settings;
    final connected =
        s.githubToken != null && s.githubToken!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('githubSyncSettings'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Account status
          ListTile(
            leading: Icon(
              connected ? Icons.check_circle : Icons.cloud_off,
              color: connected ? Colors.green : null,
            ),
            title: Text(
              connected
                  ? l10n.tArgs('githubLoggedInAs', [s.githubUsername ?? ''])
                  : l10n.t('githubNotConnected'),
            ),
            subtitle: connected ? Text(s.githubRepo ?? '') : null,
          ),
          const Divider(),
          // Client ID
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _clientIdController,
              decoration: InputDecoration(
                labelText: l10n.t('githubClientId'),
                border: const OutlineInputBorder(),
                hintText: 'Iv1.xxxxx',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              l10n.t('githubClientIdHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          // Login / Disconnect
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: Text(l10n.t('githubLogin')),
                    onPressed: _busy ? null : _startLogin,
                  ),
                ),
                if (connected) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.t('githubDisconnect')),
                    onPressed: _busy ? null : _disconnect,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          // Repository picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _loadingRepos
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    key: ValueKey(_selectedRepo),
                    initialValue: _selectedRepo,
                    decoration: InputDecoration(
                      labelText: l10n.t('githubSelectRepo'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(
                      _repos.isEmpty
                          ? l10n.t('githubNoRepos')
                          : l10n.t('githubSelectRepo'),
                    ),
                    items: _repos
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.fullName,
                            child: Text(
                              '${r.fullName}${r.private ? '  🔒' : ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: connected
                        ? (value) async {
                            if (value == null) return;
                            setState(() => _selectedRepo = value);
                            await widget.host.updateGitHubAuth(repo: value);
                          }
                        : null,
                  ),
          ),
          if (!connected && _repos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l10n.t('githubLoginToLoadRepos'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          if (connected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.t('githubLoadRepos')),
                onPressed: _loadingRepos
                    ? null
                    : () => _loadRepos(s.githubToken!),
              ),
            ),
          const Divider(),
          // Auto sync toggle
          SwitchListTile(
            title: Text(l10n.t('autoSync')),
            value: s.autoSync,
            onChanged: (v) async {
              await widget.host.updateGitHubAuth(autoSync: v);
              if (mounted) setState(() {});
            },
          ),
          // Manual sync actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: Text(l10n.t('syncNow')),
                    onPressed: _syncNow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(l10n.t('pullFromGitHub')),
                    onPressed: _pullNow,
                  ),
                ),
              ],
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
