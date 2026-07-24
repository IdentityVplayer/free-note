import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';

/// GitHub sync service — syncs notes to a GitHub repository via the REST API.
/// Notes are stored as a single `notes/notes.json` file (with frontmatter
/// mirrored locally as individual `.md` files by the storage layer).
class GitHubSyncService {
  /// Default GitHub OAuth App client_id for the Device login flow. Users can
  /// override it with their own OAuth App via "使用其他的Oauth登录".
  static const String defaultClientId = 'Ov23liBn5JuhulMcevmz';

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
  /// Sync all notes to GitHub — each note becomes an individual `.md` file
  /// under the `notes/` directory, preserving subfolder structure so the
  /// repository stays human-readable. Files that no longer exist locally are
  /// deleted from the remote, and the legacy single-file `notes/notes.json` is
  /// cleaned up if it still exists.
  Future<SyncResult> syncNotes(List<Note> notes) async {
    if (!isConfigured) {
      return SyncResult(success: false, message: 'GitHub 未配置（请填写 Token 和仓库）');
    }
    try {
      // 1. List current files in notes/ on the remote (path → sha).
      final remoteFiles = await _listNotesDir();
      final remotePaths = remoteFiles.keys.toSet();

      // 2. Upload every local note.
      final localPaths = <String>{};
      for (final note in notes) {
        final path = _notePath(note);
        localPaths.add(path);
        final content = note.toMarkdownFile();
        final encoded = base64Encode(utf8.encode(content)).replaceAll('\n', '');
        await _putFile(path, encoded, remoteFiles[path]);
      }

      // 3. Delete files that exist on GitHub but no longer locally.
      for (final path in remotePaths.difference(localPaths)) {
        final sha = remoteFiles[path];
        if (sha != null) await _deleteFile(path, sha);
      }

      // 4. Clean up the legacy single-file format if still present.
      if (remoteFiles.containsKey('notes/notes.json')) {
        await _deleteFile('notes/notes.json', remoteFiles['notes/notes.json']!);
      }

      return SyncResult(
        success: true,
        message: '已同步 ${notes.length} 篇笔记到 GitHub',
      );
    } catch (e) {
      return SyncResult(success: false, message: '同步失败: $e');
    }
  }

