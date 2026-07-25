/// Pure, testable helpers for the reminder/repeat feature.
///
/// (The hierarchical "subtask" auto-complete and fresh-copy helpers were
/// removed in v1.15.4 when the subtask feature itself was dropped.)
library;

import 'package:free_note/models/task.dart';

/// The next occurrence of a repeating reminder, [every] [unit]s after [base].
DateTime nextRepeatDue(DateTime base, RepeatConfig r) {
  switch (r.unit) {
    case 'hour':
      return base.add(Duration(hours: r.every));
    case 'day':
      return base.add(Duration(days: r.every));
    case 'week':
      return base.add(Duration(days: 7 * r.every));
    case 'month':
      return DateTime(
        base.year,
        base.month + r.every,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    case 'year':
      return DateTime(
        base.year + r.every,
        base.month,
        base.day,
        base.hour,
        base.minute,
        base.second,
      );
    default:
      return base.add(Duration(days: r.every));
  }
}
