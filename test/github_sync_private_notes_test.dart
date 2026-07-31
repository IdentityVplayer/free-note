import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:free_note/models/note.dart';
import 'package:free_note/services/github_sync_service.dart';

/// A minimal stand-in for `package:http/testing`'s `MockClient` so we can drive
/// GitHubSyncService.syncNotes without any network access or extra deps.
class _MockClient extends http.BaseClient {
  _MockClient(this._handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

http.StreamedResponse _jsonResponse(int status, Map<String, dynamic> body) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
    status,
  );
}

/// Build the mock HTTP handler. [uploaded] / [deleted] are filled with the
/// repo-relative paths the sync service tried to PUT / DELETE so tests can
/// assert on them.
Future<http.StreamedResponse> Function(http.BaseRequest) _makeHandler(
  List<String> uploaded,
  List<String> deleted,
) {
  return (http.BaseRequest request) {
    // Decode percent-encoded segments (e.g. "Public%20Note.md" → "Public Note.md")
    // so assertions can match the repo-relative paths we expect.
    final path = Uri.decodeFull(request.url.path);
    const marker = '/contents/';

    if (request.method == 'GET' && path.endsWith('/git/refs/heads/main')) {
      return Future.value(
        _jsonResponse(200, {
          'object': {'sha': 'abc123'},
        }),
      );
    }
    if (request.method == 'GET' && path.contains('/git/trees/')) {
      // Remote already has: a pre-existing private note (same path as the
      // local private note) and a stale public file that no longer exists.
      return Future.value(
        _jsonResponse(200, {
          'tree': [
            {'path': 'notes/私人笔记/Secret.md', 'type': 'blob', 'sha': 'sha_priv'},
            {'path': 'notes/old-public.md', 'type': 'blob', 'sha': 'sha_old'},
          ],
        }),
      );
    }
    if (request.method == 'PUT' && path.contains(marker)) {
      uploaded.add(path.substring(path.indexOf(marker) + marker.length));
      return Future.value(
        _jsonResponse(201, {
          'content': {'sha': 'newsha'},
        }),
      );
    }
    if (request.method == 'DELETE' && path.contains(marker)) {
      deleted.add(path.substring(path.indexOf(marker) + marker.length));
      return Future.value(_jsonResponse(200, {}));
    }
    return Future.value(_jsonResponse(404, {}));
  };
}

/// Handler variant for [GitHubSyncService.pullNotes]: serves the tree and
/// returns valid frontmatter markdown for the public note. [contentGets] is
/// filled with every `contents/...` path actually fetched, so tests can assert
/// that private notes are never downloaded.
Future<http.StreamedResponse> Function(http.BaseRequest) _makePullHandler(
  List<String> contentGets,
) {
  return (http.BaseRequest request) {
    final path = Uri.decodeFull(request.url.path);
    if (request.method == 'GET' && path.endsWith('/git/refs/heads/main')) {
      return Future.value(
        _jsonResponse(200, {
          'object': {'sha': 'abc123'},
        }),
      );
    }
    if (request.method == 'GET' && path.contains('/git/trees/')) {
      return Future.value(
        _jsonResponse(200, {
          'tree': [
            {'path': 'notes/私人笔记/Secret.md', 'type': 'blob', 'sha': 'sha_priv'},
            {'path': 'notes/public.md', 'type': 'blob', 'sha': 'sha_pub'},
          ],
        }),
      );
    }
    if (request.method == 'GET' && path.contains('/contents/')) {
      contentGets.add(path);
      if (path.contains('notes/public.md')) {
        const md =
            '---\n'
            'id: pub1\n'
            'title: Public Note\n'
            'tags: []\n'
            'pinned: false\n'
            'favorite: false\n'
            'createdAt: 2024-01-01T00:00:00.000\n'
            'updatedAt: 2024-01-01T00:00:00.000\n'
            '---\n\n'
            'Hello from public\n';
        return Future.value(
          _jsonResponse(200, {
            'content': base64Encode(utf8.encode(md)).replaceAll('\n', ''),
            'sha': 'sha_pub',
          }),
        );
      }
      return Future.value(
        _jsonResponse(200, {
          'content': base64Encode(utf8.encode('---')),
          'sha': 'x',
        }),
      );
    }
    return Future.value(_jsonResponse(404, {}));
  };
}

