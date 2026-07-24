import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../models/plugin.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/github_sync_service.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../plugins/plugin_manager.dart';
import '../plugins/builtin_plugins.dart';
import '../plugins/ai_context_plugin.dart';
import '../plugins/autosave_plugin.dart';
import '../plugins/github_sync_plugin.dart';
import '../plugins/github_sync_host.dart';
import '../plugins/user_plugin.dart';

/// Central app state provider — manages notes, settings, AI, sync, and plugins.
class AppProvider extends ChangeNotifier implements GitHubSyncHost {
  final StorageService _storage = StorageService.instance;

  // State
  List<Note> _notes = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  String? _statusMessage;

  // Services
  late final AIService aiService;
  @override
  late final GitHubSyncService githubService;
  final PluginManager pluginManager = PluginManager();

  // Getters
  List<Note> get notes => List.unmodifiable(_notes);
  @override
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  bool get isDarkMode => _settings.isDarkMode;
  bool get needsFolderSelection => !_storage.hasFolder;

  /// Resolved theme color from settings, or null for default.
  Color? get themeColor {
    final hex = _settings.themeColorHex;
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(
        int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000,
      );
    } catch (_) {
      return null;
    }
  }

  /// Notes sorted: pinned first, then by updated time descending.
  List<Note> get sortedNotes {
    final list = List<Note>.from(_notes);
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  /// Initialize the app — load data and register plugins.
  Future<void> init() async {
    _setLoading(true);

    // Restore the last opened repository BEFORE reading settings. Settings
    // live in <repo>/.config/settings.json, whose location depends on knowing
    // the repo first — so without this, settings would be read from the
    // private config dir (which is empty after the legacy migration moved them
    // into the repo), `notesFolderPath` would be lost, and the app would fall
    // back to FolderPickerScreen instead of reopening the last repository.
    final lastRepo = await _storage.loadLastRepoPath();
    if (lastRepo != null && Directory(lastRepo).existsSync()) {
      await _storage.setFolder(lastRepo);
    }

    _settings = await _storage.loadSettings();
    if (_settings.notesFolderPath != null &&
        _settings.notesFolderPath!.isNotEmpty) {
      await _storage.setFolder(_settings.notesFolderPath!);
    }
    _notes = await _storage.loadNotes();

    // Initialize services with loaded settings.
    aiService = AIService(
      apiKey: _settings.aiApiKey,
      model: _settings.aiModel,
      baseUrl: _settings.resolvedAiBaseUrl,
    );
    githubService = GitHubSyncService(
      token: _settings.githubToken,
      repo: _settings.githubRepo,
    );

    // Register built-in plugins.
    pluginManager.register(WordCountPlugin());
    pluginManager.register(TextFormatterPlugin());
    pluginManager.register(ExportPlugin());
    pluginManager.register(AiContextPlugin());
    pluginManager.register(AutoSavePlugin());
    pluginManager.register(GitHubSyncPlugin());

    // Restore user-added plugins (added at runtime via the Plugins "+" button).
    for (final info in _settings.userPlugins) {
      pluginManager.register(UserPlugin.fromInfo(info));
    }

    _setLoading(false);

    // Notifications: initialize, respawn any due repeating tasks, and schedule
    // upcoming reminders. Best-effort — failures must not block startup.
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await NotificationService.instance.init();
    await TaskService.instance.respawnDueRepeats();
    final tasks = await TaskService.instance.loadTasks();
    for (final t in tasks) {
      if (t.reminder != null) {
        await NotificationService.instance.scheduleReminder(
          t,
          title: 'Reminder',
        );
      }
    }
  }

  // ---- Notes CRUD ----

  Note createNote({String title = '', String content = ''}) {
    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _notes.add(note);
    _persist();
    notifyListeners();
    return note;
  }

  void updateNote(Note note) {
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      final oldRel = _notes[idx].relativePath;
      _notes[idx] = note;
      // If the note moved to a different subfolder, remove the stale file so
      // we don't leave duplicates behind.
      if (oldRel != null && oldRel != note.relativePath) {
        _storage.deleteNoteFile(oldRel);
      }
      _persist();
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    Note? note;
    if (idx >= 0) {
      note = _notes[idx];
      _notes.removeAt(idx);
    }
    if (note != null) {
      _storage.deleteNoteFile(note.relativePath ?? note.fileName);
      _storage.deleteNoteConfig(note.id);
    }
    _persist();
    notifyListeners();
  }

  void togglePin(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notes[idx] = _notes[idx].copyWith(isPinned: !_notes[idx].isPinned);
      _persist();
      notifyListeners();
    }
  }

  void toggleFavorite(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notes[idx] = _notes[idx].copyWith(isFavorite: !_notes[idx].isFavorite);
      _persist();
      notifyListeners();
    }
  }

  Note? getNote(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- Folder selection ----

  /// Choose the notes folder (user's "repository"). Loads existing notes.
  ///
  /// On Android this requests all-files access (required to write into an
  /// arbitrary user-picked folder on API 30+), then verifies the folder is
  /// actually writable before relying on it — so a bad pick surfaces an error
  /// instead of silently dropping notes.
  Future<String> chooseFolder(String path) async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final requested = await Permission.manageExternalStorage.request();
        if (!requested.isGranted) {
          _statusMessage = '需要「所有文件访问」权限才能把笔记写入所选文件夹';
          notifyListeners();
          return _statusMessage!;
        }
      }
    }

    final writable = await _storage.probeWritable(path);
    if (!writable) {
      _statusMessage = '该文件夹无法写入，请换一个文件夹或授予存储权限';
      notifyListeners();
      return _statusMessage!;
    }

    _settings.notesFolderPath = path;
    if (!_settings.repositories.contains(path)) {
      _settings.repositories = [..._settings.repositories, path];
    }
    await _storage.setFolder(path);
    await _storage.saveSettings(_settings);
    await _storage.saveLastRepoPath(path);
    _notes = await _storage.loadNotes();
    _statusMessage = null;
    notifyListeners();
    return '';
  }

  /// Reload notes from disk (e.g. after an external file was written).
  Future<void> reloadNotes() async {
    _notes = await _storage.loadNotes();
    notifyListeners();
  }

  /// Insert a freshly created note into the in-memory list and persist it.
  Future<void> addNoteAndPersist(Note note) async {
    _notes.add(note);
    await _persist();
    notifyListeners();
  }

  // ---- Settings ----

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    aiService.apiKey = settings.aiApiKey;
    aiService.model = settings.aiModel;
    aiService.baseUrl = settings.resolvedAiBaseUrl;
    githubService.token = settings.githubToken;
    githubService.repo = settings.githubRepo;
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  /// Persist GitHub auth fields coming from the GitHub Sync plugin settings.
  /// Empty [token]/[username] clear the value (disconnect).
  @override
  Future<void> updateGitHubAuth({
    String? token,
    String? username,
    String? repo,
    String? clientId,
    bool? autoSync,
  }) async {
    if (token != null) _settings.githubToken = token.isEmpty ? null : token;
    if (username != null) {
      _settings.githubUsername = username.isEmpty ? null : username;
    }
    if (repo != null) _settings.githubRepo = repo.isEmpty ? null : repo;
    if (clientId != null) {
      _settings.githubClientId = clientId.isEmpty ? null : clientId;
    }
    if (autoSync != null) _settings.autoSync = autoSync;
    githubService.token = _settings.githubToken;
    githubService.repo = _settings.githubRepo;
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  void toggleDarkMode() {
    _settings.isDarkMode = !_settings.isDarkMode;
    _storage.saveSettings(_settings);
    notifyListeners();
  }

  void setLanguage(String code) {
    _settings.languageCode = code;
    _storage.saveSettings(_settings);
    notifyListeners();
  }

  void setThemeColor(String? hex) {
    _settings.themeColorHex = hex;
    _storage.saveSettings(_settings);
    notifyListeners();
  }

  // ---- User plugins (runtime-added via the Plugins "+" button) ----

  /// Add a user-created plugin and persist it so it survives restarts.
  /// Returns the generated plugin id, or null if [name] is empty.
  /// [snippet] is an optional insert text used by "editor"-type plugins.
  String? addUserPlugin({
    required String name,
    required String description,
    required PluginType type,
    String? snippet,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final id =
        'user.${trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '')}.${DateTime.now().millisecondsSinceEpoch}';
    final plugin = UserPlugin(
      id: id,
      name: trimmed,
      description: description.trim(),
      type: type,
      snippet: snippet,
    );
    pluginManager.register(plugin);
    final updated = List<PluginInfo>.from(_settings.userPlugins)
      ..add(plugin.info);
    _settings.userPlugins = updated;
    _storage.saveSettings(_settings);
    notifyListeners();
    return id;
  }

  /// Remove a user-added plugin by [id] (only user plugins can be removed).
  void removeUserPlugin(String id) {
    if (!UserPlugin.isUserPluginId(id)) return;
    pluginManager.unregister(id);
    final updated = _settings.userPlugins.where((p) => p.id != id).toList();
    _settings.userPlugins = updated;
    _storage.saveSettings(_settings);
    notifyListeners();
  }

  // ---- GitHub Sync ----

  /// Sync notes to GitHub now (immediate sync).
  @override
  Future<String> syncToGitHub() async {
    if (!githubService.isConfigured) {
      _statusMessage = 'GitHub 未配置，请先在设置中填写 Token 和仓库';
      notifyListeners();
      return _statusMessage!;
    }
    _setLoading(true);
    final result = await githubService.syncNotes(_notes);
    _statusMessage = result.message;
    _setLoading(false);
    notifyListeners();
    return result.message;
  }

  @override
  Future<String> pullFromGitHub() async {
    if (!githubService.isConfigured) {
      _statusMessage = 'GitHub 未配置，请先在设置中填写 Token 和仓库';
      notifyListeners();
      return _statusMessage!;
    }
    _setLoading(true);
    final remoteNotes = await githubService.pullNotes();
    if (remoteNotes != null) {
      _notes = remoteNotes;
      await _persist();
      _statusMessage = '已从 GitHub 拉取 ${remoteNotes.length} 篇笔记';
    } else {
      _statusMessage = '从 GitHub 拉取失败';
    }
    _setLoading(false);
    notifyListeners();
    return _statusMessage!;
  }

  Future<bool> verifyGitHubConnection() async {
    return githubService.verifyConnection();
  }

  // ---- Private helpers ----

  Future<void> _persist() async {
    try {
      await _storage.saveNotes(_notes);
    } catch (e) {
      _statusMessage = '保存失败：$e';
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearStatus() {
    _statusMessage = null;
    notifyListeners();
  }
}
