/// Plugin model representing an extensible plugin in Free Note.
class PluginInfo {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final bool isEnabled;
  final PluginType type;
  final bool hasSettings;

  /// Optional insert text for user ("editor"-type) plugins. When set, the
  /// plugin renders a real toolbar button in the editor that inserts this
  /// snippet at the caret. null for plugins that carry no snippet.
  final String? snippet;

  const PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    this.isEnabled = true,
    required this.type,
    this.hasSettings = false,
    this.snippet,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'isEnabled': isEnabled,
    'type': type.name,
    'hasSettings': hasSettings,
    'snippet': snippet,
  };

  factory PluginInfo.fromJson(Map<String, dynamic> json) => PluginInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    version: json['version'] as String,
    author: json['author'] as String,
    isEnabled: json['isEnabled'] as bool? ?? true,
    type: PluginType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => PluginType.utility,
    ),
    hasSettings: json['hasSettings'] as bool? ?? false,
    snippet: json['snippet'] as String?,
  );
}

enum PluginType { editor, exporter, importer, theme, utility }