Note _note(String id, String title, String content, {String? relativePath}) =>
    Note(
      id: id,
      title: title,
      content: content,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      relativePath: relativePath,
    );

void main() {
  group('isPathPrivate (shared exclusion rule)', () {
    test('true inside the private folder or its subfolders', () {
      expect(isPathPrivate('私人笔记/Secret.md'), isTrue);
      expect(isPathPrivate('私人笔记/sub/Deep.md'), isTrue);
      expect(isPathPrivate('私人笔记'), isTrue); // the folder itself
      expect(isPathPrivate('a/b/私人笔记/c.md'), isTrue);
    });

    test(
      'false for non-private paths (including a file merely named like it)',
      () {
        expect(isPathPrivate('Public Note.md'), isFalse);
        expect(isPathPrivate('sub/Public.md'), isFalse);
        // A top-level file named "私人笔记.md" is NOT inside the folder — must NOT
        // be excluded, otherwise a legitimately-named public note would vanish.
        expect(isPathPrivate('notes/私人笔记.md'), isFalse);
        expect(isPathPrivate(''), isFalse);
      },
    );

    test('Note.isPrivate delegates to isPathPrivate', () {
      // Inside the private folder → private.
      final n = _note('x', 'S', 'body', relativePath: '私人笔记/S.md');
      expect(n.isPrivate, isTrue);
      final nested = _note('z', '日记', 'body', relativePath: '私人笔记/sub/日记.md');
      expect(nested.isPrivate, isTrue);
      // Outside the private folder → not private, even if the title mentions it.
      final pub = _note('y', '私人笔记日记', 'body', relativePath: 'Public.md');
      expect(pub.isPrivate, isFalse);
    });
  });

  group('GitHubSyncService.syncNotes — private notes stay local-only', () {
    late List<String> uploaded;
    late List<String> deleted;

    setUp(() {
      uploaded = [];
      deleted = [];
    });

    test(
      'private note is NOT uploaded, but its remote copy is preserved',
      () async {
        final publicNote = _note(
          '1',
          'Public Note',
          'hello',
          relativePath: 'Public Note.md',
        );
        final privateNote = _note(
          '2',
          'Secret',
          'top secret',
          relativePath: '私人笔记/Secret.md',
        );

        final result = await http.runWithClient(
          () => GitHubSyncService(
            token: 'tok',
            repo: 'a/b',
          ).syncNotes([publicNote, privateNote]),
          () => _MockClient(_makeHandler(uploaded, deleted)),
        );

        expect(result.success, isTrue);

        // 1) The public note IS uploaded.
        expect(uploaded, contains('notes/Public Note.md'));

        // 2) The private note is NEVER uploaded — the core privacy guarantee.
        expect(uploaded, isNot(contains('notes/私人笔记/Secret.md')));

        // 3) The pre-existing remote copy of the private note is preserved
        //    (added to localPaths, so it is not deleted).
        expect(deleted, isNot(contains('notes/私人笔记/Secret.md')));

        // 4) Stale public files are still cleaned up — deletion still works.
        expect(deleted, contains('notes/old-public.md'));
      },
    );

    test(
      'a private note nested in a subfolder is also excluded from upload',
      () async {
        final privateNested = _note(
          '3',
          'Deep',
          'body',
          relativePath: '私人笔记/sub/Deep.md',
        );

        final result = await http.runWithClient(
          () => GitHubSyncService(
            token: 'tok',
            repo: 'a/b',
          ).syncNotes([privateNested]),
          () => _MockClient(_makeHandler(uploaded, deleted)),
        );

        expect(result.success, isTrue);
        expect(uploaded, isEmpty);
        expect(uploaded.any((p) => p.contains('私人笔记')), isFalse);
      },
    );
  });

  group('GitHubSyncService.pullNotes — private notes never imported', () {
    test('private notes are skipped and never fetched from GitHub', () async {
      final contentGets = <String>[];
      final result = await http.runWithClient(
        () => GitHubSyncService(token: 'tok', repo: 'a/b').pullNotes(),
        () => _MockClient(_makePullHandler(contentGets)),
      );

      expect(result, isNotNull);
      // The private note's contents are never downloaded.
      expect(contentGets.any((p) => p.contains('私人笔记')), isFalse);
      // Exactly one note is pulled — the public one.
      expect(result!.notes.length, 1);
      expect(result.notes.first.relativePath, 'public.md');
    });
  });
}
