import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/clipboard_service.dart';
import '../services/storage_service.dart';
import '../services/github_sync_service.dart';
import '../services/notification_service.dart';
import '../utils/app_arch.dart';
import '../utils/curl_downloader.dart';
import '../markdown/math_markdown.dart';
import '../l10n/app_localizations.dart';
import '../models/settings.dart';
import '../screens/folder_picker_screen.dart';

/// Settings screen — folder, language, dark mode, theme color, AI config, GitHub config.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<TextEditingController> _aiKeyControllers;
  late TextEditingController _aiModelController;
  late TextEditingController _aiBaseUrlController;
  late TextEditingController _aiLabelController;
  late String _language;
  late bool _darkMode;
  late String _aiProvider;
  late List<String> _aiModels;
  final TextEditingController _aiModelAddController = TextEditingController();
  String? _themeColorHex;

  /// Clipboard widget: max number of history items to keep (1..99999).
  late TextEditingController _clipboardMaxController;

  /// Whether the (obscured by default) AI API key fields are revealed.
  bool _showApiKey = false;

  /// Set of endpoints that are built-in (so we can decide whether to render
  /// label / baseUrl as read-only or editable). Cached at init from
  /// [AIProviderPresets.order].
  late Set<String> _builtinIds;

  static const List<Color> _themeColors = [
    Color(0xFF6750A4),
    Color(0xFF1976D2),
    Color(0xFF388E3C),
    Color(0xFFE64A19),
    Color(0xFFC2185B),
    Color(0xFF00796B),
  ];

  @override
  void initState() {
    super.initState();
    _builtinIds = AIProviderPresets.order.toSet();
    final s = context.read<AppProvider>().settings;
    _aiKeyControllers = s.currentEndpoint.keys
        .map((k) => TextEditingController(text: k))
        .toList();
    final ep = s.currentEndpoint;
    _aiModelController = TextEditingController(text: s.aiModel);
    _aiBaseUrlController = TextEditingController(text: ep.baseUrl ?? '');
    _aiLabelController = TextEditingController(text: ep.label);
    _language = s.languageCode;
    _darkMode = s.isDarkMode;
    _aiProvider = s.currentAiId.isEmpty
        ? 'openrouter'
        : s.currentAiId; // custom:<id> preserved as-is, built-ins stay keys
    _aiModels = List<String>.from(s.aiModels);
    _themeColorHex = s.themeColorHex;
    _clipboardMaxController = TextEditingController(
      text: s.clipboardMax.toString(),
    );
  }

  @override
  void dispose() {
    for (final c in _aiKeyControllers) {
      c.dispose();
    }
    _aiModelController.dispose();
    _aiBaseUrlController.dispose();
    _aiLabelController.dispose();
    _aiModelAddController.dispose();
    _clipboardMaxController.dispose();
    super.dispose();
  }

  /// Add an empty API key row (used as fallback if key [i] hits a 401/403/429).
  void _addAiKey() {
    setState(() {
      _aiKeyControllers.add(TextEditingController());
    });
  }

  void _removeAiKey(int i) {
    setState(() {
      final c = _aiKeyControllers.removeAt(i);
      c.dispose();
    });
  }

  /// Re-load the current provider's saved keys into the editor controllers.
  /// Called when the user changes the provider dropdown so they always edit
  /// the right set of keys.
  void _syncKeysToProvider() {
    final settings = context.read<AppProvider>().settings;
    final endpoints = settings.aiEndpoints;
    final ep = endpoints.firstWhere(
      (e) => e.id == _aiProvider,
      orElse: () => endpoints.first,
    );
    for (final c in _aiKeyControllers) {
      c.dispose();
    }
    _aiKeyControllers = ep.keys
        .map((k) => TextEditingController(text: k))
        .toList();
    _aiBaseUrlController.text = ep.baseUrl ?? '';
    _aiLabelController.text = ep.label;
  }

  /// Add a fresh user-defined AI endpoint and switch the editor to it. The
  /// new endpoint is created empty (no keys, default URL) so the user can
  /// fill it in.
  void _addCustomAiEndpoint() {
    final provider = context.read<AppProvider>();
    final id = 'custom:${DateTime.now().microsecondsSinceEpoch}';
    final existingCustom = provider.settings.aiEndpoints
        .where((e) => e.id.startsWith('custom:'))
        .length;
    final newEp = AiEndpoint(
      id: id,
      label: '自定义 ${existingCustom + 1}',
      baseUrl: 'https://',
    );
    setState(() {
      for (final c in _aiKeyControllers) {
        c.dispose();
      }
      _aiKeyControllers = <TextEditingController>[TextEditingController()];
      _aiBaseUrlController.text = newEp.baseUrl!;
      _aiLabelController.text = newEp.label;
      _aiProvider = id;
    });
    provider.updateSettings(
      provider.settings.copyWith(
        aiEndpoints: [...provider.settings.aiEndpoints, newEp],
        currentAiId: id,
      ),
    );
  }

  /// Drop the currently-selected custom endpoint and switch back to a built-in
  /// (openrouter if available). Built-ins cannot be deleted.
  void _deleteCurrentCustomAiEndpoint() {
    if (_builtinIds.contains(_aiProvider)) return;
    final provider = context.read<AppProvider>();
    final remaining = provider.settings.aiEndpoints
        .where((e) => e.id != _aiProvider)
        .toList();
    if (remaining.isEmpty) return;
    final fallbackId = remaining.first.id;
    setState(() {
      for (final c in _aiKeyControllers) {
        c.dispose();
      }
      _aiKeyControllers = remaining.first.keys
          .map((k) => TextEditingController(text: k))
          .toList();
      _aiBaseUrlController.text = remaining.first.baseUrl ?? '';
      _aiLabelController.text = remaining.first.label;
      _aiProvider = fallbackId;
    });
    provider.updateSettings(
      provider.settings.copyWith(
        aiEndpoints: remaining,
        currentAiId: fallbackId,
      ),
    );
  }

  /// Display label for an [AiEndpoint] in the provider dropdown — uses the
  /// built-in preset name when applicable.
  String _endpointLabel(AiEndpoint e) {
    if (e.builtinKey != null) {
      return AIProviderPresets.labelFor(e.builtinKey!);
    }
    return e.label;
  }

  void _save() {
    final provider = context.read<AppProvider>();
    // Clipboard history cap — clamp to [1, 99999] so the widget stays sane.
    final parsedMax = int.tryParse(_clipboardMaxController.text.trim());
    final clipboardMax = (parsedMax == null || parsedMax < 1)
        ? 100
        : (parsedMax > 99999 ? 99999 : parsedMax);
    ClipboardService.instance.setMax(clipboardMax);
    // Build the new endpoint list with the user's current edits on the
    // selected endpoint, plus the unchanged entries for the others.
    final isCustom = !_builtinIds.contains(_aiProvider);
    final baseUrl = _aiBaseUrlController.text.trim();
    final label = _aiLabelController.text.trim().isEmpty
        ? '自定义'
        : _aiLabelController.text.trim();
    final newKeys = _aiKeyControllers
        .map((c) => c.text.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    final endpoints = <AiEndpoint>[];
    for (final e in provider.settings.aiEndpoints) {
      if (e.id == _aiProvider) {
        endpoints.add(
          e.copyWith(
            label: label,
            baseUrl: isCustom ? (baseUrl.isEmpty ? null : baseUrl) : null,
            keys: newKeys,
          ),
        );
      } else {
        endpoints.add(e);
      }
    }
    provider.updateSettings(
      AppSettings(
        languageCode: _language,
        isDarkMode: _darkMode,
        githubToken: provider.settings.githubToken,
        githubRepo: provider.settings.githubRepo,
        githubClientId: provider.settings.githubClientId,
        githubUsername: provider.settings.githubUsername,
        aiModel: _aiModelController.text.trim(),
        autoSync: provider.settings.autoSync,
        enableAI: true,
        aiEndpoints: endpoints,
        currentAiId: _aiProvider,
        themeColorHex: _themeColorHex,
        notesFolderPath: provider.settings.notesFolderPath,
        repositories: provider.settings.repositories,
        aiModels: _aiModels.where((m) => m.trim().isNotEmpty).toList(),
        clipboardMax: clipboardMax,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _changeRepository() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();
    final repos = provider.settings.repositories;
    final current = provider.settings.notesFolderPath;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('switchRepository')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in repos)
                ListTile(
                  leading: Icon(
                    r == current ? Icons.check_circle : Icons.folder,
                    color: r == current
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.t('addRepository')),
                onTap: () => Navigator.pop(ctx, '__add__'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == '__add__') {
      await _changeFolder();
      return;
    }
    await provider.chooseFolder(choice);
    if (mounted) setState(() {});
  }

  Future<void> _changeFolder() async {
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
      );
      setState(() {});
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<({String version, String arch})> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    final arch = await AppArch.detect();
    return (version: info.version, arch: arch);
  }

  Future<void> _checkUpdate() async {
    final l10n = AppLocalizations.of(context)!;
    final release = await fetchLatestRelease('IdentityVplayer/free-note');
    if (!mounted) return;
    if (release == null) {
      _toast(l10n.t('upToDate'));
      return;
    }
    final info = await PackageInfo.fromPlatform();
    final latest = release.tagName.replaceAll(RegExp(r'^v'), '');
    if (GitHubRelease.isNewer(latest, info.version)) {
      NotificationService.instance.showUpdate(
        l10n.t('updateAvailable'),
        'v$latest 现已可用 — 当前版本 v${info.version}',
      );
      _showUpdateDialog(release);
    } else {
      _toast(l10n.t('upToDate'));
    }
  }

  /// Choose the APK asset URL that matches the current app's CPU arch. Falls
  /// back to a sensible default (arm64-v8a / x64) when not found.
  String? _pickApkForArch(GitHubRelease release, String arch) {
    final filtered = release.assetUrls
        .where((u) => u.endsWith('.apk'))
        .toList();
    if (filtered.isEmpty) return null;
    String? pick;
    String? fallback;
    for (final url in filtered) {
      final lower = url.toLowerCase();
      if (lower.contains(arch.toLowerCase())) {
        pick = url;
        break;
      }
      if (arch.contains('arm64') && lower.contains('arm64-v8a')) {
        fallback ??= url;
      } else if ((arch.contains('x86_64') || arch.contains('x64')) &&
          (lower.contains('x86_64') || lower.contains('x64'))) {
        fallback ??= url;
      }
    }
    return pick ?? fallback ?? filtered.first;
  }

  void _showUpdateDialog(GitHubRelease release) async {
    final l10n = AppLocalizations.of(context)!;
    final arch = await AppArch.detect();
    if (!mounted) return;
    // Pick the APK matching the running app's architecture; fall back to
    // arm64-v8a (most common on Android) / x64 (Windows) if not present.
    final apkAsset = _pickApkForArch(release, arch);
    // Rewrite to the xget mirror so we don't need GitHub network access
    // (xget is the XGet CDN proxy used by some Chinese free-note users).
    final apkUrl = apkAsset == null
        ? null
        : 'https://xget.xi-xu.me/gh/IdentityVplayer/free-note/releases/download/'
              '${Uri.encodeComponent(release.tagName)}/'
              '${Uri.encodeComponent(p.basename(Uri.parse(apkAsset).path))}';
    int pct = -1; // -1 = idle, 0..100 = progress, 101 = done
    String? errorMsg;
    final cancelled = ValueNotifier<bool>(false);
    // Default save path: <repo>/download/free-note-<current_version>.apk
    final info = await PackageInfo.fromPlatform();
    final saveDir = await _defaultDownloadDir();
    final savePath = p.join(saveDir, 'free-note-${info.version}.apk');
    final ctx = context;
    if (!mounted) return;

    showDialog(
      // ignore: use_build_context_synchronously
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text('${l10n.t('updateAvailable')} (${release.tagName})'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pct < 0)
                    safeMarkdown(
                      data: release.body.isEmpty
                          ? release.tagName
                          : release.body,
                    ),
                  if (apkUrl == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '未找到匹配当前架构 ($arch) 的 APK',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (pct >= 0 && pct < 101)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: pct.clamp(0, 100) / 100,
                          ),
                          const SizedBox(height: 6),
                          Text(pct == 0 ? '正在连接…' : '下载中… $pct%'),
                        ],
                      ),
                    ),
                  if (pct >= 101)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('下载完成'),
                        ],
                      ),
                    ),
                  if (errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '下载失败: $errorMsg',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (pct < 101 && errorMsg == null)
              TextButton(
                onPressed: () {
                  cancelled.value = true;
                  Navigator.pop(ctx);
                },
                child: Text(l10n.t('updateLater')),
              ),
            if (apkUrl != null && pct < 0)
              FilledButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: Text(l10n.t('updateDownload')),
                onPressed: () async {
                  setInner(() => pct = 0);
                  final ok = await CurlDownloader.download(
                    apkUrl,
                    savePath,
                    onProgress: (p) {
                      if (cancelled.value) return;
                      setInner(() => pct = p);
                    },
                  );
                  if (cancelled.value) return;
                  if (!ok) {
                    setInner(() {
                      errorMsg = '下载失败（curl/HTTP 错误）';
                      pct = -1;
                    });
                    return;
                  }
                  setInner(() => pct = 101);
                  // Auto-install via the OS default installer.
                  try {
                    await CurlDownloader.installApk(savePath);
                  } catch (_) {}
                },
              ),
            if (pct >= 101)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('完成'),
              ),
          ],
        ),
      ),
    );
  }

  /// Default directory for downloads: `<notes folder>/download/`.
  Future<String> _defaultDownloadDir() async {
    final storage = StorageService.instance;
    if (storage.hasFolder) {
      return p.join(storage.currentFolder!, 'download');
    }
    // Fall back to a directory inside the app config dir.
    final cfgDir = await storage.configDir;
    return p.join(cfgDir.path, 'download');
  }

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    final storage = StorageService.instance;
    if (!storage.hasFolder || storage.currentFolderName == null) {
      _toast(l10n.t('repositoryNeedFolder'));
      return;
    }
    try {
      final bytes = await storage.buildFolderFneBytes();
      if (bytes == null) {
        _toast(l10n.t('repositoryNeedFolder'));
        return;
      }
      final fileName = '${storage.currentFolderName}_export.fne';
      final path = await FilePicker.saveFile(
        dialogTitle: l10n.t('exportData'),
        fileName: fileName,
        bytes: bytes,
      );
      if (path == null) return; // user cancelled
      // file_picker may append a platform extension (e.g. `.zip` on Windows);
      // normalize the saved file so it ends with `.fne`.
      var outPath = path;
      if (!outPath.toLowerCase().endsWith('.fne')) {
        final corrected = outPath.toLowerCase().endsWith('.zip')
            ? outPath.substring(0, outPath.length - 4)
            : '$outPath.fne';
        try {
          final old = File(outPath);
          outPath = old.existsSync()
              ? old.renameSync(corrected).path
              : corrected;
        } catch (_) {
          outPath = corrected;
        }
      }
      _toast(l10n.tArgs('exportSuccessFne', [p.basename(outPath)]));
    } catch (e) {
      _toast(l10n.tArgs('exportFailed', [e.toString()]));
    }
  }

  Future<void> _importData() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();
    final storage = StorageService.instance;
    if (!storage.hasFolder) {
      _toast(l10n.t('repositoryNeedFolder'));
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.t('importData')),
        content: Text(l10n.t('importOverwriteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(l10n.t('importData')),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fne'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _toast(l10n.tArgs('importFailed', ['no data']));
        return;
      }
      final count = await storage.importFolderFromFneBytes(bytes);
      await provider.reloadNotes();
      _toast(l10n.tArgs('importSuccessFne', ['$count']));
    } catch (e) {
      _toast(l10n.tArgs('importFailed', [e.toString()]));
    }
  }

  void _addModel() {
    final v = _aiModelAddController.text.trim();
    if (v.isEmpty) return;
    if (!_aiModels.contains(v)) {
      setState(() => _aiModels.add(v));
    }
    _aiModelAddController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<AppProvider>();
    final folder = provider.settings.notesFolderPath ?? l10n.t('notSet');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings')),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        children: [
          // Repository (notes folder)
          _sectionHeader(l10n.t('repository')),
          ListTile(
            leading: const Icon(Icons.folder_special),
            title: Text(l10n.t('currentRepository')),
            subtitle: Text(
              folder,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: TextButton(
              onPressed: _changeRepository,
              child: Text(l10n.t('changeRepository')),
            ),
          ),
          // Appearance
          _sectionHeader(l10n.t('appearance')),
          SwitchListTile(
            title: Text(l10n.t('darkMode')),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          // Theme color
          _sectionHeader(l10n.t('themeColor')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _colorCircle(
                  null,
                  l10n.t('default'),
                  isSelected: _themeColorHex == null,
                ),
                for (final c in _themeColors)
                  _colorCircle(
                    _hex(c),
                    null,
                    color: c,
                    isSelected: _themeColorHex == _hex(c),
                  ),
              ],
            ),
          ),
          // Language
          _sectionHeader(l10n.t('language')),
          RadioGroup<String>(
            groupValue: _language,
            onChanged: (v) => setState(() => _language = v!),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(l10n.t('followSystem')),
                  subtitle: Text(
                    _systemLocaleLabel(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: '',
                ),
                const RadioListTile<String>(
                  title: Text('English'),
                  value: 'en',
                ),
                const RadioListTile<String>(title: Text('中文'), value: 'zh'),
                const RadioListTile<String>(title: Text('日本語'), value: 'ja'),
              ],
            ),
          ),
          // Widgets (clipboard history cap)
          _sectionHeader(l10n.t('widgets')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _clipboardMaxController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.t('clipboardMax'),
                hintText: '1 – 99999',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // AI
          _sectionHeader(l10n.t('aiAssistant')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: _aiProvider,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.t('aiProvider'),
                border: const OutlineInputBorder(),
              ),
              items: context
                  .read<AppProvider>()
                  .settings
                  .aiEndpoints
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(_endpointLabel(e)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _aiProvider = v;
                  _syncKeysToProvider();
                  final ep = context
                      .read<AppProvider>()
                      .settings
                      .aiEndpoints
                      .firstWhere(
                        (e) => e.id == v,
                        orElse: () => context
                            .read<AppProvider>()
                            .settings
                            .aiEndpoints
                            .first,
                      );
                  final builtin = ep.builtinKey;
                  if (builtin != null) {
                    final current = _aiModelController.text.trim();
                    if (current.isEmpty ||
                        AIService.isKnownDefaultModel(current)) {
                      _aiModelController.text = AIService.defaultModelFor(
                        builtin,
                      );
                    }
                    if (_aiModels.isEmpty) {
                      _aiModels = [AIService.defaultModelFor(builtin)];
                    }
                  }
                });
              },
            ),
          ),
          if (!_builtinIds.contains(_aiProvider)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _aiBaseUrlController,
                decoration: InputDecoration(
                  labelText: l10n.t('baseUrl'),
                  border: const OutlineInputBorder(),
                  hintText: 'https://your-endpoint/v1',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // AI API keys — multi-key with fallback. The first row is what the
          // app tries first; subsequent rows are tried when the previous one
          // fails (auth / rate-limit). Empty rows are ignored.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.t('aiApiKey')}（多 Key 自动 fallback）',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: _showApiKey ? l10n.t('hide') : l10n.t('show'),
                      icon: Icon(
                        _showApiKey ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < _aiKeyControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aiKeyControllers[i],
                            obscureText: !_showApiKey,
                            decoration: InputDecoration(
                              labelText: i == 0 ? 'Key 1（主）' : 'Key ${i + 1}',
                              border: const OutlineInputBorder(),
                              hintText: 'sk-...',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeAiKey(i),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加 Key'),
                    onPressed: _addAiKey,
                  ),
                ),
                if (_aiKeyControllers.every((c) => c.text.trim().isEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                    child: Text(
                      l10n.t('aiBuiltInHint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Add / delete custom endpoints. Each call updates the persistent
          // endpoints list immediately so the dropdown always reflects the
          // current state.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('添加自定义 Provider'),
                  onPressed: _addCustomAiEndpoint,
                ),
                if (!_builtinIds.contains(_aiProvider))
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除当前 Provider'),
                    onPressed: _deleteCurrentCustomAiEndpoint,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _aiModelController,
              decoration: InputDecoration(
                labelText: l10n.t('defaultModel'),
                border: const OutlineInputBorder(),
                hintText: 'gpt-3.5-turbo',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('addedModels'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _aiModels.isEmpty
                      ? [
                          Text(
                            l10n.t('noAddedModels'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ]
                      : _aiModels
                            .map(
                              (m) => Chip(
                                label: Text(m),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () =>
                                    setState(() => _aiModels.remove(m)),
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiModelAddController,
                        decoration: InputDecoration(
                          labelText: l10n.t('addModel'),
                          border: const OutlineInputBorder(),
                          hintText: 'gpt-4o / deepseek-chat ...',
                        ),
                        onSubmitted: (_) => _addModel(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addModel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // GitHub is now configured from the GitHub Sync plugin (Plugins → gear).
          // Data backup — export/import the notes folder as a .fne archive.
          _sectionHeader(l10n.t('dataBackup')),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l10n.t('exportData')),
            subtitle: Text(l10n.t('exportHint')),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.t('importData')),
            subtitle: Text(l10n.t('importHint')),
            onTap: _importData,
          ),
          // About
          _sectionHeader(l10n.t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.t('appTitle')),
            subtitle: Text(l10n.t('aboutDesc')),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(l10n.t('reportIssue')),
            onTap: () => _openUrl(
              'https://github.com/IdentityVplayer/free-note/issues/new',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(l10n.t('checkUpdate')),
            onTap: _checkUpdate,
          ),
          // App info footer — version and CPU architecture.
          const SizedBox(height: 16),
          FutureBuilder<({String version, String arch})>(
            future: _loadAppInfo(),
            builder: (ctx, snap) {
              final v = snap.data?.version ?? '?';
              final arch = snap.data?.arch ?? '?';
              return Center(
                child: Text(
                  'v$v · $arch',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _colorCircle(
    String? hex,
    String? label, {
    Color? color,
    required bool isSelected,
  }) {
    final display = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => setState(() => _themeColorHex = hex),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: display,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white)
            : (label != null
                  ? Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null),
      ),
    );
  }

  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Human-readable label for the device's current locale, shown under the
  /// "Follow system" language option.
  String _systemLocaleLabel() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final code = locale.languageCode;
    const names = {'en': 'English', 'zh': '中文', 'ja': '日本語'};
    return names[code] ?? code.toUpperCase();
  }
}
