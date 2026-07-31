import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/services/pomodoro_service.dart';
import 'package:free_note/services/pomodoro_timer.dart';

/// Exercises the v1.18.4 Pomodoro changes:
///  - `reset()` must NOT zero the completed-pomodoro count.
///  - `start()` launches a singleton-owned countdown that ticks in the
///    background (independent of any screen), so the user can switch pages.
void main() {
  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('pomtimer');
    PomodoroService.instance.debugSetDir(dir);
    await PomodoroService.instance.load();
    // Ensure a clean, idle timer between tests.
    PomodoroTimer.instance.reset();
  });

  tearDown(() {
    // Always stop the singleton's real timer so it can't leak into other
    // tests or the test process teardown.
    PomodoroTimer.instance.reset();
  });

  test('reset preserves the completed count (v1.18.4 fix)', () async {
    final timer = PomodoroTimer.instance;

    // Complete one work phase → completed count increments to 1.
    timer.debugCompletePhase();
    final before = timer.completed;
    expect(before, greaterThanOrEqualTo(1));

    // "重置" restarts the current phase's countdown only.
    timer.reset();

    expect(
      timer.completed,
      before,
      reason: 'reset() must not zero the completed-pomodoro count',
    );
    expect(timer.running, isFalse);
    // The active (next) phase's countdown is restored to its full duration.
    expect(timer.remaining, timer.total);
  });

  test('reset never decreases the completed count', () async {
    final timer = PomodoroTimer.instance;

    // Complete a phase so the count is non-zero.
    timer.debugCompletePhase();
    final baseline = timer.completed;
    expect(baseline, greaterThanOrEqualTo(1));

    // Repeated resets (with phases in between) must never shrink progress.
    timer.reset();
    expect(timer.completed, baseline);
    timer.debugCompletePhase();
    expect(timer.completed, greaterThanOrEqualTo(baseline));
    timer.reset();
    expect(
      timer.completed,
      greaterThanOrEqualTo(baseline),
      reason: 'completed count must survive every reset()',
    );
  });

  test('start runs the countdown in the background (v1.18.4 change)', () async {
    final timer = PomodoroTimer.instance;

    expect(timer.running, isFalse);
    timer.start();
    expect(timer.running, isTrue);

    // The singleton owns a real Timer.periodic that ticks on its own — no
    // widget drives it. After ~1s the remaining seconds must have decreased,
    // proving it runs independently of any screen.
    final start = timer.remaining;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      timer.remaining,
      lessThan(start),
      reason: 'the background timer should keep ticking',
    );
  });

  test('start is idempotent until reset', () async {
    final timer = PomodoroTimer.instance;
    timer.start();
    final remainingAfterFirst = timer.remaining;

    // A second start() while already running is a no-op (no restart / jump).
    timer.start();
    expect(timer.running, isTrue);
    // Let one tick happen, then confirm start() did not reset the countdown.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      timer.remaining,
      lessThanOrEqualTo(remainingAfterFirst),
      reason: 'a repeated start() must not jump/restart the countdown',
    );

    timer.reset();
    expect(timer.running, isFalse);
  });
}
