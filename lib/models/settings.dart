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

  /// Extra AI models the user has added (beyond [aiModel]). Combined with
  /// [aiModel] to build the model picker shown in the AI chat screen.
  List<String> aiModels;

  AppSettings({
    this.languageCode = 'en',
    this.isDarkMode = false,
    this.githubToken,
    this.githubRepo,
    this.githubClientId,
    this.githubUsername,
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.autoSync = false,
    this.enableAI = true,
    this.aiProvider = 'openai',
    this.aiBaseUrl,
    this.themeColorHex,
    this.notesFolderPath,
    this.aiModels = const [],
  });

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'isDarkMode': isDarkMode,
    'githubToken': githubToken,
    'githubRepo': githubRepo,
    'githubClientId': githubClientId,
    'githubUsername': githubUsername,
    'aiApiKey': aiApiKey,
    'aiModel': aiModel,
    'autoSync': autoSync,
    'enableAI': enableAI,
    'aiProvider': aiProvider,
    'aiBaseUrl': aiBaseUrl,
    'themeColorHex': themeColorHex,
    'notesFolderPath': notesFolderPath,
    'aiModels': aiModels,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    languageCode: json['languageCode'] as String? ?? 'en',
    isDarkMode: json['isDarkMode'] as bool? ?? false,
    githubToken: json['githubToken'] as String?,
    githubRepo: json['githubRepo'] as String?,
    githubClientId: json['githubClientId'] as String?,
    githubUsername: json['githubUsername'] as String?,
    aiApiKey: json['aiApiKey'] as String?,
    aiModel: json['aiModel'] as String? ?? 'gpt-3.5-turbo',
    autoSync: json['autoSync'] as bool? ?? false,
    enableAI: json['enableAI'] as bool? ?? true,
    aiProvider: json['aiProvider'] as String? ?? 'openai',
    aiBaseUrl: json['aiBaseUrl'] as String?,
    themeColorHex: json['themeColorHex'] as String?,
    notesFolderPath: json['notesFolderPath'] as String?,
    aiModels: (json['aiModels'] as List<dynamic>?)?.cast<String>() ?? const [],
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
