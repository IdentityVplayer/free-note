import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/pomodoro_profile.dart';
import 'package:free_note/services/pomodoro_service.dart';

void main() {
  test('stats aggregates focus and break seconds per period', () async {
    final dir = Directory.systemTemp.createTempSync('pomstats');
    PomodoroService.instance.debugSetDir(dir);
    await PomodoroService.instance.load();

    await PomodoroService.instance.recordSession(
      PomodoroProfile.phaseWork,
      25 * 60,
    );
    await PomodoroService.instance.recordSession(
      PomodoroProfile.phaseShort,
      5 * 60,
    );

    final stats = PomodoroService.instance.stats();
    expect(stats['today']!.focusSeconds, 25 * 60);
    expect(stats['today']!.breakSeconds, 5 * 60);
    // Today's sessions also fall inside the wider week/month/year windows.
    expect(stats['week']!.focusSeconds, 25 * 60);
    expect(stats['month']!.breakSeconds, 5 * 60);
    expect(stats['year']!.focusSeconds, 25 * 60);
  });
}
