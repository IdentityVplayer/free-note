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

  AppSettings({
    this.languageCode = 'en',
    this.isDarkMode = false,
    this.githubToken,
    this.githubRepo,
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.autoSync = false,
    this.enableAI = true,
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
  );
}
