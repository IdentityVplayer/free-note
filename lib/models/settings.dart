import 'dart:convert';

import 'plugin.dart';

/// App settings model.
class AppSettings {
  String languageCode;
  bool isDarkMode;
  String? githubToken;
  String? githubRepo;

  /// OAuth App client_id used for the GitHub Device login flow. null = use
  /// [GitHubSyncService.defaultClientId].
  String? githubClientId;

  /// Login name of the authenticated GitHub user (filled after Device login).
  String? githubUsername;

  /// GitHub Sync login mode: 'device' (OAuth Device flow) or 'token'
  /// (paste a Personal Access Token). Persisted so the settings UI can show
  /// the right input on reopen.
  String githubSyncMode;

  String? aiApiKey;
  String aiModel;
  bool autoSync;
  bool enableAI;

  // ── New in 1.1.0 ──
  /// Selected AI provider key, e.g. 'openai', 'deepseek', 'custom'.
  String aiProvider;

  /// Custom base URL when aiProvider == 'custom'.
  String? aiBaseUrl;

  /// Hex string theme color, e.g. '#6750A4'. null = default.
  String? themeColorHex;

  /// User-selected notes folder (absolute path). null = not chosen yet.
  String? notesFolderPath;

  /// All repositories (folders) the user has opened, so they can be switched
  /// between from Settings without re-picking each time. The current one is
  /// [notesFolderPath].
  List<String> repositories;

  /// Extra AI models the user has added (beyond [aiModel]). Combined with
  /// [aiModel] to build the model picker shown in the AI chat screen.
  List<String> aiModels;

  // ── New in 1.9.8 ──
  /// Plugins the user added at runtime from the Plugins screen's "+" button.
  /// Persisted as [PluginInfo] so they can be re-registered on next launch.
  List<PluginInfo> userPlugins;

  // ── New in 1.12.0 ──
  /// When true, completing every subtask of a main task automatically marks
  /// the main task itself done.
  bool autoCompleteMainTasks;

  AppSettings({
    this.languageCode = '',
    this.isDarkMode = false,
    this.githubToken,
    this.githubRepo,
    this.githubClientId,
    this.githubUsername,
    this.githubSyncMode = 'device',
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.autoSync = false,
    this.enableAI = true,
    this.aiProvider = 'openai',
    this.aiBaseUrl,
    this.themeColorHex,
    this.notesFolderPath,
    this.repositories = const [],
    this.aiModels = const [],
    this.userPlugins = const [],
    this.autoCompleteMainTasks = false,
  });

  /// Obfuscate a secret (API key / token) with base64 before persisting.
  /// A `b64:` prefix marks encoded values so plaintext (legacy) settings are
  /// still read back unchanged (backward compatible).
  static String? _encodeSecret(String? v) {
    if (v == null || v.isEmpty) return v;
    return 'b64:${base64Encode(utf8.encode(v))}';
  }

  /// Reverse [_encodeSecret]; returns the value as-is if not encoded.
  static String? _decodeSecret(String? v) {
    if (v == null || v.isEmpty || !v.startsWith('b64:')) return v;
    try {
      return utf8.decode(base64Decode(v.substring(4)));
    } catch (_) {
      return v;
    }
  }

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'isDarkMode': isDarkMode,
    'githubToken': _encodeSecret(githubToken),
    'githubRepo': githubRepo,
    'githubClientId': githubClientId,
    'githubUsername': githubUsername,
    'githubSyncMode': githubSyncMode,
    'aiApiKey': _encodeSecret(aiApiKey),
    'aiModel': aiModel,
    'autoSync': autoSync,
    'enableAI': enableAI,
    'aiProvider': aiProvider,
    'aiBaseUrl': aiBaseUrl,
    'themeColorHex': themeColorHex,
    'notesFolderPath': notesFolderPath,
    'repositories': repositories,
    'aiModels': aiModels,
    'userPlugins': userPlugins.map((p) => p.toJson()).toList(),
    'autoCompleteMainTasks': autoCompleteMainTasks,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    languageCode: json['languageCode'] as String? ?? '',
    isDarkMode: json['isDarkMode'] as bool? ?? false,
    githubToken: _decodeSecret(json['githubToken'] as String?),
    githubRepo: json['githubRepo'] as String?,
    githubClientId: json['githubClientId'] as String?,
    githubUsername: json['githubUsername'] as String?,
    githubSyncMode: json['githubSyncMode'] as String? ?? 'device',
    aiApiKey: _decodeSecret(json['aiApiKey'] as String?),
    aiModel: json['aiModel'] as String? ?? 'gpt-3.5-turbo',
    autoSync: json['autoSync'] as bool? ?? false,
    enableAI: json['enableAI'] as bool? ?? true,
    aiProvider: json['aiProvider'] as String? ?? 'openai',
    aiBaseUrl: json['aiBaseUrl'] as String?,
    themeColorHex: json['themeColorHex'] as String?,
    notesFolderPath: json['notesFolderPath'] as String?,
    repositories:
        (json['repositories'] as List<dynamic>?)?.cast<String>() ?? const [],
    aiModels: (json['aiModels'] as List<dynamic>?)?.cast<String>() ?? const [],
    userPlugins:
        (json['userPlugins'] as List<dynamic>?)
            ?.map((e) => PluginInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    autoCompleteMainTasks: json['autoCompleteMainTasks'] as bool? ?? false,
  );

