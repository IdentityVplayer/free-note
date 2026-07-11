import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/settings.dart';

/// Settings screen — language, dark mode, AI config, GitHub config.
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
  late String _language;
  late bool _darkMode;
  late bool _autoSync;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppProvider>().settings;
    _githubTokenController = TextEditingController(text: s.githubToken ?? '');
    _githubRepoController = TextEditingController(text: s.githubRepo ?? '');
    _aiApiKeyController = TextEditingController(text: s.aiApiKey ?? '');
    _aiModelController = TextEditingController(text: s.aiModel);
    _language = s.languageCode;
    _darkMode = s.isDarkMode;
    _autoSync = s.autoSync;
  }

  @override
  void dispose() {
    _githubTokenController.dispose();
    _githubRepoController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
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
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings')),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        children: [
          // Appearance
          _sectionHeader(l10n.t('darkMode')),
          SwitchListTile(
            title: Text(l10n.t('darkMode')),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
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
                hintText: 'username/free-note-workbuddy',
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
