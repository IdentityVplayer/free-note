import 'package:yaml/yaml.dart';

/// Note data model for Free Note app.
class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;
  bool isPinned;
  bool isFavorite;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.isFavorite = false,
  });

  /// Convert to JSON for persistence and GitHub sync.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
    'isPinned': isPinned,
    'isFavorite': isFavorite,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    isPinned: json['isPinned'] as bool? ?? false,
    isFavorite: json['isFavorite'] as bool? ?? false,
  );

  /// Get a preview of the content (first 100 chars without markdown).
  String get preview {
    final plainText = content.replaceAll(RegExp(r'[#*`~\[\]()>_-]'), '').trim();
    return plainText.length > 100
        ? '${plainText.substring(0, 100)}...'
        : plainText;
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
  }) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tags: tags ?? this.tags,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  // ── Markdown file (frontmatter) serialization ──

  /// Serialize to a `.md` file with YAML frontmatter.
  String toMarkdownFile() {
    final meta = {
      'id': id,
      'title': title,
      'tags': tags,
      'pinned': isPinned,
      'favorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    final yamlStr = _frontmatterYaml(meta);
    return '---\n$yamlStr---\n\n$content\n';
  }

  /// Parse a `.md` file with YAML frontmatter.
  /// Returns null if the content has no frontmatter.
  static Note? fromMarkdownFile(String raw) {
    if (!raw.startsWith('---')) return null;
    final first = raw.indexOf('---');
    final second = raw.indexOf('---', first + 3);
    if (second == -1) return null;
    final yamlStr = raw.substring(first + 3, second).trim();
    final body = raw.substring(second + 3).trim();
    try {
      final map = loadYaml(yamlStr) as Map;
      final json = <String, dynamic>{};
      for (final entry in map.entries) {
        json[entry.key.toString()] = entry.value;
      }
      json['content'] = body;
      if (!json.containsKey('id')) return null;
      return Note.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Safe file name for this note (uses id to avoid collisions).
  String get fileName => '$id.md';

  /// Build a simple YAML frontmatter block from a map.
  static String _frontmatterYaml(Map<String, dynamic> meta) {
    final sb = StringBuffer();
    for (final entry in meta.entries) {
      final v = entry.value;
      if (v is List) {
        final items = v
            .map((e) => '"${e.toString().replaceAll('"', '\\"')}"')
            .join(', ');
        sb.writeln('${entry.key}: [$items]');
      } else if (v is String) {
        sb.writeln('${entry.key}: "${v.replaceAll('"', '\\"')}"');
      } else {
        sb.writeln('${entry.key}: $v');
      }
    }
    return sb.toString();
  }
}
