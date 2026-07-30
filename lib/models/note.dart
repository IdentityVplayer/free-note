import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Name of the auto-created "private" folder. Notes inside it (and any of its
/// subfolders) are NEVER uploaded to GitHub — they stay local only (v1.18.0).
const String privateNotesFolderName = '私人笔记';

/// True if [relativePath] lives inside the private folder (`私人笔记/`) or any
/// of its subfolders. This is the single, shared exclusion rule used by both
/// sync layers (the note upload loop in [GitHubSyncService] and the
/// extra-files scan in [AppProvider._readExtraFiles]) so they can never drift
/// apart (v1.18.0).
bool isPathPrivate(String relativePath) =>
    relativePath.split('/').contains(privateNotesFolderName);

/// Sanitize an arbitrary string into a safe, cross-platform file name.
///
/// Strips characters that are illegal on common file systems, collapses runs
/// of whitespace, trims, and caps length. Returns `'Untitled'` for empty
/// input. Used so a note's [Note.title] can become its on-disk file name.
String sanitizeFileName(String s) {
  var out = s.trim();
  // Illegal on Windows / macOS / Linux file systems.
  out = out.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '');
  // Collapse whitespace runs into a single space, then trim again.
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (out.isEmpty) return 'Untitled';
  // Cap length so deep paths stay within filesystem limits.
  if (out.length > 80) out = out.substring(0, 80).trim();
  if (out.isEmpty) return 'Untitled';
  return out;
}

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
    'relativePath': relativePath,
  };

  /// Serialize app-managed metadata into a `.config/<id>.json` entry.
  ///
  /// Note content lives in a *separate* `.md` file, so it is intentionally
  /// NOT included here — this keeps the markdown body clean (no frontmatter).
  Map<String, dynamic> toConfigJson() => {
    'id': id,
    'title': title,
    'tags': tags,
    'pinned': isPinned,
    'favorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'relativePath': relativePath,
  };

  /// Build a Note from a `.config/<id>.json` entry plus the note's markdown
  /// content (read separately from the `.md` file on disk).
  factory Note.fromConfigJson(Map<String, dynamic> json, String content) =>
      Note(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        content: content,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        isPinned: json['pinned'] as bool? ?? false,
        isFavorite: json['favorite'] as bool? ?? false,
        relativePath: json['relativePath'] as String?,
      );

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

  /// Safe file name for this note, derived from its [title] (title → file
  /// name). The actual on-disk path is [relativePath], which prefixes this
  /// with a subfolder when the note lives inside one. Two notes sharing a
  /// title collide on disk only if they live in the same folder — the storage
  /// layer appends a ` (n)` suffix to keep files unique (v1.18.0).
  String get fileName => '${sanitizeFileName(title)}.md';

  /// True if this note lives inside the private folder (`私人笔记/`) or any of
  /// its subfolders. Private notes are never uploaded to GitHub.
  bool get isPrivate => isPathPrivate(relativePath ?? fileName);

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
