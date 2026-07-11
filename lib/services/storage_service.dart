import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../models/settings.dart';

/// Local storage service.
///
/// Two storage areas:
///  - **Private app dir**: settings.json (tokens, config) — never user-facing.
///  - **User-selected notes folder**: each note is a standalone `.md` file with
///    YAML frontmatter, so users can manage / edit them with any tool.
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  Directory? _appDir;
  String? currentFolder;

  Future<Directory> get _privateDir async {
    if (_appDir != null) return _appDir!;
    final dir = await getApplicationDocumentsDirectory();
    _appDir = Directory('${dir.path}/free_note');
    if (!_appDir!.existsSync()) _appDir!.createSync(recursive: true);
    return _appDir!;
  }

  bool get hasFolder => currentFolder != null && currentFolder!.isNotEmpty;

  Future<void> setFolder(String path) async {
    currentFolder = path;
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  // ── Notes: markdown files in the user folder ──

  Future<List<Note>> loadNotes() async {
    if (!hasFolder) return [];
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) return [];
    final notes = <Note>[];
    final files = dir.listSync().whereType<File>();
    for (final f in files) {
      if (!f.path.endsWith('.md')) continue;
      try {
        final note = Note.fromMarkdownFile(f.readAsStringSync());
        if (note != null) notes.add(note);
      } catch (_) {
        // Skip unreadable / non-note markdown files.
      }
    }
    return notes;
  }

  Future<void> saveNotes(List<Note> notes) async {
    if (!hasFolder) return;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final keep = <String>{};
    for (final note in notes) {
      final file = File(p.join(dir.path, note.fileName));
      file.writeAsStringSync(note.toMarkdownFile());
      keep.add(note.fileName);
    }
    // Remove orphaned .md files no longer in the list.
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.md') && !keep.contains(p.basename(f.path))) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> saveNote(Note note) async {
    if (!hasFolder) return;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, note.fileName));
    file.writeAsStringSync(note.toMarkdownFile());
  }

  Future<void> deleteNoteFile(String id) async {
    if (!hasFolder) return;
    final file = File(p.join(currentFolder!, '$id.md'));
    if (file.existsSync()) file.deleteSync();
  }

  // ── Settings: private app dir ──

  Future<AppSettings> loadSettings() async {
    final dir = await _privateDir;
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
    final dir = await _privateDir;
    final file = File('${dir.path}/settings.json');
    file.writeAsStringSync(jsonEncode(settings.toJson()));
  }

  // ── Export ──

  Future<String> exportNoteAsMarkdown(Note note) async {
    final dir = await _privateDir;
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) exportDir.createSync(recursive: true);
    final filename =
        '${note.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.md';
    final file = File('${exportDir.path}/$filename');
    file.writeAsStringSync(note.toMarkdownFile());
    return file.path;
  }
}
