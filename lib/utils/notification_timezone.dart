import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Initialise the `tz.local` location so that [tz.TZDateTime.from] on a
/// device-local [DateTime] preserves the user's wall-clock intent.
///
/// `tz.local` defaults to UTC after [tzdata.initializeTimeZones]; that
/// causes every scheduled reminder to land in UTC and fire at the wrong
/// hour on devices whose offset is not zero. We synthesize a location
/// name from the device's current UTC offset (e.g. `UTC+08:00`) and look
/// it up in the database — most common offsets are pre-populated.
void initLocalTimezone() {
  tzdata.initializeTimeZones();
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final name = 'UTC$sign$hours:$minutes';
  try {
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    // Fall back to the closest known fixed-offset location, or UTC.
    try {
      tz.setLocalLocation(
        tz.getLocation(
          'Etc/GMT${offset.isNegative ? '+' : '-'}${offset.inHours.abs()}',
        ),
      );
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }
}
