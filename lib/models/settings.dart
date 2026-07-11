/// App settings model.
class AppSettings {
  String languageCode;
  bool isDarkMode;
  String? githubToken;
  String? githubRepo;
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

  AppSettings({
    this.languageCode = 'en',
    this.isDarkMode = false,
    this.githubToken,
    this.githubRepo,
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.autoSync = false,
    this.enableAI = true,
    this.aiProvider = 'openai',
    this.aiBaseUrl,
    this.themeColorHex,
    this.notesFolderPath,
  });

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'isDarkMode': isDarkMode,
    'githubToken': githubToken,
    'githubRepo': githubRepo,
    'aiApiKey': aiApiKey,
    'aiModel': aiModel,
    'autoSync': autoSync,
    'enableAI': enableAI,
    'aiProvider': aiProvider,
    'aiBaseUrl': aiBaseUrl,
    'themeColorHex': themeColorHex,
    'notesFolderPath': notesFolderPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    languageCode: json['languageCode'] as String? ?? 'en',
    isDarkMode: json['isDarkMode'] as bool? ?? false,
    githubToken: json['githubToken'] as String?,
    githubRepo: json['githubRepo'] as String?,
    aiApiKey: json['aiApiKey'] as String?,
    aiModel: json['aiModel'] as String? ?? 'gpt-3.5-turbo',
    autoSync: json['autoSync'] as bool? ?? false,
    enableAI: json['enableAI'] as bool? ?? true,
    aiProvider: json['aiProvider'] as String? ?? 'openai',
    aiBaseUrl: json['aiBaseUrl'] as String?,
    themeColorHex: json['themeColorHex'] as String?,
    notesFolderPath: json['notesFolderPath'] as String?,
  );

  /// Resolve the effective base URL from provider preset or custom value.
  String get resolvedAiBaseUrl {
    if (aiProvider == 'custom' && aiBaseUrl != null && aiBaseUrl!.isNotEmpty) {
      return aiBaseUrl!;
    }
    return AIProviderPresets.baseUrlFor(aiProvider);
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
    'custom': '',
  };

  static const List<String> order = [
    'openai',
    'deepseek',
    'moonshot',
    'google',
    'ollama',
    'custom',
  ];

  static String baseUrlFor(String provider) =>
      presets[provider] ?? presets['openai']!;

  /// Some providers (e.g. Ollama, Google) don't require a key.
  static bool needsApiKey(String provider) => provider != 'ollama';
}
