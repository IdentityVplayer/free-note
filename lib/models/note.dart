import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Note data model for Borderless Notes app.
class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;
  bool isPinned;
  bool isFavorite;

  /// Relative path of this note inside the selected notes folder
  /// (e.g. "sub/dir/my-note.md"). null means the note lives at the top level.
  /// Used so notes keep their subdirectory when re-saved, and so the same
  /// file is updated in place across edits.
  String? relativePath;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.isFavorite = false,
    this.relativePath,
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

  factory Note.fromJson(Map<String, dynamic> json, [String? relativePath]) =>
      Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        isPinned: json['isPinned'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        relativePath: relativePath ?? json['relativePath'] as String?,
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
    String? relativePath,
  }) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tags: tags ?? this.tags,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    relativePath: relativePath ?? this.relativePath,
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
  static Note? fromMarkdownFile(String raw, [String? relativePath]) {
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
      return Note.fromJson(json, relativePath);
    } catch (_) {
      return null;
    }
  }

  /// Parse a `.md` file, adopting plain (frontmatter-less) markdown files as
  /// notes too. This lets the app recognize every `.md` file in the selected
  /// folder and its subfolders — not just files it created itself.
  ///
  /// [relativePath] is the file's path relative to the notes folder (used to
  /// keep the note in its subdirectory and to derive a stable id).
  static Note fromMarkdownFileOrAdopt(String raw, String relativePath) {
    final parsed = fromMarkdownFile(raw, relativePath);
    if (parsed != null) return parsed;

    final name = p.basenameWithoutExtension(relativePath);
    final id = _stableId(relativePath);
    return Note(
      id: id,
      title: name.isEmpty ? 'Untitled' : name,
      content: raw.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      relativePath: relativePath,
    );
  }

  /// Derive a stable id from a relative path so an adopted file keeps the same
  /// identity (and therefore maps to the same note) across reloads.
  static String _stableId(String relativePath) =>
      'adopted_${relativePath.hashCode.abs().toRadixString(36)}';

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
