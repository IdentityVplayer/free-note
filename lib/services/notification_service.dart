import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/task.dart';

/// Real OS notifications. On Android this shows a system notification; on
/// iOS/macOS/Linux it uses the platform channel. (Windows toast support lands
/// with a newer flutter_local_notifications release; the reminder/repeat
/// respawn logic in [TaskService] is platform-independent and runs everywhere.)
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
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
    if (!_ready || task.reminder == null) return;
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
