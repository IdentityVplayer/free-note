import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:path/path.dart' as p;

/// Download an APK to [destPath] using `curl`, with real-time progress
/// reported to [onProgress] (values 0..100). Returns `true` on success.
///
/// On Android, `curl` is not available in user space; we fall back to a
/// Dart `http` byte-stream download that polls the local file size for
/// indeterminate progress (the percentage may take a moment to stabilize).
class CurlDownloader {
  /// Returns `true` if `curl` is on PATH (used to decide between curl and
  /// the Dart HTTP fallback).
  static Future<bool> isCurlAvailable() async {
    if (Platform.isAndroid || Platform.isIOS) return false;
    try {
      final res = await Process.run('curl', ['--version']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns the content length of [url] via a HEAD request, or -1 if
  /// the server doesn't return it.
  static Future<int> headContentLength(String url) async {
    try {
      final client = HttpClient();
      final req = await client.openUrl('HEAD', Uri.parse(url));
      final res = await req.close();
      final len = res.contentLength;
      res.drain();
      client.close(force: true);
      return len;
    } catch (_) {
      return -1;
    }
  }

  /// Download [url] to [destPath]. The callback receives a percentage
  /// 0..100; values may briefly dip while the content-length is being
  /// discovered.
  static Future<bool> download(
    String url,
    String destPath, {
    required void Function(int percent) onProgress,
  }) async {
    if (await isCurlAvailable()) {
      return _downloadWithCurl(url, destPath, onProgress: onProgress);
    }
    return _downloadWithHttp(url, destPath, onProgress: onProgress);
  }

  /// Run `curl -L -f -# -o dest url` and parse its stderr progress meter.
  static Future<bool> _downloadWithCurl(
    String url,
    String destPath, {
    required void Function(int percent) onProgress,
  }) async {
    // Make sure the destination directory exists.
    Directory(p.dirname(destPath)).createSync(recursive: true);
    final proc = await Process.start('curl', [
      '-L', // follow redirects (xget CDN may redirect)
      '-f', // fail fast on HTTP errors (4xx/5xx)
      '-#', // progress bar to stderr
      '-o', destPath,
      url,
    ]);

    final totalBytes = await headContentLength(url);

    // Parse curl's stderr for percentages. curl uses \r to overwrite the
    // line; we receive the data as chunks that we split into lines.
    final buffer = StringBuffer();
    proc.stderr.listen((chunk) {
      buffer.write(String.fromCharCodes(chunk));
      final s = buffer.toString();
      // Split on either \n or \r — curl updates in-place with \r.
      final lastLine = s
          .split(RegExp('[\r\n]'))
          .lastWhere((l) => l.contains('%'), orElse: () => '');
      final pctMatch = RegExp(r'(\d{1,3}(?:\.\d+)?)\s*%').firstMatch(lastLine);
      if (pctMatch != null) {
        final pct = double.tryParse(pctMatch.group(1)!)?.round() ?? 0;
        onProgress(pct.clamp(0, 100));
      }
      // Trim processed text so we only parse the fresh tail.
      if (buffer.length > 4096) {
        buffer.clear();
      }
    }, onError: (_) {});

    final exitCode = await proc.exitCode;
    if (exitCode != 0) {
      return false;
    }
    if (totalBytes > 0) {
      onProgress(100);
    }
    return true;
  }

  /// HTTP fallback (used when curl isn't available, e.g. on Android).
  /// Streams bytes from the URL to disk and reports percentage based on the
  /// file size vs. the server's content-length.
  static Future<bool> _downloadWithHttp(
    String url,
    String destPath, {
    required void Function(int percent) onProgress,
  }) async {
    Directory(p.dirname(destPath)).createSync(recursive: true);
    final uri = Uri.parse(url);
    final client = HttpClient();
    final req = await client.openUrl('GET', uri);
    final res = await req.close();
    if (res.statusCode != 200) {
      client.close(force: true);
      return false;
    }
    final total = res.contentLength;
    final file = File(destPath);
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress(((received / total) * 100).clamp(0, 100).round());
      } else {
        // Indeterminate — emit values 1..99 so the bar still moves.
        onProgress((received ~/ 100000) % 99 + 1);
      }
    }
    await sink.flush();
    await sink.close();
    client.close(force: true);
    onProgress(100);
    return true;
  }

  /// Open the given APK file with the OS default installer.
  ///
  /// On Android this dispatches a MethodChannel to MainActivity which fires
  /// `Intent.ACTION_VIEW` with `application/vnd.android.package-archive`.
  /// On desktop we shell out to the platform's `open`/`xdg-open`/`start`.
  static Future<void> installApk(String filePath) async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.note.apps/abi');
        await channel.invokeMethod('installApk', {'path': filePath});
        return;
      } catch (_) {
        // fall through to OS open
      }
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    }
  }
}
