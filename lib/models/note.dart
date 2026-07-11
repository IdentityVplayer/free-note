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
}