  /// Pull notes from GitHub — download every `.md` file under `notes/`,
  /// parse YAML frontmatter and return the resulting [Note] list.
  Future<List<Note>?> pullNotes() async {
    if (!isConfigured) return null;
    try {
      final remoteFiles = await _listNotesDir();
      final notes = <Note>[];
      for (final entry in remoteFiles.entries) {
        final path = entry.key;
        if (!path.endsWith('.md')) continue;
        final res = await http
            .get(
              Uri.parse(_encPath('$_apiBase/contents/$path')),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['content'] as String;
        final decoded = utf8.decode(base64Decode(raw.replaceAll('\n', '')));
        final relativePath = path.startsWith('notes/')
            ? path.substring(6)
            : path;
        final note = Note.fromMarkdownFile(decoded, relativePath);
        if (note != null) notes.add(note);
      }
      return notes.isNotEmpty ? notes : null;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers for file-based sync ──

  /// URL-encode each segment of a repository file path so special characters
  /// (spaces, Unicode, etc.) are safely included in API request URLs.
  static String _encPath(String path) =>
      path.split('/').map((s) => Uri.encodeComponent(s)).join('/');

  /// Relative path for a note inside the `notes/` directory.
  String _notePath(Note note) => 'notes/${note.relativePath ?? note.fileName}';

  /// List every blob whose path starts with `notes/` using the Git Trees API,
  /// returning a map of path → SHA. Returns an empty map on error (new repo
  /// with no commits, network failure, etc.).
  Future<Map<String, String>> _listNotesDir() async {
    final result = <String, String>{};
    try {
      final ref = await http
          .get(
            Uri.parse(_encPath('$_apiBase/git/refs/heads/$branch')),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (ref.statusCode != 200) return result;
      final refData = jsonDecode(ref.body) as Map<String, dynamic>;
      final commitSha = refData['object']['sha'] as String;

      final tree = await http
          .get(
            Uri.parse(_encPath('$_apiBase/git/trees/$commitSha?recursive=1')),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      if (tree.statusCode != 200) return result;
      final treeData = jsonDecode(tree.body) as Map<String, dynamic>;
      final items = treeData['tree'] as List<dynamic>;
      for (final item in items) {
        final itemPath = item['path'] as String;
        if (!itemPath.startsWith('notes/')) continue;
        if (item['type'] as String != 'blob') continue;
        result[itemPath] = item['sha'] as String;
      }
    } catch (_) {
      // New / empty repo — no files to list.
    }
    return result;
  }

  /// Create or update a file on GitHub at [path] with [base64Content].
  /// [existingSha] should be given when the file already exists (update);
  /// null for new files.
  Future<void> _putFile(
    String path,
    String base64Content,
    String? existingSha,
  ) async {
    final body = <String, dynamic>{
      'message': 'Sync note: $path — ${DateTime.now().toIso8601String()}',
      'content': base64Content,
      'branch': branch,
    };
    if (existingSha != null) body['sha'] = existingSha;
    final res = await http
        .put(
          Uri.parse(_encPath('$_apiBase/contents/$path')),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw GitHubAuthException(
        '上传 $path 失败: ${_describeError(res.statusCode)}',
      );
    }
  }

  /// Delete a file on GitHub at [path] (identified by [sha]).
  Future<void> _deleteFile(String path, String sha) async {
    final body = jsonEncode({
      'message': 'Remove note: $path',
      'sha': sha,
      'branch': branch,
    });
    final res = await http
        .delete(
          Uri.parse(_encPath('$_apiBase/contents/$path')),
          headers: _headers,
          body: body,
        )
        .timeout(const Duration(seconds: 30));
    // Non-200 is best-effort — the next sync will retry.
    if (res.statusCode != 200) {
      throw GitHubAuthException(
        '删除 $path 失败: ${_describeError(res.statusCode)}',
      );
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

/// A GitHub release, as returned by GET /repos/{owner}/{repo}/releases/latest.
class GitHubRelease {
  final String tagName;
  final String body;
  final String htmlUrl;
  final List<String> assetUrls;

  GitHubRelease({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    this.assetUrls = const [],
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List?) ?? [];
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      assetUrls: assets
          .map(
            (a) =>
                (a as Map<String, dynamic>)['browser_download_url'] as String?,
          )
          .where((u) => u != null)
          .cast<String>()
          .toList(),
    );
  }

  /// Where the user downloads: the first asset, or the release page itself.
  String get downloadUrl => assetUrls.isNotEmpty ? assetUrls.first : htmlUrl;

  /// Compare two version strings ("1.12.0" vs "1.9.9"). Returns true when
  /// [latest] is strictly newer than [current].
  static bool isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .where((p) => p.isNotEmpty)
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parse(latest);
    final b = parse(current);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

/// Fetch the latest published release of a public repository (no auth needed).
/// Returns null on any failure (offline, rate-limited, 404, etc.).
Future<GitHubRelease?> fetchLatestRelease(String repo) async {
  try {
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      return GitHubRelease.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
  } catch (_) {
    // Network error or rate limit — treat as "no update info".
  }
  return null;
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

/// OAuth Authorization Code flow with PKCE, using a local `http://localhost`
/// callback server so the browser can redirect back into the app automatically
/// — no custom URL scheme / deep-link manifest changes required on Android or
/// Windows. (Web cannot host a local server, so it falls back to the Device
/// flow in the UI.)
extension GitHubSyncBrowserFlow on GitHubSyncService {
  /// Local port the callback server listens on. Must match the "Authorization
  /// callback URL" registered in the GitHub OAuth App:
  /// `http://localhost:8543/callback`.
  static const int callbackPort = 8543;
  static const String callbackPath = '/callback';

  /// Build the GitHub authorize URL for the authorization-code + PKCE flow.
  Uri buildAuthorizeUrl({
    required String clientId,
    required String state,
    required String codeChallenge,
    String redirectUri = 'http://localhost:$callbackPort$callbackPath',
  }) => Uri.https('github.com', '/login/oauth/authorize', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': 'repo',
    'state': state,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  });

  String _generateCodeVerifier() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(64, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).split('=')[0];
  }

  String _pkceChallenge(String verifier) => base64Url
      .encode(crypto.sha256.convert(utf8.encode(verifier)).bytes)
      .split('=')[0];

  String _generateState() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).split('=')[0];
  }

  void _sendHtml(HttpRequest req, String message) {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><head><meta charset="utf-8">'
        '<title>Free Note</title></head><body style="font-family:sans-serif;'
        'display:flex;height:100vh;align-items:center;justify-content:center">'
        '<h3>$message</h3></body></html>',
      )
      ..close();
  }

  /// Exchange the authorization `code` for an access token (PKCE).
  Future<String> _exchangeCode({
    required String clientId,
    required String code,
    required String redirectUri,
    required String verifier,
  }) async {
    final res = await http
        .post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'client_id': clientId,
            'code': code,
            'redirect_uri': redirectUri,
            'code_verifier': verifier,
            'grant_type': 'authorization_code',
          }),
        )
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j.containsKey('access_token')) return j['access_token'] as String;
    final err = j['error_description'] ?? j['error'];
    throw GitHubAuthException('换取令牌失败: $err');
  }

