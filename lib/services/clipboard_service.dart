import 'dart:async';

import 'package:flutter/services.dart';

import '../services/storage_service.dart';

/// In-app clipboard manager (the "剪切板" widget, v1.18.0).
///
/// Polls the system clipboard while the app is in the foreground, keeps a
/// de-duplicated, most-recent-first history capped at [max], and persists it
/// to `clipboard.json` in the config directory so it survives restarts.
class ClipboardService {
  static final ClipboardService instance = ClipboardService._();
  ClipboardService._();

  static const int hardMax = 99999;

  List<String> _items = [];
  int _max = 100;
  Timer? _timer;
  final StreamController<void> _controller = StreamController<void>.broadcast();

  /// Notified whenever the clipboard history changes (add / trim / clear).
  Stream<void> get onChange => _controller.stream;

  /// The current history, most-recent first.
  List<String> get items => List.unmodifiable(_items);

  int get max => _max;

  /// Load the persisted history and begin polling the system clipboard.
  Future<void> init({int max = 100}) async {
    _max = max.clamp(1, hardMax);
    await _load();
    _startPolling();
  }

  /// Update the retention cap; trims the history if it now exceeds [max].
  void setMax(int max) {
    _max = max.clamp(1, hardMax);
    _trim();
    _save();
    _controller.add(null);
  }

  void _startPolling() {
    _timer?.cancel();
    // Sample immediately, then every 2s — frequent enough to catch a copy
    // made in another app when the user returns to Borderless Notes.
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) return;
      _add(text);
    } catch (_) {
      // Clipboard access can throw on some platforms (e.g. background on
      // Android) — ignore and try again next tick.
    }
  }

  void _add(String text) {
    if (_items.isNotEmpty && _items.first == text) return;
    _items.remove(text);
    _items.insert(0, text);
    _trim();
    _save();
    _controller.add(null);
  }

  void _trim() {
    if (_items.length > _max) _items = _items.sublist(0, _max);
  }

  Future<void> _load() async {
    try {
      final json = await StorageService.instance.readJsonWithBackup(
        'clipboard.json',
      );
      if (json is Map && json['items'] is List) {
        _items = (json['items'] as List).map((e) => e.toString()).toList();
        _trim();
      }
    } catch (_) {
      // no history yet
    }
  }

  Future<void> _save() async {
    try {
      await StorageService.instance.writeJsonAtomic('clipboard.json', {
        'items': _items,
      });
    } catch (_) {
      // best-effort persistence
    }
  }

  /// Copy [text] back to the system clipboard and bubble it to the top.
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _add(text);
  }

  /// Remove a single entry from the history.
  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _save();
    _controller.add(null);
  }

  /// Clear the entire clipboard history.
  void clear() {
    _items = [];
    _save();
    _controller.add(null);
  }
}
