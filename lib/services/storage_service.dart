import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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
  //
  // Storage model: the note *content* lives in a standalone `.md` file, while
  // its *metadata* (title, tags, pinned, favorite, timestamps, relativePath)
  // lives in a sibling `.config/<id>.json` file. This keeps the markdown body
  // clean — no YAML frontmatter at the top of the text — and groups all app
  // config under one hidden `.config` directory.

  /// Path of the `.config` directory (created on demand). Falls back to the
  /// private app dir when no notes folder is configured.
  Future<String> get _configDirPath async {
    final base = hasFolder ? currentFolder! : (await _privateDir).path;
    final dir = p.join(base, '.config');
    if (!Directory(dir).existsSync()) {
      Directory(dir).createSync(recursive: true);
    }
    return dir;
  }

  /// Public, awaitable config directory — used for settings.json, tasks.json,
  /// pomodoro.json, etc. So all app config travels with the selected
  /// repository (resides in `<repo>/.config`) and is portable.
  Future<Directory> get configDir async => Directory(await _configDirPath);

  /// One-time migration: move [fileName] from the legacy private app dir
  /// (`free_note/`) into the current config dir. No-op when already present
  /// in the config dir or absent from the private dir. Used so existing users
  /// (whose config lived in the private dir) get their files moved into the
  /// repository's `.config` on first launch after the change.
  Future<void> migrateFileFromPrivate(String fileName) async {
    final cfg = Directory(await _configDirPath);
    final target = File(p.join(cfg.path, fileName));
    if (target.existsSync()) return;
    final src = File(p.join((await _privateDir).path, 'free_note', fileName));
    if (!src.existsSync()) return;
    try {
      src.copySync(target.path);
      src.deleteSync();
    } catch (_) {
      // best-effort; if it fails we just keep the legacy copy.
    }
  }

  /// Load every note in the selected folder AND its subfolders.
  ///
  /// 1. Notes with a `.config/<id>.json` entry are authoritative: their
  ///    content is read from the matching `.md` file by `relativePath`.
  /// 2. Any `.md` not covered by a config (the user's own files, or old
  ///    frontmatter files being migrated) is adopted as a note.
  Future<List<Note>> loadNotes() async {
    if (!hasFolder) return [];
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) return [];
    final notes = <Note>[];
    final covered = <String>{}; // relative paths already claimed by a config

    // 1) App-managed notes from .config.
    final cfgDir = Directory(await _configDirPath);
    if (cfgDir.existsSync()) {
      for (final entity in cfgDir.listSync()) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.json')) continue;
        try {
          final json =
              jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
          final rel = (json['relativePath'] as String?) ?? '${json['id']}.md';
          covered.add(rel);
          final mdFile = File(p.join(dir.path, rel));
          final content = mdFile.existsSync() ? mdFile.readAsStringSync() : '';
          notes.add(Note.fromConfigJson(json, content));
        } catch (_) {
          // Skip corrupt config entries.
        }
      }
    }

    // 2) Adopt any .md not covered by a config.
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      final relative = p.relative(entity.path, from: dir.path);
      if (covered.contains(relative)) continue;
      try {
        final content = entity.readAsStringSync();
        notes.add(Note.fromMarkdownFileOrAdopt(content, relative));
        covered.add(relative);
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
    final cfgDir = Directory(await _configDirPath);
    final written = <String>{};
    final writtenConfigs = <String>{};
    for (final note in notes) {
      final rel = note.relativePath ?? note.fileName;
      final file = File(p.join(dir.path, rel));
      try {
        file.parent.createSync(recursive: true);
        // Content only — metadata goes to .config/<id>.json.
        file.writeAsStringSync(note.content);
        written.add(file.path);
        final cfg = File(p.join(cfgDir.path, '${note.id}.json'));
        cfg.writeAsStringSync(jsonEncode(note.toConfigJson()));
        writtenConfigs.add(cfg.path);
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
    // Remove orphaned config files for notes that no longer exist.
    if (cfgDir.existsSync()) {
      for (final entity in cfgDir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        if (writtenConfigs.contains(entity.path)) continue;
        try {
          entity.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> saveNote(Note note) async {
    if (!hasFolder) return;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final rel = note.relativePath ?? note.fileName;
    final file = File(p.join(dir.path, rel));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(note.content); // content only
    final cfg = File(p.join(await _configDirPath, '${note.id}.json'));
    cfg.writeAsStringSync(jsonEncode(note.toConfigJson())); // metadata
  }

  /// Delete the note's `.md` file, using its relative path when known.
  Future<void> deleteNoteFile(String relativePathOrFileName) async {
    if (!hasFolder) return;
    final file = File(p.join(currentFolder!, relativePathOrFileName));
    if (file.existsSync()) file.deleteSync();
  }

  /// Delete the note's metadata file under `.config/<id>.json`.
  Future<void> deleteNoteConfig(String id) async {
    if (!hasFolder) return;
    final cfg = File(p.join(await _configDirPath, '$id.json'));
    if (cfg.existsSync()) cfg.deleteSync();
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
    // Migrate the legacy private-dir files into the repository's .config on
    // first launch for existing users.
    await migrateFileFromPrivate('settings.json');
    await migrateFileFromPrivate('secrets.json');

    // Load the non-secret settings.
    AppSettings settings;
    final settingsJson = await readJsonWithBackup('settings.json');
    if (settingsJson == null) {
      settings = AppSettings();
    } else {
      try {
        settings = AppSettings.fromJson(settingsJson as Map<String, dynamic>);
      } catch (_) {
        settings = AppSettings();
      }
    }

    // Merge secrets from the dedicated secrets file. Fall back to any legacy
    // secrets still embedded in settings.json for backward compatibility.
    final secrets = await _loadSecrets();
    final key = secrets.aiApiKey ?? settings.aiApiKey;
    final token = secrets.githubToken ?? settings.githubToken;
    settings = settings.copyWith(aiApiKey: key, githubToken: token);

    // If secrets.json had nothing but the legacy settings still carried them,
    // persist them into secrets.json (and rewrite settings.json without them).
    if ((secrets.aiApiKey == null || secrets.githubToken == null) &&
        (settings.aiApiKey != null || settings.githubToken != null)) {
      await saveSettings(settings);
    }
    return settings;
  }

  Future<void> saveSettings(AppSettings settings) async {
    // Secrets go to a dedicated file; settings.json stays secret-free.
    await _saveSecrets(settings);
    await writeJsonAtomic('settings.json', settings.toJson());
  }

  /// Load secrets from the dedicated `.config/secrets.json` (with `.bak`
  /// fallback). Returns nulls when absent or unreadable.
  Future<({String? aiApiKey, String? githubToken})> _loadSecrets() async {
    final json = await readJsonWithBackup('secrets.json');
    if (json == null) return (aiApiKey: null, githubToken: null);
    try {
      final map = json as Map<String, dynamic>;
      return (
        aiApiKey: AppSettings.decodeSecret(map['aiApiKey'] as String?),
        githubToken: AppSettings.decodeSecret(map['githubToken'] as String?),
      );
    } catch (_) {
      return (aiApiKey: null, githubToken: null);
    }
  }

  /// Persist secrets to the dedicated `.config/secrets.json`.
  Future<void> _saveSecrets(AppSettings settings) async {
    await writeJsonAtomic('secrets.json', {
      'aiApiKey': AppSettings.encodeSecret(settings.aiApiKey),
      'githubToken': AppSettings.encodeSecret(settings.githubToken),
    });
  }

  /// Atomically replace [fileName] inside the config dir with [object] encoded
  /// as JSON. The previous file is snapshotted as `<fileName>.bak` first, so a
  /// crash mid-write or a full disk can be recovered on the next read (the temp
  /// file is fully written before the rename, so the live file is never
  /// truncated in place).
  Future<void> writeJsonAtomic(String fileName, Object object) async {
    final dir = await _configDirPath;
    final target = File(p.join(dir, fileName));
    final tmp = File('${target.path}.tmp');
    try {
      // Write the full payload to a temp file first, then copy the (still-good)
      // live file to `.bak` before replacing it — so a crash mid-replace never
      // leaves the live file truncated. The post-write copy guarantees a backup
      // exists after every successful save.
      tmp.writeAsStringSync(jsonEncode(object));
      if (tmp.existsSync()) {
        if (target.existsSync()) target.copySync('${target.path}.bak');
        target.writeAsStringSync(tmp.readAsStringSync());
        tmp.deleteSync();
        if (target.existsSync()) target.copySync('${target.path}.bak');
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Read a JSON file from the config dir. On a parse error the `.bak` backup
  /// is tried before giving up. Returns null when neither exists or both are
  /// unreadable.
  Future<dynamic> readJsonWithBackup(String fileName) async {
    final dir = await _configDirPath;
    final target = File(p.join(dir, fileName));
    if (target.existsSync()) {
      try {
        return jsonDecode(target.readAsStringSync());
      } catch (_) {
        // fall through to backup
      }
    }
    final bak = File('${target.path}.bak');
    if (bak.existsSync()) {
      try {
        return jsonDecode(bak.readAsStringSync());
      } catch (_) {}
    }
    return null;
  }

  // ── Last opened repository (stable, repository-independent) ──
  //
  // The last opened repository path must survive restarts, but it can't live
  // in the repository's own `.config/settings.json` — that file's location
  // depends on knowing the repository first (a chicken-and-egg problem at
  // startup, since `currentFolder` is still null when settings are first
  // read). So we persist just the path in a stable private file, read before
  // any repository folder is selected, which lets the app reopen the last
  // repository on launch.

  Future<String?> loadLastRepoPath() async {
    final file = File(
      p.join((await _privateDir).path, '.config', 'last_repo.json'),
    );
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final path = json['path'] as String?;
      return (path != null && path.isNotEmpty) ? path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastRepoPath(String path) async {
    final dir = Directory(p.join((await _privateDir).path, '.config'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'last_repo.json'));
    file.writeAsStringSync(jsonEncode({'path': path}));
  }

  // ── Export ──

  /// Export a single note as a standalone `.md` file into the **selected
  /// notes folder** (so it lands next to the user's other notes, not in a
  /// hidden `/data` path). Falls back to the private app dir when no folder
  /// is configured. Only the markdown *content* is written — no frontmatter.
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
    final body = note.content.trim().isEmpty
        ? '# ${note.title}\n'
        : note.content;
    file.writeAsStringSync(body);
    return file.path;
  }

  // ── Folder backup (.fne = zip of the notes folder) ──

  /// The base name (last path segment) of the selected notes folder, used to
  /// name the exported archive as `{folder_name}_export.fne`.
  String? get currentFolderName {
    if (!hasFolder) return null;
    final cleaned = currentFolder!.replaceAll(RegExp(r'[/\\]+$'), '');
    return p.basename(cleaned);
  }

  /// Build the `.fne` archive (a zip) of the entire notes folder — including
  /// the hidden `.config` metadata directory — and return its raw bytes.
  /// Returns null when no folder is configured.
  Future<Uint8List?> buildFolderFneBytes() async {
    if (!hasFolder) return null;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) return null;

    final archive = Archive();
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: dir.path);
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Extract a `.fne` archive ([bytes]) into the current notes folder,
  /// merging entries and overwriting same-named files. Returns the number of
  /// files written.
  Future<int> importFolderFromFneBytes(List<int> bytes) async {
    if (!hasFolder) return 0;
    final dir = Directory(currentFolder!);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final archive = ZipDecoder().decodeBytes(bytes);
    var written = 0;
    for (final file in archive.files) {
      if (file.isFile) {
        final content = file.content;
        if (content == null) continue;
        final outPath = p.join(dir.path, file.name);
        File(outPath)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(content as List<int>);
        written++;
      }
    }
    return written;
  }
}