  /// Immutable update helper used by toggles in the settings UI.
  AppSettings copyWith({
    String? languageCode,
    bool? isDarkMode,
    String? githubToken,
    String? githubRepo,
    String? githubClientId,
    String? githubUsername,
    String? githubSyncMode,
    String? aiApiKey,
    String? aiModel,
    bool? autoSync,
    bool? enableAI,
    String? aiProvider,
    String? aiBaseUrl,
    String? themeColorHex,
    String? notesFolderPath,
    List<String>? repositories,
    List<String>? aiModels,
    List<PluginInfo>? userPlugins,
    bool? autoCompleteMainTasks,
  }) => AppSettings(
    languageCode: languageCode ?? this.languageCode,
    isDarkMode: isDarkMode ?? this.isDarkMode,
    githubToken: githubToken ?? this.githubToken,
    githubRepo: githubRepo ?? this.githubRepo,
    githubClientId: githubClientId ?? this.githubClientId,
    githubUsername: githubUsername ?? this.githubUsername,
    githubSyncMode: githubSyncMode ?? this.githubSyncMode,
    aiApiKey: aiApiKey ?? this.aiApiKey,
    aiModel: aiModel ?? this.aiModel,
    autoSync: autoSync ?? this.autoSync,
    enableAI: enableAI ?? this.enableAI,
    aiProvider: aiProvider ?? this.aiProvider,
    aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
    themeColorHex: themeColorHex ?? this.themeColorHex,
    notesFolderPath: notesFolderPath ?? this.notesFolderPath,
    repositories: repositories ?? this.repositories,
    aiModels: aiModels ?? this.aiModels,
    userPlugins: userPlugins ?? this.userPlugins,
    autoCompleteMainTasks: autoCompleteMainTasks ?? this.autoCompleteMainTasks,
  );

  /// Resolve the effective base URL from provider preset or custom value.
  String get resolvedAiBaseUrl {
    if (aiProvider == 'custom' && aiBaseUrl != null && aiBaseUrl!.isNotEmpty) {
      return aiBaseUrl!;
    }
    return AIProviderPresets.baseUrlFor(aiProvider);
  }

  /// All selectable models: the default model plus any the user added,
  /// de-duplicated and with empty entries removed. Used to build the model
  /// picker in the AI chat screen.
  List<String> get allModels {
    final set = <String>{};
    if (aiModel.isNotEmpty) set.add(aiModel);
    for (final m in aiModels) {
      if (m.isNotEmpty) set.add(m);
    }
    return set.toList();
  }
}

/// Built-in AI provider presets.
class AIProviderPresets {
  static const Map<String, String> presets = {
    'openai': 'https://api.openai.com/v1',
    'deepseek': 'https://api.deepseek.com/v1',
    'moonshot': 'https://api.moonshot.cn/v1',
    'google': 'https://generativelanguage.googleapis.com/v1beta/openai',
    'ollama': 'http://localhost:11434/v1',
    'sealos': 'https://aiproxy.hzh.sealos.run/v1',
    'custom': '',
  };

  static const List<String> order = [
    'openai',
    'deepseek',
    'moonshot',
    'google',
    'ollama',
    'sealos',
    'custom',
  ];

  static String baseUrlFor(String provider) =>
      presets[provider] ?? presets['openai']!;

  /// Some providers (e.g. Ollama, Google) don't require a key.
  static bool needsApiKey(String provider) => provider != 'ollama';
}
