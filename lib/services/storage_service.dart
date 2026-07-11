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

  /// Test whether [path] is a real, writable directory by writing a tiny probe
  /// file and reading it back. Returns false on any failure (e.g. Android SAF
  /// tree URIs, missing permission). Used to validate a folder before we rely
  /// on it for note storage.
  Future<bool> probeWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final probe = File('${dir.path}/.wubianji_probe.tmp');
      probe.writeAsStringSync('ok');
      final read = probe.readAsStringSync();
      probe.deleteSync();
      return read == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<void> setFolder(String path) async {
    currentFolder = path;
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }

  // ── Notes: markdown files in the user folder (recursive) ──

  /// Load every `.md` file in the selected folder AND its subfolders.
  /// Notes keep their relative path so they are saved back in place.
  Future<List<Note>> loadNotes() async {
    if (!hasFolder) return [];
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) return [];
    final notes = <Note>[];
    final entities = dir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      final relative = p.relative(entity.path, from: dir.path);
      try {
        final content = entity.readAsStringSync();
        notes.add(Note.fromMarkdownFileOrAdopt(content, relative));
      } catch (_) {
        // Skip unreadable files.
      }
    }
    return notes;
  }

  Future<void> saveNotes(List<Note> notes) async {
    if (!hasFolder) return;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final written = <String>{};
    for (final note in notes) {
      final rel = note.relativePath ?? note.fileName;
      final file = File(p.join(dir.path, rel));
      try {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(note.toMarkdownFile());
        written.add(file.path);
      } catch (_) {
        // Skip notes we cannot write (e.g. permission revoked) rather than
        // aborting the whole save and losing everything else.
      }
    }
    // Remove orphaned app-managed note files (those whose name matches the
    // generated numeric id pattern) that are no longer in the list. We only
    // touch app-generated files so the user's own .md files (and adopted
    // files) are never auto-deleted.
    final managed = RegExp(r'^\d{10,}\.md$');
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!managed.hasMatch(p.basename(entity.path))) continue;
      if (written.contains(entity.path)) continue;
      try {
        entity.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> saveNote(Note note) async {
    if (!hasFolder) return;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final rel = note.relativePath ?? note.fileName;
    final file = File(p.join(dir.path, rel));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(note.toMarkdownFile());
  }

  /// Delete the on-disk file for a note, using its relative path when known.
  Future<void> deleteNoteFile(String relativePathOrFileName) async {
    if (!hasFolder) return;
    final file = File(p.join(currentFolder!, relativePathOrFileName));
    if (file.existsSync()) file.deleteSync();
  }

  /// Write a standalone markdown file (e.g. an exported AI chat) into the
  /// selected notes folder. Falls back to the private app dir when no folder
  /// is configured, so a save never silently disappears.
  Future<String> writeMarkdownFile(String fileName, String markdown) async {
    final Directory dir;
    if (hasFolder) {
      dir = Directory(currentFolder!);
    } else {
      dir = await _privateDir;
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, fileName));
    file.writeAsStringSync(markdown);
    return file.path;
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

  /// Export a single note as a standalone `.md` file into the **selected
  /// notes folder** (so it lands next to the user's other notes, not in a
  /// hidden `/data` path). Falls back to the private app dir when no folder
  /// is configured.
  Future<String> exportNoteAsMarkdown(Note note) async {
    final Directory dir;
    if (hasFolder) {
      dir = Directory(currentFolder!);
    } else {
      dir = await _privateDir;
    }
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final filename =
        '${note.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_')}.md';
    final file = File(p.join(dir.path, filename));
    file.writeAsStringSync(note.toMarkdownFile());
    return file.path;
  }
}
