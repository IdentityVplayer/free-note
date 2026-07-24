import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import '../plugins/github_sync_host.dart';
import '../l10n/app_localizations.dart';
import '../services/github_sync_service.dart';

/// Settings page for the GitHub Sync plugin. Opened from the plugin card.
///
/// Uses the GitHub Device flow:
///   1. Tap "Sign in" → app requests a [DeviceCodeResponse].
///   2. Browser auto-opens `https://github.com/login/device`.
///   3. The 8-digit user code is displayed inline (tappable to copy).
///   4. User pastes the code on the web page & clicks Continue.
///   5. Background polling detects authorization and obtains the token.
class GitHubSyncSettingsScreen extends StatefulWidget {
  final GitHubSyncHost host;

  const GitHubSyncSettingsScreen({super.key, required this.host});

  @override
  State<GitHubSyncSettingsScreen> createState() =>
      _GitHubSyncSettingsScreenState();
}

class _GitHubSyncSettingsScreenState extends State<GitHubSyncSettingsScreen> {
  late TextEditingController _clientIdController;
  late TextEditingController _tokenController;
  List<GitHubRepo> _repos = [];
  String? _selectedRepo;
  bool _loadingRepos = false;
  bool _busy = false;
  String? _status;

  /// GitHub Sync login mode: 'device' (OAuth Device flow) or 'token'
  /// (paste a Personal Access Token). Mirrors [AppSettings.githubSyncMode].
  String _syncMode = 'device';

  /// The active device-code session (null when not authorizing).
  DeviceCodeResponse? _deviceSession;

  /// Set true to abort an in-flight poll.
  bool _cancelPolling = false;

  /// Whether the custom-client-id field is expanded ("使用其他的Oauth登录").
  bool _showCustomClientId = false;

