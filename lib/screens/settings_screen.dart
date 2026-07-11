import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/settings.dart';

/// Settings screen — folder, language, dark mode, theme color, AI config, GitHub config.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _githubTokenController;
  late TextEditingController _githubRepoController;
  late TextEditingController _aiApiKeyController;
  late TextEditingController _aiModelController;
  late TextEditingController _aiBaseUrlController;
  late String _language;
  late bool _darkMode;
  late bool _autoSync;
  late String _aiProvider;
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
    _githubTokenController = TextEditingController(text: s.githubToken ?? '');
    _githubRepoController = TextEditingController(text: s.githubRepo ?? '');
    _aiApiKeyController = TextEditingController(text: s.aiApiKey ?? '');
    _aiModelController = TextEditingController(text: s.aiModel);
    _aiBaseUrlController = TextEditingController(text: s.aiBaseUrl ?? '');
    _language = s.languageCode;
    _darkMode = s.isDarkMode;
    _autoSync = s.autoSync;
    _aiProvider = s.aiProvider;
    _themeColorHex = s.themeColorHex;
  }

  @override
  void dispose() {
    _githubTokenController.dispose();
    _githubRepoController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiBaseUrlController.dispose();
    super.dispose();
  }

  void _save() {
    final provider = context.read<AppProvider>();
    provider.updateSettings(
      AppSettings(
        languageCode: _language,
        isDarkMode: _darkMode,
        githubToken: _githubTokenController.text.trim(),
        githubRepo: _githubRepoController.text.trim(),
        aiApiKey: _aiApiKeyController.text.trim(),
        aiModel: _aiModelController.text.trim(),
        autoSync: _autoSync,
        enableAI: true,
        aiProvider: _aiProvider,
        aiBaseUrl: _aiBaseUrlController.text.trim().isEmpty
            ? null
            : _aiBaseUrlController.text.trim(),
        themeColorHex: _themeColorHex,
        notesFolderPath: provider.settings.notesFolderPath,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _changeFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null && mounted) {
      await context.read<AppProvider>().chooseFolder(path);
      setState(() {});
    }
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
          // Folder
          _sectionHeader(l10n.t('notesFolder')),
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(l10n.t('currentFolder')),
            subtitle: Text(
              folder,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: TextButton(
              onPressed: _changeFolder,
              child: Text(l10n.t('changeFolder')),
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
            child: const Column(
              children: [
                RadioListTile<String>(title: Text('English'), value: 'en'),
                RadioListTile<String>(title: Text('中文'), value: 'zh'),
                RadioListTile<String>(title: Text('日本語'), value: 'ja'),
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
              onChanged: (v) => setState(() => _aiProvider = v!),
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
                labelText: l10n.t('aiModel'),
                border: const OutlineInputBorder(),
                hintText: 'gpt-3.5-turbo',
              ),
            ),
          ),
          // GitHub
          _sectionHeader(l10n.t('githubSync')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _githubTokenController,
              decoration: InputDecoration(
                labelText: l10n.t('githubToken'),
                border: const OutlineInputBorder(),
                hintText: 'ghp_...',
              ),
              obscureText: true,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _githubRepoController,
              decoration: InputDecoration(
                labelText: l10n.t('githubRepo'),
                border: const OutlineInputBorder(),
                hintText: 'username/free--note',
              ),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.t('autoSync')),
            value: _autoSync,
            onChanged: (v) => setState(() => _autoSync = v),
          ),
          // About
          _sectionHeader(l10n.t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.t('appTitle')),
            subtitle: Text(l10n.t('aboutDesc')),
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
}
