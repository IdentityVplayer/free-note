import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
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
        aiModels: _aiModels.where((m) => m.trim().isNotEmpty).toList(),
      ),
    );
    Navigator.pop(context);
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
}
