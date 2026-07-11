import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/github_sync_service.dart';
import '../plugins/plugin_manager.dart';
import '../plugins/builtin_plugins.dart';

/// Central app state provider — manages notes, settings, AI, sync, and plugins.
class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;

  // State
  List<Note> _notes = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  String? _statusMessage;

  // Services
  late final AIService aiService;
  late final GitHubSyncService githubService;
  final PluginManager pluginManager = PluginManager();

  // Getters
  List<Note> get notes => List.unmodifiable(_notes);
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  bool get isDarkMode => _settings.isDarkMode;

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
    _settings = await _storage.loadSettings();
    _notes = await _storage.loadNotes();

    // Initialize services with loaded settings.
    aiService = AIService(apiKey: _settings.aiApiKey, model: _settings.aiModel);
    githubService = GitHubSyncService(
      token: _settings.githubToken,
      repo: _settings.githubRepo,
    );

    // Register built-in plugins.
    pluginManager.register(WordCountPlugin());
    pluginManager.register(TextFormatterPlugin());
    pluginManager.register(ExportPlugin());

    _setLoading(false);
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
      _notes[idx] = note;
      _persist();
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
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

  // ---- Settings ----

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    aiService.apiKey = settings.aiApiKey;
    aiService.model = settings.aiModel;
    githubService.token = settings.githubToken;
    githubService.repo = settings.githubRepo;
    await _storage.saveSettings(settings);
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

  // ---- GitHub Sync ----

  Future<String> syncToGitHub() async {
    _setLoading(true);
    final result = await githubService.syncNotes(_notes);
    _statusMessage = result.message;
    _setLoading(false);
    notifyListeners();
    return result.message;
  }

  Future<String> pullFromGitHub() async {
    _setLoading(true);
    final remoteNotes = await githubService.pullNotes();
    if (remoteNotes != null) {
      _notes = remoteNotes;
      await _persist();
      _statusMessage = 'Pulled ${remoteNotes.length} notes from GitHub';
    } else {
      _statusMessage = 'Failed to pull from GitHub';
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
    await _storage.saveNotes(_notes);
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