  @override
  void initState() {
    super.initState();
    final s = widget.host.settings;
    // Start empty so the default OAuth is used immediately; only prefill when
    // the user previously chose a custom OAuth App.
    _clientIdController = TextEditingController(text: s.githubClientId ?? '');
    _showCustomClientId =
        s.githubClientId != null && s.githubClientId!.isNotEmpty;
    _syncMode = s.githubSyncMode;
    // Token mode input is prefilled with the (in-memory, plaintext) token so
    // the user can see / re-edit it.
    _tokenController = TextEditingController(text: s.githubToken ?? '');
    _selectedRepo = s.githubRepo;
    if (s.githubToken != null && s.githubToken!.isNotEmpty) {
      _loadRepos(s.githubToken!);
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String get _effectiveClientId => (_clientIdController.text.trim().isEmpty
      ? GitHubSyncService.defaultClientId
      : _clientIdController.text.trim());

  Future<void> _persistClientId() async {
    await widget.host.updateGitHubAuth(clientId: _effectiveClientId);
  }

  // ── Repo loading ──────────────────────────────────────────────────

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
        if (_selectedRepo != null &&
            !repos.any((r) => r.fullName == _selectedRepo)) {
          // stored repo may not be in list — keep it.
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

  // ── Login: Device flow with auto-open ────────────────────────────

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
      _deviceSession = null;
      _status = l10n.t('githubWaitingAuth');
    });

    try {
      // Step 1 — request device + user code.
      final dc = await widget.host.githubService.requestDeviceCode(clientId);
      if (!mounted) return;
      setState(() => _deviceSession = dc);

      // Step 2 — auto-open https://github.com/login/device in the browser.
      final uri = Uri.parse(dc.verificationUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      // If launch fails we still continue — user can navigate manually.

      // Step 3 — poll until authorized / cancelled / expired.
      _cancelPolling = false;
      final token = await widget.host.githubService.pollForToken(
        clientId: clientId,
        deviceCode: dc.deviceCode,
        interval: dc.interval,
        expiresIn: dc.expiresIn,
        shouldCancel: () => _cancelPolling,
      );

      // Step 4 — success: resolve user, persist, load repos.
      final user = await widget.host.githubService.getAuthenticatedUser(token);
      await widget.host.updateGitHubAuth(
        token: token,
        username: user.login,
        clientId: clientId,
        syncMode: 'device',
      );
      await _loadRepos(token);
      if (mounted) {
        setState(() {
          _deviceSession = null;
          _status = l10n.tArgs('githubLoggedInAs', [user.login]);
        });
      }
    } on GitHubAuthException catch (e) {
      if (mounted) {
        setState(() {
          _deviceSession = null;
          if (!e.cancelled) _status = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceSession = null;
          _status = '登录失败: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelAuth() {
    _cancelPolling = true;
    setState(() {
      _deviceSession = null;
      _busy = false;
    });
  }

  // ── Login: Token (Key) mode ─────────────────────────────────────

  /// Connect using a pasted Personal Access Token. Validates the token by
  /// resolving the authenticated user, then persists it (same path the Device
  /// flow would have produced) so sync works identically.
  Future<void> _connectWithToken() async {
    final l10n = AppLocalizations.of(context)!;
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _status = l10n.t('githubTokenRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.t('githubVerifying');
    });
    try {
      final user = await widget.host.githubService.getAuthenticatedUser(token);
      await widget.host.updateGitHubAuth(
        token: token,
        username: user.login,
        syncMode: 'token',
      );
      await _loadRepos(token);
      if (mounted) {
        setState(() => _status = l10n.tArgs('githubLoggedInAs', [user.login]));
      }
    } on GitHubAuthException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = '连接失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Disconnect / sync helpers ─────────────────────────────────────

  Future<void> _disconnect() async {
    await widget.host.updateGitHubAuth(
      token: '',
      username: '',
      repo: _selectedRepo ?? '',
    );
    if (mounted) {
      setState(() {
        _repos = [];
        _deviceSession = null;
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

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = widget.host.settings;
    final connected = s.githubToken != null && s.githubToken!.isNotEmpty;
    final authorizing = _deviceSession != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('githubSyncSettings'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Account status ──
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

          // ── Login mode selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.t('githubMode'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'device',
                  label: Text(l10n.t('githubDeviceMode')),
                ),
                ButtonSegment(
                  value: 'token',
                  label: Text(l10n.t('githubTokenMode')),
                ),
              ],
              selected: {_syncMode},
              onSelectionChanged: (sel) =>
                  setState(() => _syncMode = sel.first),
            ),
          ),
          const SizedBox(height: 12),

          // ── Device (OAuth) mode ──
          if (_syncMode == 'device') ...[
            if (_showCustomClientId) ...[
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
            ],
            if (authorizing) ...[
              const SizedBox(height: 12),
              _buildAuthorizingCard(l10n),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: Text(l10n.t('githubLoginNow')),
                      onPressed: _busy ? null : _startLogin,
                    ),
                  ),
                  if (connected || authorizing) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: Text(
                        authorizing
                            ? l10n.t('cancel')
                            : l10n.t('githubDisconnect'),
                      ),
                      onPressed: _busy
                          ? null
                          : (authorizing ? _cancelAuth : _disconnect),
                    ),
                  ],
                ],
              ),
            ),
            if (!connected && !authorizing && !_showCustomClientId)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showCustomClientId = true),
                  child: Text(
                    l10n.t('githubUseOtherOauth'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],

          // ── Token (Key) mode ──
          if (_syncMode == 'token') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.t('githubToken'),
                  border: const OutlineInputBorder(),
                  hintText: l10n.t('githubTokenHint'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l10n.t('githubTokenHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.key),
                      label: Text(l10n.t('githubLoginNow')),
                      onPressed: _busy ? null : _connectWithToken,
                    ),
                  ),
                  if (connected) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: Text(l10n.t('githubDisconnect')),
                      onPressed: _busy ? null : _disconnect,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const Divider(),

          // ── Repository picker ──
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
          if (!connected && !authorizing && _repos.isEmpty)
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

          // ── Auto sync ──
          SwitchListTile(
            title: Text(l10n.t('autoSync')),
            value: s.autoSync,
            onChanged: (v) async {
              await widget.host.updateGitHubAuth(autoSync: v);
              if (mounted) setState(() {});
            },
          ),

          // ── Manual sync actions ──
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
          if (_status != null && !authorizing) ...[
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

  /// Inline card shown while waiting for the user to authorize on the web.
  Widget _buildAuthorizingCard(AppLocalizations l10n) {
    final code = _deviceSession!.userCode;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.t('githubWaitingAuth'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Big tappable code block.
            InkWell(
              onTap: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tArgs('githubCopiedCode', [code])),
                      ),
                    );
                  }
                } catch (_) {}
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.t('githubEnterThisCode'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.t('githubTapCopyHint'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
