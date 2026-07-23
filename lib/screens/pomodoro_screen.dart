import 'dart:async';
import 'package:flutter/material.dart';
import '../services/pomodoro_service.dart';
import '../l10n/app_localizations.dart';

/// Pomodoro timer screen.
///
/// Cycles through focus / short-break / long-break phases. A long break is
/// taken every [PomodoroConfig.longBreakEvery] completed focus sessions. The
/// durations are persisted via [PomodoroService].
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroConfig _config = const PomodoroConfig();
  String _phase = PomodoroConfig.phaseWork;
  int _remaining = 25 * 60;
  int _total = 25 * 60;
  int _completed = 0;
  bool _running = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await PomodoroService.instance.load();
    if (mounted) {
      setState(() {
        _config = cfg;
        _total = cfg.secondsForPhase(_phase);
        _remaining = _total;
      });
    }
  }

  void _tick() {
    if (_remaining > 0) {
      setState(() => _remaining--);
    } else {
      _onPhaseComplete();
    }
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _running = false);
  }

  void _reset() {
    _pause();
    if (mounted) {
      setState(() {
        _phase = PomodoroConfig.phaseWork;
        _completed = 0;
        _total = _config.secondsForPhase(_phase);
        _remaining = _total;
      });
    }
  }

  void _onPhaseComplete() {
    final l10n = AppLocalizations.of(context);
    if (_phase == PomodoroConfig.phaseWork) {
      _completed++;
    }
    final next = nextPomodoroPhase(_phase, _completed, _config.longBreakEvery);
    if (mounted) {
      setState(() {
        _phase = next;
        _total = _config.secondsForPhase(next);
        _remaining = _total;
        _running = false;
      });
    }
    _timer?.cancel();
    _timer = null;
    if (l10n != null && mounted) {
      final msg = _phase == PomodoroConfig.phaseWork
          ? l10n.t('pomodoroFocus')
          : (_phase == PomodoroConfig.phaseLong
              ? l10n.t('pomodoroLongBreak')
              : l10n.t('pomodoroShortBreak'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.t('pomodoro')}: $msg')),
      );
    }
  }

  Future<void> _editSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final workCtl = TextEditingController(text: '${_config.workMinutes}');
    final shortCtl =
        TextEditingController(text: '${_config.shortBreakMinutes}');
    final longCtl =
        TextEditingController(text: '${_config.longBreakMinutes}');
    final everyCtl = TextEditingController(text: '${_config.longBreakEvery}');

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('pomodoroSettings')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: workCtl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.t('pomodoroWorkMinutes')),
              ),
              TextField(
                controller: shortCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: l10n.t('pomodoroShortMinutes')),
              ),
              TextField(
                controller: longCtl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.t('pomodoroLongMinutes')),
              ),
              TextField(
                controller: everyCtl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.t('pomodoroInterval')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (changed != true) return;

    int parse(TextEditingController c, int d) {
      final v = int.tryParse(c.text);
      return (v != null && v > 0) ? v : d;
    }
    final newCfg = _config.copyWith(
      workMinutes: parse(workCtl, 25),
      shortBreakMinutes: parse(shortCtl, 5),
      longBreakMinutes: parse(longCtl, 15),
      longBreakEvery: parse(everyCtl, 4),
    );
    await PomodoroService.instance.save(newCfg);
    if (mounted) {
      setState(() {
        _config = newCfg;
        // If idle at the start of a phase, reflect the new duration now.
        if (!_running) {
          _total = newCfg.secondsForPhase(_phase);
          _remaining = _total;
        }
      });
    }
  }

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  (String, Color) _phaseLabelColor(AppLocalizations l10n, ThemeData theme) {
    switch (_phase) {
      case PomodoroConfig.phaseWork:
        return (l10n.t('pomodoroFocus'), theme.colorScheme.error);
      case PomodoroConfig.phaseLong:
        return (l10n.t('pomodoroLongBreak'), theme.colorScheme.primary);
      default:
        return (l10n.t('pomodoroShortBreak'), Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (label, color) = _phaseLabelColor(l10n, theme);
    final progress = _total > 0 ? 1 - (_remaining / _total) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('pomodoro')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.t('pomodoroSettings'),
            onPressed: _editSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    color: color,
                  ),
                ),
                Text(
                  _format(_remaining),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _running ? l10n.t('pomodoroPause') : l10n.t('pomodoroStart'),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.t('pomodoroReset')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.tArgs('pomodoroSessions', ['$_completed']),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
