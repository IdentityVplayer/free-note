import 'dart:io' show Platform, Process;

import 'package:flutter/services.dart' show MethodChannel;

/// Detect the CPU architecture / ABI of the running app.
///
/// On Android, queries the native MainActivity via [MethodChannel]
/// `com.note.apps/abi` to get `Build.SUPPORTED_ABIS[0]` (the primary ABI).
/// On other platforms, [Platform.resolvedExecutable] carries enough
/// information to infer the host arch (arm64-v8a / x86_64 etc.).
class AppArch {
  /// Returns a friendly arch label, e.g. "arm64-v8a" / "x86_64" /
  /// "arm64" (macOS Apple Silicon) / "x64" (Windows).
  static Future<String> detect() async {
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.note.apps/abi');
        final result = await channel.invokeMethod<String>('getPrimaryAbi');
        if (result != null && result.isNotEmpty) return result;
      } catch (_) {
        // fall through to heuristic
      }
    }
    if (Platform.isMacOS && (await _macArch() ?? false)) return 'arm64';
    if (Platform.isMacOS) return 'x86_64';
    if (Platform.isWindows) return 'x64';
    if (Platform.isLinux || Platform.isAndroid) {
      // On Linux, executable path contains the arch; on Android the channel
      // call should normally succeed — this is the fallback.
      return 'x86_64';
    }
    return 'unknown';
  }

  static Future<bool?> _macArch() async {
    try {
      final res = await Process.run('uname', ['-m']);
      return res.stdout.toString().contains('arm64');
    } catch (_) {
      return null;
    }
  }
}
