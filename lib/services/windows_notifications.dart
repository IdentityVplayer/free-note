import 'dart:io';

/// Native Windows 10/11 toast notifications.
///
/// `flutter_local_notifications` (the plugin used on Android/iOS/macOS/Linux)
/// does not ship a Windows implementation, so on Windows we talk to the OS
/// directly through PowerShell's WinRT toast bridge. This keeps the Windows
/// build green (no unsupported plugin) while still producing real system
/// toasts.
///
/// All calls are best-effort: any failure (e.g. PowerShell missing, WinRT
/// unavailable) is swallowed so a notification problem can never crash the app.
class WindowsNotifications {
  static final WindowsNotifications instance = WindowsNotifications._();
  WindowsNotifications._();

  static const String _appId = 'Free Note';

  /// Show an immediate toast with [title] and [body].
  Future<void> show(String title, String body) async {
    if (!Platform.isWindows) return;
    try {
      await Process.run(
        'powershell.exe',
        ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', _toastScript(title, body)],
        runInShell: false,
      );
    } catch (_) {
      // Best-effort: ignore (PowerShell/WinRT unavailable).
    }
  }

  /// Schedule a toast to appear at [due]. Implemented via Windows Task
  /// Scheduler: the toast script is written to a temp `.ps1` and a one-shot
  /// scheduled task runs it at the due time (works whether the app is open or
  /// closed).
  Future<void> schedule(DateTime due, String title, String body, int id) async {
    if (!Platform.isWindows) return;
    try {
      final ps1 = File('${Directory.systemTemp.path}/freennote_reminder_$id.ps1');
      await ps1.writeAsString(_toastScript(title, body));
      final taskName = 'FreeNote-Reminder-$id';
      final register = '''
\$a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -File \\"${ps1.path}\\""
\$t = New-ScheduledTaskTrigger -Once -At (Get-Date "${_iso(due)}")
Unregister-ScheduledTask -TaskName "$taskName" -Confirm:\$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "$taskName" -Action \$a -Trigger \$t -Force
''';
      await Process.run(
        'powershell.exe',
        ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', register],
        runInShell: false,
      );
    } catch (_) {
      // Best-effort: ignore scheduling failures.
    }
  }

  /// Build a PowerShell script that raises a WinRT toast with the given text.
  String _toastScript(String title, String body) {
    final t = _escapePs(title);
    final b = _escapePs(body);
    return '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
\$text = \$template.GetElementsByTagName('text')
\$text.Item(0).AppendChild(\$template.CreateTextNode('$t')) | Out-Null
\$text.Item(1).AppendChild(\$template.CreateTextNode('$b')) | Out-Null
\$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$_appId')
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template)
\$notifier.Show(\$toast)
''';
  }

  /// Escape text for a PowerShell single-quoted string: double single quotes
  /// and drop newlines (which would break the single-quoted line).
  String _escapePs(String s) =>
      s.replaceAll("'", "''").replaceAll(RegExp(r'\r?\n'), ' ');

  /// Format [due] as a PowerShell `Get-Date`-parseable ISO string.
  String _iso(DateTime due) => due.toIso8601String();
}
