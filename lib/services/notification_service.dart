import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../utils/notification_timezone.dart';
import 'windows_notifications.dart';

/// Real OS notifications.
///
/// Channels:
/// - `tasks`     (Android): scheduled task reminders
/// - `pomodoro`  (Android): pomodoro phase complete (immediate)
/// - `sync`      (Android): GitHub sync success / failure
/// - `updates`   (Android): new release available
///
/// Backends:
/// - Android / iOS / macOS / Linux: [FlutterLocalNotificationsPlugin].
/// - Windows: [WindowsNotifications] (PowerShell WinRT toast bridge).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const _channelTasks = 'tasks';
  static const _channelPomodoro = 'pomodoro';
  static const _channelSync = 'sync';
  static const _channelUpdates = 'updates';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (Platform.isWindows) {
      _ready = true;
      return;
    }
    initLocalTimezone();
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
    // Notification posting (Android 13+) and exact alarms (Android 12+).
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// Cancel any existing notifications for the given task id.
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(taskId.hashCode);
    } catch (_) {}
  }

  /// Schedule a notification at the task's [Task.reminder]. [title] is the
  /// localized reminder label.
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
        _channelTasks,
        '任务提醒',
        channelDescription: 'Plan tasks with reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        task.id.hashCode,
        title,
        task.title,
        when,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Best-effort: SCHEDULE_EXACT_ALARM may be denied on some Android
      // versions; the OS still surfaces the reminder roughly on time.
    }
  }

  /// Show an immediate notification in the [channel]. Channels:
  /// `tasks` (default) / `pomodoro` / `sync` / `updates`.
  Future<void> showNotification(
    String title,
    String body, {
    String channel = _channelSync,
    int? id,
  }) async {
    final notifId = id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (Platform.isWindows) {
      await WindowsNotifications.instance.show(title, body);
      return;
    }
    if (!_ready) return;
    final (channelName, channelDesc) = _channelMeta(channel);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelSync,
        '应用通知',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    // Per-channel details.
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    final fullDetails = NotificationDetails(
      android: androidDetails,
      iOS: details.iOS,
    );
    try {
      await _plugin.show(notifId, title, body, fullDetails);
    } catch (_) {}
  }

  (String, String) _channelMeta(String channel) {
    switch (channel) {
      case _channelTasks:
        return ('任务提醒', 'Plan tasks with reminders');
      case _channelPomodoro:
        return ('番茄钟', 'Pomodoro phase complete');
      case _channelUpdates:
        return ('应用更新', 'New version available');
      case _channelSync:
      default:
        return ('应用通知', 'General app notifications');
    }
  }

  /// Convenience wrappers used by callers that don't care which channel.
  Future<void> showPomodoroDone(String title, String body) =>
      showNotification(title, body, channel: _channelPomodoro);
  Future<void> showSync(String title, String body) =>
      showNotification(title, body, channel: _channelSync);
  Future<void> showUpdate(String title, String body) =>
      showNotification(title, body, channel: _channelUpdates);
}
