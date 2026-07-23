import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/github_sync_service.dart';
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
  late TextEditingController _aiApiKeyController;
  late TextEditingController _aiModelController;
  late TextEditingController _aiBaseUrlController;
  late String _language;
  late bool _darkMode;
  late String _aiProvider;
  late List<String> _aiModels;
  final TextEditingController _aiModelAddController = TextEditingController();
  String? _themeColorHex;

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
    final s = context.read<AppProvider>().settings;
    _aiApiKeyController = TextEditingController(text: s.aiApiKey ?? '');
    _aiModelController = TextEditingController(text: s.aiModel);
    _aiBaseUrlController = TextEditingController(text: s.aiBaseUrl ?? '');
    _language = s.languageCode;
    _darkMode = s.isDarkMode;
    _aiProvider = s.aiProvider;
    _aiModels = List<String>.from(s.aiModels);
    _themeColorHex = s.themeColorHex;
  }

  @override
  void dispose() {
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiBaseUrlController.dispose();
    _aiModelAddController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = context.read<AppProvider>();
    provider.updateSettings(
      AppSettings(
        languageCode: _language,
        isDarkMode: _darkMode,
        githubToken: provider.settings.githubToken,
        githubRepo: provider.settings.githubRepo,
        githubClientId: provider.settings.githubClientId,
        githubUsername: provider.settings.githubUsername,
        aiApiKey: _aiApiKeyController.text.trim(),
        aiModel: _aiModelController.text.trim(),
        autoSync: provider.settings.autoSync,
        enableAI: true,
        aiProvider: _aiProvider,
        aiBaseUrl: _aiBaseUrlController.text.trim().isEmpty
            ? null
            : _aiBaseUrlController.text.trim(),
        themeColorHex: _themeColorHex,
        notesFolderPath: provider.settings.notesFolderPath,
        repositories: provider.settings.repositories,
        aiModels: _aiModels.where((m) => m.trim().isNotEmpty).toList(),
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
      _showUpdateDialog(release);
    } else {
      _toast(l10n.t('upToDate'));
    }
  }

  void _showUpdateDialog(GitHubRelease release) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.t('updateAvailable')} (${release.tagName})'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: safeMarkdown(
              data: release.body.isEmpty ? release.tagName : release.body,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('updateLater')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(release.downloadUrl);
            },
            child: Text(l10n.t('updateDownload')),
          ),
        ],
      ),
    );
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
      _toast(l10n.tArgs('exportSuccessFne', [p.basename(path)]));
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
                const RadioListTile<String>(title: Text('English'), value: 'en'),
                const RadioListTile<String>(title: Text('中文'), value: 'zh'),
                const RadioListTile<String>(title: Text('日本語'), value: 'ja'),
              ],
            ),
          ),
          // AI
          _sectionHeader(l10n.t('aiAssistant')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: _aiProvider,
              decoration: InputDecoration(
                labelText: l10n.t('aiProvider'),
                border: const OutlineInputBorder(),
              ),
              items: AIProviderPresets.order
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(_providerLabel(p, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _aiProvider = v;
                  // Pick a sensible default model for the chosen provider so
                  // the feature works right after the user enters a key. Only
                  // overwrite when the current model is empty or one of the
                  // built-in defaults (don't clobber a model the user typed).
                  final current = _aiModelController.text.trim();
                  if (current.isEmpty ||
                      AIService.isKnownDefaultModel(current)) {
                    _aiModelController.text = AIService.defaultModelFor(v);
                  }
                  // Seed the model list with the provider default when empty.
                  if (_aiModels.isEmpty) {
                    _aiModels = [AIService.defaultModelFor(v)];
                  }
                });
              },
            ),
          ),
          if (_aiProvider == 'custom') ...[
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _aiApiKeyController,
              decoration: InputDecoration(
                labelText: l10n.t('aiApiKey'),
                border: const OutlineInputBorder(),
                hintText: 'sk-...',
              ),
              obscureText: true,
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _providerLabel(String p, dynamic l10n) {
    switch (p) {
      case 'openai':
        return 'OpenAI';
      case 'deepseek':
        return 'DeepSeek';
      case 'moonshot':
        return 'Moonshot (Kimi)';
      case 'google':
        return 'Google Gemini';
      case 'ollama':
        return 'Ollama (local)';
      case 'sealos':
        return 'Sealos AIProxy';
      case 'custom':
        return l10n.t('customProvider');
      default:
        return p;
    }
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
