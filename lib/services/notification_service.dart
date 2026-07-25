import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../utils/notification_timezone.dart';
import 'windows_notifications.dart';

/// Real OS notifications.
///
/// Channels:
/// - `tasks`     (Android, IMPORTANCE max): scheduled task reminders with
///               interactive "OK" / "Ignore" buttons.
/// - `pomodoro`  (Android): pomodoro phase complete (immediate).
/// - `sync`      (Android): GitHub sync success / failure.
/// - `updates`   (Android): new release available.
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

  /// Darwin category identifier for task reminders (lets iOS present action
  /// buttons in the notification).
  static const _categoryTask = 'task_reminder';

  /// Action IDs used by both Android and iOS. The payload of every task
  /// reminder is the task's id, so [onTaskAction] can locate the task.
  static const actionOk = 'task_ok';
  static const actionIgnore = 'task_ignore';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Registered by [AppProvider] (or any other handler). Fires when the user
  /// taps an action button on a task reminder. The action is one of
  /// [actionOk] / [actionIgnore] / `''` (a tap on the notification body).
  void Function(String taskId, String actionId)? onTaskAction;

  Future<void> init() async {
    if (Platform.isWindows) {
      _ready = true;
      return;
    }
    initLocalTimezone();
    final android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          _categoryTask,
          actions: [
            DarwinNotificationAction.plain(
              actionOk,
              '完成',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              actionIgnore,
              '忽略',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    );
    final settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: LinuxInitializationSettings(defaultActionName: 'Free Note'),
    );
    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
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

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final action = response.actionId ?? '';
    onTaskAction?.call(payload, action);
  }

  /// Cancel any existing notifications for the given task id.
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(taskId.hashCode);
    } catch (_) {}
  }

  /// Schedule a notification at the task's [Task.reminder]. Posted as an
  /// IMPORTANT reminder with two action buttons:
  ///   - `OK` (`actionOk`)        — mark the task as done
  ///   - `Ignore` (`actionIgnore`) — dismiss without action
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

    const androidDetails = AndroidNotificationDetails(
      _channelTasks,
      '任务提醒',
      channelDescription: 'Plan tasks with reminders',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(actionOk, '完成', showsUserInterface: true),
        AndroidNotificationAction(actionIgnore, '忽略', cancelNotification: true),
      ],
    );
    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _categoryTask,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _plugin.zonedSchedule(
        task.id.hashCode,
        title,
        task.title,
        when,
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
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
    final androidDetails = AndroidNotificationDetails(
      channel,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    try {
      await _plugin.show(
        notifId,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
      );
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
