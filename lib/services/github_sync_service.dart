import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note.dart';

/// GitHub sync service — syncs notes to a GitHub repository via the REST API.
class GitHubSyncService {
  String? token;
  String? repo; // format: owner/repo
  String? branch;

  GitHubSyncService({this.token, this.repo, this.branch = 'main'});

  bool get isConfigured =>
      token != null && token!.isNotEmpty && repo != null && repo!.isNotEmpty;

  String get _apiBase => 'https://api.github.com/repos/$repo';

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  /// Sync all notes to GitHub — uploads a single notes.json file.
  Future<SyncResult> syncNotes(List<Note> notes) async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub not configured');
    }
    try {
      final content = base64Encode(
        utf8.encode(jsonEncode(notes.map((n) => n.toJson()).toList())),
      );
      final path = 'notes/notes.json';

      // Get existing file SHA (if any) for update.
      String? sha;
      try {
        final getRes = await http.get(
          Uri.parse('$_apiBase/contents/$path?ref=$branch'),
          headers: _headers,
        );
        if (getRes.statusCode == 200) {
          sha =
              (jsonDecode(getRes.body) as Map<String, dynamic>)['sha']
                  as String?;
        }
      } catch (_) {
        // File doesn't exist yet — that's fine.
      }

      final body = <String, dynamic>{
        'message': 'Sync notes — ${DateTime.now().toIso8601String()}',
        'content': content,
        'branch': branch,
      };
      if (sha != null) body['sha'] = sha;

      final res = await http.put(
        Uri.parse('$_apiBase/contents/$path'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return SyncResult(
          success: true,
          message: 'Synced ${notes.length} notes to GitHub',
        );
      }
      return SyncResult(
        success: false,
        message: 'GitHub API error: ${res.statusCode}',
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Sync error: $e');
    }
  }

  /// Pull notes from GitHub.
  Future<List<Note>?> pullNotes() async {
    if (!isConfigured) return null;
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/contents/notes/notes.json?ref=$branch'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final content = data['content'] as String;
        final decoded = utf8.decode(base64Decode(content.replaceAll('\n', '')));
        final json = jsonDecode(decoded) as List<dynamic>;
        return json
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verify the repository and token are valid.
  Future<bool> verifyConnection() async {
    if (!isConfigured) return false;
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$repo'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class SyncResult {
  final bool success;
  final String message;

  SyncResult({required this.success, required this.message});
}
