import 'dart:convert';

import 'plugin.dart';

/// User-defined AI endpoint (a single base URL + ordered list of API keys
/// used as a fallback chain on auth / rate-limit failures). Built-in providers
/// are also represented as [AiEndpoint] entries internally so the runtime /
/// settings UI only deals with one shape (v1.17.0).
class AiEndpoint {
  /// Stable id (built-in key like `openai` or `custom:<uuid>`).
  String id;
  String label;
  String? baseUrl; // null = use the built-in preset URL
  List<String> keys; // ordered: index 0 tried first, then 1, …
  String? builtinKey; // non-null if this is a built-in preset shortcut

  AiEndpoint({
    required this.id,
    required this.label,
    this.baseUrl,
    List<String>? keys,
    this.builtinKey,
  }) : keys = keys ?? <String>[];

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'baseUrl': baseUrl,
    'keys': keys,
    'builtinKey': builtinKey,
  };

  factory AiEndpoint.fromJson(Map<String, dynamic> json) => AiEndpoint(
    id: json['id'] as String,
    label: (json['label'] as String?) ?? json['id'] as String,
    baseUrl: json['baseUrl'] as String?,
    keys: ((json['keys'] as List<dynamic>?) ?? const [])
        .cast<String>()
        .map((s) => AppSettings.decodeSecret(s) ?? '')
        .where((s) => s.isNotEmpty)
        .toList(),
    builtinKey: json['builtinKey'] as String?,
  );

  AiEndpoint copyWith({String? label, String? baseUrl, List<String>? keys}) =>
      AiEndpoint(
        id: id,
        label: label ?? this.label,
        baseUrl: baseUrl ?? this.baseUrl,
        keys: keys ?? this.keys,
        builtinKey: builtinKey,
      );
}

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

  String aiModel;
  bool autoSync;
  bool enableAI;

  // ── AI provider model (v1.17.0 redesign) ──
  /// Every AI endpoint the user has configured, built-in or custom. The
  /// currently active one is [currentAiId]; its keys are tried in order on
  /// failure. The user can add any number of custom endpoints via the
  /// settings UI ("+ add provider").
  List<AiEndpoint> aiEndpoints;
  String currentAiId; // = id of the active endpoint

  // ── Legacy fields (kept for backward-compatible JSON migration only) ──
  /// (Legacy single-key / single-provider fields are migrated in [fromJson]
  ///  on load; they aren't stored on the runtime instance.)
  // @deprecated Since v1.17.0, single-key was replaced by [aiEndpoints].

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

  AppSettings({
    this.languageCode = '',
    this.isDarkMode = false,
    this.githubToken,
    this.githubRepo,
    this.githubClientId,
    this.githubUsername,
    this.githubSyncMode = 'device',
    this.aiModel = 'openrouter/free',
    this.autoSync = false,
    this.enableAI = true,
    List<AiEndpoint>? aiEndpoints,
    this.currentAiId = 'openrouter',
    this.themeColorHex,
    this.notesFolderPath,
    this.repositories = const [],
    this.aiModels = const [],
    this.userPlugins = const [],
  }) : aiEndpoints = aiEndpoints ?? _defaultEndpoints();

  /// Sensible default if no endpoints have been configured yet (first launch
  /// or fresh install). Lists the built-in presets so the user just has to
  /// fill in keys.
  static List<AiEndpoint> _defaultEndpoints() => [
    for (final id in AIProviderPresets.order.where((p) => p != 'custom'))
      AiEndpoint(id: id, label: AIProviderPresets.labelFor(id), builtinKey: id),
  ];

  /// Obfuscate a secret (API key / token) with base64 before persisting.
  /// A `b64:` prefix marks encoded values so plaintext (legacy) settings are
  /// still read back unchanged (backward compatible). Secrets are persisted in
  /// a dedicated `.config/secrets.json` (see [StorageService]), never inside
  /// `settings.json`, so they are isolated from the rest of the config.
  static String? encodeSecret(String? v) {
    if (v == null || v.isEmpty) return v;
    return 'b64:${base64Encode(utf8.encode(v))}';
  }

  /// Reverse [encodeSecret]; returns the value as-is if not encoded.
  static String? decodeSecret(String? v) {
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
    'githubRepo': githubRepo,
    'githubClientId': githubClientId,
    'githubUsername': githubUsername,
    'githubSyncMode': githubSyncMode,
    'aiModel': aiModel,
    'autoSync': autoSync,
    'enableAI': enableAI,
    'aiEndpoints': aiEndpoints
        .map((e) => {...e.toJson(), 'keys': e.keys.map(encodeSecret).toList()})
        .toList(),
    'currentAiId': currentAiId,
    'themeColorHex': themeColorHex,
    'notesFolderPath': notesFolderPath,
    'repositories': repositories,
    'aiModels': aiModels,
    'userPlugins': userPlugins.map((p) => p.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final endpoints = <AiEndpoint>[];

    // v1.17.0+: read endpoints directly.
    final rawList = json['aiEndpoints'];
    if (rawList is List && rawList.isNotEmpty) {
      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          endpoints.add(AiEndpoint.fromJson(raw));
        }
      }
    }

    // Migration from v1.16 single-key settings.
    if (endpoints.isEmpty) {
      final legacyProvider = (json['aiProvider'] as String?) ?? 'openrouter';
      final legacyKey = decodeSecret(json['aiApiKey'] as String?);
      final legacyBase = json['aiBaseUrl'] as String?;
      if (legacyProvider == 'custom' &&
          legacyBase != null &&
          legacyBase.isNotEmpty) {
        endpoints.add(
          AiEndpoint(
            id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
            label: 'Custom',
            baseUrl: legacyBase,
            keys: legacyKey == null || legacyKey.isEmpty
                ? <String>[]
                : <String>[legacyKey],
          ),
        );
      } else {
        endpoints.add(
          AiEndpoint(
            id: legacyProvider,
            label: AIProviderPresets.labelFor(legacyProvider),
            builtinKey: legacyProvider,
            keys: legacyKey == null || legacyKey.isEmpty
                ? <String>[]
                : <String>[legacyKey],
          ),
        );
      }
    }

    // Always make sure all built-in presets exist so the dropdown is complete.
    for (final id in AIProviderPresets.order) {
      if (id == 'custom') continue;
      if (!endpoints.any((e) => e.id == id)) {
        endpoints.insert(
          0,
          AiEndpoint(
            id: id,
            label: AIProviderPresets.labelFor(id),
            builtinKey: id,
          ),
        );
      }
    }

    return AppSettings(
      languageCode: json['languageCode'] as String? ?? '',
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      // Secrets may still be present in a legacy settings.json; read them so
      // StorageService can migrate them into `.config/secrets.json`.
      githubToken: decodeSecret(json['githubToken'] as String?),
      githubRepo: json['githubRepo'] as String?,
      githubClientId: json['githubClientId'] as String?,
      githubUsername: json['githubUsername'] as String?,
      githubSyncMode: json['githubSyncMode'] as String? ?? 'device',
      aiModel: json['aiModel'] as String? ?? 'gpt-3.5-turbo',
      autoSync: json['autoSync'] as bool? ?? false,
      enableAI: json['enableAI'] as bool? ?? true,
      aiEndpoints: endpoints,
      currentAiId:
          (json['currentAiId'] as String?) ??
          ((json['aiProvider'] as String?) ?? 'openrouter'),
      themeColorHex: json['themeColorHex'] as String?,
      notesFolderPath: json['notesFolderPath'] as String?,
      repositories:
          (json['repositories'] as List<dynamic>?)?.cast<String>() ?? const [],
      aiModels:
          (json['aiModels'] as List<dynamic>?)?.cast<String>() ?? const [],
      userPlugins:
          (json['userPlugins'] as List<dynamic>?)
              ?.map((e) => PluginInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Immutable update helper used by toggles in the settings UI.
  AppSettings copyWith({
    String? languageCode,
    bool? isDarkMode,
    String? githubToken,
    String? githubRepo,
    String? githubClientId,
    String? githubUsername,
    String? githubSyncMode,
    String? aiModel,
    bool? autoSync,
    bool? enableAI,
    List<AiEndpoint>? aiEndpoints,
    String? currentAiId,
    String? themeColorHex,
    String? notesFolderPath,
    List<String>? repositories,
    List<String>? aiModels,
    List<PluginInfo>? userPlugins,
  }) => AppSettings(
    languageCode: languageCode ?? this.languageCode,
    isDarkMode: isDarkMode ?? this.isDarkMode,
    githubToken: githubToken ?? this.githubToken,
    githubRepo: githubRepo ?? this.githubRepo,
    githubClientId: githubClientId ?? this.githubClientId,
    githubUsername: githubUsername ?? this.githubUsername,
    githubSyncMode: githubSyncMode ?? this.githubSyncMode,
    aiModel: aiModel ?? this.aiModel,
    autoSync: autoSync ?? this.autoSync,
    enableAI: enableAI ?? this.enableAI,
    aiEndpoints: aiEndpoints ?? this.aiEndpoints,
    currentAiId: currentAiId ?? this.currentAiId,
    themeColorHex: themeColorHex ?? this.themeColorHex,
    notesFolderPath: notesFolderPath ?? this.notesFolderPath,
    repositories: repositories ?? this.repositories,
    aiModels: aiModels ?? this.aiModels,
    userPlugins: userPlugins ?? this.userPlugins,
  );

  /// The currently-active [AiEndpoint].
  AiEndpoint get currentEndpoint {
    for (final e in aiEndpoints) {
      if (e.id == currentAiId) return e;
    }
    return aiEndpoints.first;
  }

  /// Resolve the effective base URL for the active endpoint.
  String get resolvedAiBaseUrl {
    final ep = currentEndpoint;
    if (ep.baseUrl != null && ep.baseUrl!.isNotEmpty) return ep.baseUrl!;
    final bk = ep.builtinKey;
    if (bk != null) return AIProviderPresets.baseUrlFor(bk);
    return AIProviderPresets.baseUrlFor('openai');
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
    'openrouter': 'https://openrouter.ai/api/v1',
    'huggingface': 'https://router.huggingface.co/v1',
    'custom': '',
  };

  static const List<String> order = [
    'openai',
    'deepseek',
    'moonshot',
    'google',
    'ollama',
    'sealos',
    'openrouter',
    'huggingface',
    'custom',
  ];

  static String baseUrlFor(String provider) =>
      presets[provider] ?? presets['openai']!;

  /// Some providers (e.g. Ollama) don't require a key.
  static bool needsApiKey(String provider) => provider != 'ollama';

  /// Human-readable label for a provider — kept here so settings UI and AI
  /// assistant share a single source of truth. Locale-insensitive; the i18n
  /// layer can override if/when needed.
  static String labelFor(String provider) {
    switch (provider) {
      case 'openai':
        return 'OpenAI';
      case 'deepseek':
        return 'DeepSeek';
      case 'moonshot':
        return 'Moonshot';
      case 'google':
        return 'Google Gemini';
      case 'ollama':
        return 'Ollama (本地)';
      case 'sealos':
        return 'Sealos';
      case 'openrouter':
        return 'OpenRouter';
      case 'huggingface':
        return 'Hugging Face';
      case 'custom':
        return 'Custom';
      default:
        return provider;
    }
  }
}
