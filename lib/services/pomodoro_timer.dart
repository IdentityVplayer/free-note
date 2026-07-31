import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../models/pomodoro_profile.dart';
import 'notification_service.dart';
import 'pomodoro_service.dart';

/// Owns the running Pomodoro countdown so it keeps ticking even when the user
/// navigates away from the Pomodoro screen (v1.18.4). The screen renders this
/// state and issues start / pause / reset commands; this singleton is never
/// disposed during the app's lifetime, so the timer survives page switches
/// (e.g. opening a note) and only the screen's view is torn down.
///
/// Both the "started" and the "phase complete" notifications are posted from
/// here, so the user is alerted even when no Pomodoro screen is mounted.
class PomodoroTimer extends ChangeNotifier {
  static final PomodoroTimer instance = PomodoroTimer._();
  PomodoroTimer._();

  String _phase = PomodoroProfile.phaseWork;
  int _remaining = 25 * 60;
  int _total = 25 * 60;
  int _completed = 0;
  bool _running = false;
  Timer? _timer;

  String get phase => _phase;
  int get remaining => _remaining;
  int get total => _total;
  int get completed => _completed;
  bool get running => _running;

  /// Sync to the active profile when idle. Never disturbs an in-progress
  /// session. Called once when the Pomodoro screen first loads.
  void initFromActive() {
    if (_running) return;
    final active = PomodoroService.instance.active;
    _phase = PomodoroProfile.phaseWork;
    _total = active.secondsForPhase(_phase);
    _remaining = _total;
    notifyListeners();
  }

  /// Begin (or resume) the countdown and post a "started" notification.
  void start() {
    if (_running) return;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _notifyStarted();
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    notifyListeners();
  }

  /// Restart the *current* phase's countdown. Deliberately does NOT reset the
  /// completed-pomodoro count — "重置" restarts the timer, not the session
  /// progress (v1.18.4).
  void reset() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _remaining = _total;
    notifyListeners();
  }

  void _tick() {
    if (_remaining > 0) {
      _remaining--;
      notifyListeners();
    } else {
      _onPhaseComplete();
    }
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    final active = PomodoroService.instance.active;
    final finishedPhase = _phase;
    // Log the finished phase for the focus / break statistics.
    PomodoroService.instance.recordSession(finishedPhase, _total);
    if (finishedPhase == PomodoroProfile.phaseWork) _completed++;
    final next = nextPomodoroPhase(active, finishedPhase, _completed);
    _phase = next;
    _total = active.secondsForPhase(next);
    _remaining = _total;
    notifyListeners();
    _notifyDone(finishedPhase, next);
  }

  /// Switch the active profile: stop the timer and restart at that profile's
  /// work phase.
  void switchToProfile(String id) {
    PomodoroService.instance.setActive(id);
    _timer?.cancel();
    _timer = null;
    _running = false;
    _phase = PomodoroProfile.phaseWork;
    _total = PomodoroService.instance.active.secondsForPhase(_phase);
    _remaining = _total;
    notifyListeners();
  }

  /// Refresh the current phase's duration after an inline settings edit, but
  /// only while idle/paused at the phase start (so we never shrink a running
  /// countdown).
  void applyProfileDurations() {
    if (_running) return;
    _total = PomodoroService.instance.active.secondsForPhase(_phase);
    _remaining = _total;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Notifications (fire even when no screen is mounted) ──

  void _notifyStarted() {
    String t(String k) => AppLocalizations.current?.t(k) ?? k;
    NotificationService.instance.showPomodoroStarted(
      t('pomodoro'),
      t('pomodoroRunning'),
    );
  }

  void _notifyDone(String finishedPhase, String next) {
    String t(String k) => AppLocalizations.current?.t(k) ?? k;
    String label(String p) => p == PomodoroProfile.phaseWork
        ? t('pomodoroFocus')
        : (p == PomodoroProfile.phaseLong
              ? t('pomodoroLongBreak')
              : t('pomodoroShortBreak'));
    NotificationService.instance.showPomodoroDone(
      t('pomodoro'),
      '${label(finishedPhase)} → ${label(next)}',
    );
  }

  /// Force a phase completion without waiting for the real-time tick.
  /// Test-only seam.
  void debugCompletePhase() => _onPhaseComplete();
}
