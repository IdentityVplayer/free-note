import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/task.dart';
import 'windows_notifications.dart';

/// Real OS notifications.
///
/// - Android / iOS / macOS / Linux: via `flutter_local_notifications`.
/// - Windows: via [WindowsNotifications] (PowerShell WinRT toast bridge),
///   because `flutter_local_notifications` does not ship a Windows
///   implementation. The reminder/respawn logic in [TaskService] is
///   platform-independent and runs everywhere.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (Platform.isWindows) {
      // Windows has no flutter_local_notifications backend; the native path
      // (WindowsNotifications) is always available.
      _ready = true;
      return;
    }
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: LinuxInitializationSettings(defaultActionName: 'Free Note'),
    );
    try {
      await _plugin.initialize(settings);
      _ready = true;
      await _requestPermission();
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> _requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
  }

  /// Schedule a notification at the task's [Task.reminder]. [title] is the
  /// localized reminder label. No-op if not initialized or the time passed.
  Future<void> scheduleReminder(Task task, {required String title}) async {
    if (task.reminder == null) return;
    if (Platform.isWindows) {
      await WindowsNotifications.instance.schedule(
        task.reminder!,
        title,
        task.title,
        task.reminder!.hashCode,
      );
      return;
    }
    if (!_ready) return;
    final when = tz.TZDateTime.from(task.reminder!, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks',
        'Tasks',
        channelDescription: 'Task reminders',
        importance: Importance.high,
      ),
    );
    await _plugin.zonedSchedule(
      task.reminder!.hashCode,
      title,
      task.title,
      when,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Show an immediate notification.
  Future<void> showNotification(String title, String body) async {
    if (Platform.isWindows) {
      await WindowsNotifications.instance.show(title, body);
      return;
    }
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks',
        'Tasks',
        importance: Importance.high,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
