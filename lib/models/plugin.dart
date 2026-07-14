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

  const PluginInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    this.isEnabled = true,
    required this.type,
    this.hasSettings = false,
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
  );
}

enum PluginType { editor, exporter, importer, theme, utility }
