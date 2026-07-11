import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../models/settings.dart';

/// Local storage service for persisting notes and settings to disk.
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  Directory? _dataDir;

  Future<Directory> get dataDir async {
    if (_dataDir != null) return _dataDir!;
    final dir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${dir.path}/free_note');
    if (!_dataDir!.existsSync()) {
      _dataDir!.createSync(recursive: true);
    }
    return _dataDir!;
  }

  // ---- Notes ----

  Future<List<Note>> loadNotes() async {
    final dir = await dataDir;
    final file = File('${dir.path}/notes.json');
    if (!file.existsSync()) return [];
    try {
      final json = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return json.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    final dir = await dataDir;
    final file = File('${dir.path}/notes.json');
    file.writeAsStringSync(jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  // ---- Settings ----

  Future<AppSettings> loadSettings() async {
    final dir = await dataDir;
    final file = File('${dir.path}/settings.json');
    if (!file.existsSync()) return AppSettings();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final dir = await dataDir;
    final file = File('${dir.path}/settings.json');
    file.writeAsStringSync(jsonEncode(settings.toJson()));
  }

  // ---- Export / Import ----

  Future<String> exportNoteAsMarkdown(Note note) async {
    final dir = await dataDir;
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) exportDir.createSync(recursive: true);
    final filename =
        '${note.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.md';
    final file = File('${exportDir.path}/$filename');
    final content =
        '''# ${note.title}

${note.content}

---
> Created: ${note.createdAt.toIso8601String()}
> Updated: ${note.updatedAt.toIso8601String()}
> Tags: ${note.tags.join(', ')}
''';
    file.writeAsStringSync(content);
    return file.path;
  }
}
