import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note.dart';

/// GitHub sync service — syncs notes to a GitHub repository via the REST API.
/// Notes are stored as a single `notes/notes.json` file (with frontmatter
/// mirrored locally as individual `.md` files by the storage layer).
class GitHubSyncService {
  /// Default OAuth App client_id for the Device login flow. Replace with your
  /// own GitHub OAuth App's client_id (Settings → Developer settings → OAuth
  /// Apps). The device flow requires a registered OAuth App.
  static const String defaultClientId = '';

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

  String _describeError(int status) {
    switch (status) {
      case 401:
        return 'GitHub Token 无效或已过期 (401)';
      case 403:
        return '无权限写入该仓库，请检查 Token 的 repo 权限 (403)';
      case 404:
        return '仓库不存在或无访问权限，请确认 owner/repo 是否正确 (404)';
      case 422:
        return '提交内容无效 (422)';
      default:
        return 'GitHub API 错误: $status';
    }
  }

  /// Sync all notes to GitHub — uploads a single notes.json file.
  Future<SyncResult> syncNotes(List<Note> notes) async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub 未配置（请填写 Token 和仓库）');
    }
    try {
      final json = jsonEncode(notes.map((n) => n.toJson()).toList());
      // Remove newlines from base64 so the API accepts it reliably.
      final content = base64Encode(utf8.encode(json)).replaceAll('\n', '');
      const path = 'notes/notes.json';

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
        } else if (getRes.statusCode != 404) {
          return SyncResult(
            success: false,
            message: _describeError(getRes.statusCode),
          );
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

      final res = await http
          .put(
            Uri.parse('$_apiBase/contents/$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return SyncResult(
          success: true,
          message: '已同步 ${notes.length} 篇笔记到 GitHub',
        );
      }
      return SyncResult(
        success: false,
        message: _describeError(res.statusCode),
      );
    } catch (e) {
      return SyncResult(success: false, message: '同步失败: $e');
    }
  }

  /// Pull notes from GitHub.
  Future<List<Note>?> pullNotes() async {
    if (!isConfigured) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$_apiBase/contents/notes/notes.json?ref=$branch'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
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
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$repo'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
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

/// Thrown for device-flow / auth problems. [cancelled] marks user-initiated
/// cancellations so the UI can stay quiet instead of showing an error.
class GitHubAuthException implements Exception {
  final String message;
  final bool cancelled;

  GitHubAuthException(this.message, [this.cancelled = false]);

  @override
  String toString() => message;
}

/// Response from POST /login/device/code.
class DeviceCodeResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) =>
      DeviceCodeResponse(
        deviceCode: json['device_code'] as String,
        userCode: json['user_code'] as String,
        verificationUri: json['verification_uri'] as String,
        expiresIn: json['expires_in'] as int? ?? 900,
        interval: json['interval'] as int? ?? 5,
      );
}

/// A GitHub repository returned from GET /user/repos.
class GitHubRepo {
  final String name;
  final String fullName;
  final bool private;
  final String? description;

  GitHubRepo({
    required this.name,
    required this.fullName,
    required this.private,
    this.description,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
    name: json['name'] as String,
    fullName: json['full_name'] as String,
    private: json['private'] as bool? ?? false,
    description: json['description'] as String?,
  );
}

/// Authenticated GitHub user.
class GitHubUser {
  final String login;

  GitHubUser({required this.login});

  factory GitHubUser.fromJson(Map<String, dynamic> json) =>
      GitHubUser(login: json['login'] as String);
}

/// Exception thrown when [clientId] is missing/empty.
class GitHubClientIdMissingException implements Exception {
  @override
  String toString() =>
      'GitHub OAuth App Client ID is required for Device login.';
}

extension GitHubSyncDeviceFlow on GitHubSyncService {
  /// Request a device + user code from GitHub's Device flow.
  Future<DeviceCodeResponse> requestDeviceCode(String clientId) async {
    if (clientId.isEmpty) throw GitHubClientIdMissingException();
    final res = await http
        .post(
          Uri.parse('https://github.com/login/device/code'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'client_id': clientId, 'scope': 'repo'}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return DeviceCodeResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw GitHubAuthException('无法请求设备码: ${res.statusCode}');
  }

  /// Poll GitHub until the user authorizes the device. Throws [GitHubAuthException]
  /// on terminal errors or cancellation ([shouldCancel] returns true).
  Future<String> pollForToken({
    required String clientId,
    required String deviceCode,
    required int interval,
    required int expiresIn,
    bool Function()? shouldCancel,
  }) async {
    var wait = interval;
    var elapsed = 0;
    while (elapsed < expiresIn) {
      if (shouldCancel?.call() == true) {
        throw GitHubAuthException('已取消授权', true);
      }
      await Future.delayed(Duration(seconds: wait));
      elapsed += wait;
      final res = await http
          .post(
            Uri.parse('https://github.com/login/oauth/access_token'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'client_id': clientId,
              'device_code': deviceCode,
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            }),
          )
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j.containsKey('access_token')) {
        return j['access_token'] as String;
      }
      final err = j['error'] as String?;
      switch (err) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          wait += 5;
          continue;
        case 'expired_token':
          throw GitHubAuthException('设备码已过期，请重试');
        case 'access_denied':
        case 'already_denied':
          throw GitHubAuthException('已拒绝授权', true);
        default:
          throw GitHubAuthException('授权失败: $err');
      }
    }
    throw GitHubAuthException('等待授权超时', true);
  }

  /// List repositories (public + private) owned by / collaborated on by the
  /// authenticated user. Used to auto-populate the repo picker.
  Future<List<GitHubRepo>> listUserRepos(String token) async {
    final out = <GitHubRepo>[];
    var page = 1;
    while (true) {
      final res = await http
          .get(
            Uri.parse(
              'https://api.github.com/user/repos'
              '?visibility=all&affiliation=owner,collaborator'
              '&per_page=100&page=$page',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw GitHubAuthException('加载仓库失败: ${_describeError(res.statusCode)}');
      }
      final arr = jsonDecode(res.body) as List<dynamic>;
      if (arr.isEmpty) break;
      out.addAll(
        arr.map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>)),
      );
      if (arr.length < 100) break;
      page++;
    }
    return out;
  }

  /// Fetch the authenticated user's login name.
  Future<GitHubUser> getAuthenticatedUser(String token) async {
    final res = await http
        .get(
          Uri.parse('https://api.github.com/user'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return GitHubUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw GitHubAuthException('获取用户信息失败: ${_describeError(res.statusCode)}');
  }
}