  /// Run the full browser login: open GitHub in the external browser, spin up
  /// a local callback server, wait for the redirect carrying `code`, then
  /// exchange it for a token. Throws [GitHubAuthException] on error / cancel
  /// ([shouldCancel] returns true) / timeout.
  Future<String> loginWithBrowser({
    required String clientId,
    bool Function()? shouldCancel,
  }) async {
    if (clientId.isEmpty) throw GitHubClientIdMissingException();
    final redirectUri = 'http://localhost:$callbackPort$callbackPath';
    final verifier = _generateCodeVerifier();
    final challenge = _pkceChallenge(verifier);
    final state = _generateState();

    late HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        callbackPort,
      );
    } catch (e) {
      throw GitHubAuthException('无法启动本地回调服务(端口 $callbackPort 被占用): $e');
    }

    final completer = Completer<String>();
    final timeout = Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        completer.completeError(GitHubAuthException('授权超时，请重试', true));
      }
    });
    final cancelWatch = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (shouldCancel?.call() == true && !completer.isCompleted) {
        completer.completeError(GitHubAuthException('已取消授权', true));
      }
    });

    server.listen((req) async {
      final reqUri = req.uri;
      if (reqUri.path == callbackPath) {
        final err = reqUri.queryParameters['error'];
        if (err != null) {
          _sendHtml(req, 'Authorization failed: $err');
          if (!completer.isCompleted) {
            completer.completeError(GitHubAuthException('授权被拒绝: $err', true));
          }
          return;
        }
        final gotState = reqUri.queryParameters['state'];
        final code = reqUri.queryParameters['code'];
        if (gotState != state) {
          _sendHtml(req, 'State mismatch — authorization rejected.');
          if (!completer.isCompleted) {
            completer.completeError(GitHubAuthException('状态校验失败'));
          }
          return;
        }
        _sendHtml(req, 'Authorization complete. You may close this tab.');
        if (!completer.isCompleted && code != null) completer.complete(code);
        return;
      }
      _sendHtml(req, 'Free Note');
    });

    try {
      final authorizeUrl = buildAuthorizeUrl(
        clientId: clientId,
        state: state,
        codeChallenge: challenge,
        redirectUri: redirectUri,
      );
      if (await canLaunchUrl(authorizeUrl)) {
        await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication);
      } else {
        throw GitHubAuthException('无法打开浏览器进行授权');
      }
      final code = await completer.future;
      return await _exchangeCode(
        clientId: clientId,
        code: code,
        redirectUri: redirectUri,
        verifier: verifier,
      );
    } finally {
      timeout.cancel();
      cancelWatch.cancel();
      await server.close();
    }
  }
}
