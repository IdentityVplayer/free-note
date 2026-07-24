import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../models/pomodoro_profile.dart';
import '../models/pomodoro_session.dart';
import '../services/pomodoro_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';

/// Pomodoro timer screen.
///
/// Supports multiple named profiles (presets). The active profile drives the
/// timer; each profile may carry its own background image and an independent
/// long-break toggle. The durations are persisted via [PomodoroService].
class PomodoroScreen extends StatefulWidget {
  /// When true, opens the "new profile" dialog on first load (used by the
  /// home-screen FAB so a single tap creates a pomodoro).
  final bool autoAdd;

  const PomodoroScreen({super.key, this.autoAdd = false});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  List<PomodoroProfile> _profiles = const [
    PomodoroProfile(
      id: PomodoroService.defaultId,
      name: PomodoroService.defaultId,
    ),
  ];
  String _activeId = PomodoroService.defaultId;

  String _phase = PomodoroProfile.phaseWork;
  int _remaining = 25 * 60;
  int _total = 25 * 60;
  int _completed = 0;
  bool _running = false;
  Timer? _timer;

  PomodoroProfile get _active => _profiles.firstWhere(
    (p) => p.id == _activeId,
    orElse: () => _profiles.first,
  );

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
    final profiles = await PomodoroService.instance.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeId = PomodoroService.instance.active.id;
      _applyProfile(reset: true);
    });
    if (widget.autoAdd) _showProfileDialog();
  }

  /// Recompute the active profile and (when [reset]) restart the timer at the
  /// work phase with the new durations.
  void _applyProfile({bool reset = false}) {
    if (reset) {
      _pause();
      _phase = PomodoroProfile.phaseWork;
      _completed = 0;
      _total = _active.secondsForPhase(_phase);
      _remaining = _total;
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
        _phase = PomodoroProfile.phaseWork;
        _completed = 0;
        _total = _active.secondsForPhase(_phase);
        _remaining = _total;
      });
    }
  }

  void _onPhaseComplete() {
    final l10n = AppLocalizations.of(context);
    // Log the just-finished phase for the focus / break statistics.
    PomodoroService.instance.recordSession(
      _phase,
      _active.secondsForPhase(_phase),
    );
    if (_phase == PomodoroProfile.phaseWork) _completed++;
    final next = nextPomodoroPhase(_active, _phase, _completed);
    if (mounted) {
      setState(() {
        _phase = next;
        _total = _active.secondsForPhase(next);
        _remaining = _total;
        _running = false;
      });
    }
    _timer?.cancel();
    _timer = null;
    if (l10n != null && mounted) {
      final msg = _phase == PomodoroProfile.phaseWork
          ? l10n.t('pomodoroFocus')
          : (_phase == PomodoroProfile.phaseLong
                ? l10n.t('pomodoroLongBreak')
                : l10n.t('pomodoroShortBreak'));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.t('pomodoro')}: $msg')));
    }
  }

  Future<void> _switchProfile(String id) async {
    await PomodoroService.instance.setActive(id);
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _applyProfile(reset: true);
    });
  }

  Future<void> _pickBackground() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final dir = await StorageService.instance.configDir;
    final bgDir = Directory(p.join(dir.path, 'pomodoro_bg'));
    await bgDir.create(recursive: true);
    final dest = File(p.join(bgDir.path, '${_active.id}.jpg'));
    await File(picked.path).copy(dest.path);
    final updated = _active.copyWith(backgroundPath: dest.path);
    await PomodoroService.instance.updateProfile(updated);
    if (mounted) {
      setState(() {
        _profiles = _profiles
            .map((p) => p.id == updated.id ? updated : p)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('pomodoroBackgroundSet'))));
    }
  }

  Future<void> _clearBackground() async {
    final l10n = AppLocalizations.of(context)!;
    final path = _active.backgroundPath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {
        // best-effort
      }
    }
    final updated = _active.copyWith(clearBackground: true);
    await PomodoroService.instance.updateProfile(updated);
    if (mounted) {
      setState(() {
        _profiles = _profiles
            .map((p) => p.id == updated.id ? updated : p)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('pomodoroBackgroundCleared'))),
      );
    }
  }

  Future<void> _editSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final cfg = _active;
    final workCtl = TextEditingController(text: '${cfg.workMinutes}');
    final shortCtl = TextEditingController(text: '${cfg.shortBreakMinutes}');
    final longCtl = TextEditingController(text: '${cfg.longBreakMinutes}');
    final everyCtl = TextEditingController(text: '${cfg.longBreakEvery}');
    var longBreak = cfg.longBreakEnabled;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(l10n.t('pomodoroSettings')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: workCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroWorkMinutes'),
                  ),
                ),
                TextField(
                  controller: shortCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroShortMinutes'),
                  ),
                ),
                TextField(
                  controller: longCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroLongMinutes'),
                  ),
                ),
                TextField(
                  controller: everyCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroInterval'),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.t('pomodoroLongBreak')),
                  value: longBreak,
                  onChanged: (v) => setInner(() => longBreak = v),
                ),
                const SizedBox(height: 8),
                Text(l10n.t('pomodoroBackground')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: Text(l10n.t('pomodoroBackgroundFromAlbum')),
                        onPressed: () async {
                          Navigator.pop(ctx, true);
                          await _pickBackground();
                          if (mounted) _editSettings();
                        },
                      ),
                    ),
                    if (cfg.backgroundPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.t('pomodoroClearBackground'),
                        onPressed: () {
                          Navigator.pop(ctx, true);
                          _clearBackground();
                          if (mounted) _editSettings();
                        },
                      ),
                    ],
                  ],
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
      ),
    );
    if (changed != true) return;

    int parse(TextEditingController c, int d) {
      final v = int.tryParse(c.text);
      return (v != null && v > 0) ? v : d;
    }

    final newCfg = cfg.copyWith(
      workMinutes: parse(workCtl, 25),
      shortBreakMinutes: parse(shortCtl, 5),
      longBreakMinutes: parse(longCtl, 15),
      longBreakEvery: parse(everyCtl, 4),
      longBreakEnabled: longBreak,
    );
    await PomodoroService.instance.updateProfile(newCfg);
    if (mounted) {
      setState(() {
        _profiles = _profiles
            .map((p) => p.id == newCfg.id ? newCfg : p)
            .toList();
        if (!_running) {
          _total = newCfg.secondsForPhase(_phase);
          _remaining = _total;
        }
      });
    }
  }

  Future<void> _showProfileDialog({PomodoroProfile? existing}) async {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = existing != null;
    final nameCtl = TextEditingController(
      text: isEdit ? _profileName(existing) : '',
    );
    final workCtl = TextEditingController(
      text: '${isEdit ? existing.workMinutes : _active.workMinutes}',
    );
    final shortCtl = TextEditingController(
      text:
          '${isEdit ? existing.shortBreakMinutes : _active.shortBreakMinutes}',
    );
    final longCtl = TextEditingController(
      text: '${isEdit ? existing.longBreakMinutes : _active.longBreakMinutes}',
    );
    final everyCtl = TextEditingController(
      text: '${isEdit ? existing.longBreakEvery : _active.longBreakEvery}',
    );
    var longBreak = isEdit
        ? existing.longBreakEnabled
        : _active.longBreakEnabled;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(
            isEdit
                ? l10n.t('pomodoroRenameProfile')
                : l10n.t('pomodoroNewProfile'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  autofocus: !isEdit,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroProfileName'),
                  ),
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                ),
                TextField(
                  controller: workCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroWorkMinutes'),
                  ),
                ),
                TextField(
                  controller: shortCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroShortMinutes'),
                  ),
                ),
                TextField(
                  controller: longCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroLongMinutes'),
                  ),
                ),
                TextField(
                  controller: everyCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('pomodoroInterval'),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.t('pomodoroLongBreak')),
                  value: longBreak,
                  onChanged: (v) => setInner(() => longBreak = v),
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
      ),
    );
    if (ok != true) return;
    final name = nameCtl.text.trim();
    if (name.isEmpty) return;

    int parse(TextEditingController c, int d) {
      final v = int.tryParse(c.text);
      return (v != null && v > 0) ? v : d;
    }

    if (isEdit) {
      final updated = existing.copyWith(
        name: name,
        workMinutes: parse(workCtl, 25),
        shortBreakMinutes: parse(shortCtl, 5),
        longBreakMinutes: parse(longCtl, 15),
        longBreakEvery: parse(everyCtl, 4),
        longBreakEnabled: longBreak,
      );
      await PomodoroService.instance.updateProfile(updated);
      if (mounted) {
        setState(() {
          _profiles = _profiles
              .map((p) => p.id == updated.id ? updated : p)
              .toList();
        });
      }
    } else {
      final profile = PomodoroProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        workMinutes: parse(workCtl, 25),
        shortBreakMinutes: parse(shortCtl, 5),
        longBreakMinutes: parse(longCtl, 15),
        longBreakEvery: parse(everyCtl, 4),
        longBreakEnabled: longBreak,
      );
      await PomodoroService.instance.addProfile(profile);
      await PomodoroService.instance.setActive(profile.id);
      if (mounted) {
        setState(() {
          _profiles = [..._profiles, profile];
          _activeId = profile.id;
          _applyProfile(reset: true);
        });
      }
    }
  }

  Future<void> _confirmDeleteProfile(PomodoroProfile profile) async {
    final l10n = AppLocalizations.of(context)!;
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('pomodoroKeepOne'))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('pomodoroDeleteProfile')),
        content: Text(
          '${l10n.t('pomodoroDeleteProfileConfirm')} "${_profileName(profile)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      // remove background file if any
      if (profile.backgroundPath != null) {
        try {
          File(profile.backgroundPath!).deleteSync();
        } catch (_) {
          // ignore
        }
      }
      await PomodoroService.instance.removeProfile(profile.id);
      if (mounted) {
        setState(() {
          _profiles = _profiles.where((p) => p.id != profile.id).toList();
          if (_activeId == profile.id) {
            _activeId = _profiles.first.id;
            _applyProfile(reset: true);
          }
        });
      }
    }
  }

  /// Dialog to manage (switch / rename / delete) all profiles.
  Future<void> _showProfilesDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('pomodoroProfiles')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _profiles.length,
            itemBuilder: (_, i) {
              final p = _profiles[i];
              final isActive = p.id == _activeId;
              return ListTile(
                leading: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(_profileName(p)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      const Icon(Icons.check, size: 18)
                    else
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: l10n.t('edit'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showProfileDialog(existing: p);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: l10n.t('delete'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteProfile(p);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _switchProfile(p.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('close')),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.t('pomodoroNewProfile')),
            onPressed: () {
              Navigator.pop(ctx);
              _showProfileDialog();
            },
          ),
        ],
      ),
    );
  }

  /// Localized display name; the reserved default profile shows a localized
  /// label instead of its raw id.
  String _profileName(PomodoroProfile p) => p.id == PomodoroService.defaultId
      ? AppLocalizations.of(context)!.t('pomodoroDefault')
      : p.name;

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  (String, Color) _phaseLabelColor(AppLocalizations l10n, ThemeData theme) {
    switch (_phase) {
      case PomodoroProfile.phaseWork:
        return (l10n.t('pomodoroFocus'), theme.colorScheme.error);
      case PomodoroProfile.phaseLong:
        return (l10n.t('pomodoroLongBreak'), theme.colorScheme.primary);
      default:
        return (l10n.t('pomodoroShortBreak'), Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = PomodoroService.instance.stats();
    final (label, color) = _phaseLabelColor(l10n, theme);
    final progress = _total > 0 ? 1 - (_remaining / _total) : 0.0;

    final timer = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_profileName(_active), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: color,
                  ),
                ),
                Text(
                  _format(_remaining),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _running
                        ? l10n.t('pomodoroPause')
                        : l10n.t('pomodoroStart'),
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
            const SizedBox(height: 8),
            Text(
              l10n.tArgs('pomodoroSessions', ['$_completed']),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('pomodoro')),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: l10n.t('pomodoroProfiles'),
            onPressed: _showProfilesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.t('pomodoroNewProfile'),
            onPressed: () => _showProfileDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.t('pomodoroSettings'),
            onPressed: _editSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStats(l10n, stats),
          const SizedBox(height: 16),
          timer,
          const SizedBox(height: 16),
          Text(l10n.t('pomodoroProfiles'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in _profiles) _buildProfileCard(p, l10n),
        ],
      ),
    );
  }

  /// Top-of-screen statistics: focus + break time for today / week / month /
  /// year, powered by the completed-phase history.
  Widget _buildStats(AppLocalizations l10n, Map<String, PomodoroStats> stats) {
    final theme = Theme.of(context);
    final rows = [
      ('today', l10n.t('pomodoroToday')),
      ('week', l10n.t('pomodoroWeek')),
      ('month', l10n.t('pomodoroMonth')),
      ('year', l10n.t('pomodoroYear')),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('pomodoroStats'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (key, label) in rows) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${l10n.t('pomodoroFocus')} ${_fmtDur(stats[key]!.focusSeconds)}'
                      '  ·  '
                      '${l10n.t('pomodoroBreak')} ${_fmtDur(stats[key]!.breakSeconds)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  /// A preset card: name + durations, a blurred background image along the
  /// bottom, a start button (bottom-left) and an edit pencil (bottom-right).
  Widget _buildProfileCard(PomodoroProfile p, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final bg = p.backgroundPath != null && File(p.backgroundPath!).existsSync()
        ? File(p.backgroundPath!)
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          if (bg != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Image.file(bg, fit: BoxFit.cover),
              ),
            ),
          if (bg != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      theme.colorScheme.surface.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _profileName(p),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (p.id == _activeId)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.workMinutes} / ${p.shortBreakMinutes} / ${p.longBreakMinutes}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _startProfile(p.id),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.t('pomodoroStart')),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: l10n.t('edit'),
                      onPressed: () => _showProfileDialog(existing: p),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Switch to [id] (if needed) and start its timer immediately.
  Future<void> _startProfile(String id) async {
    if (_running) _pause();
    if (_activeId != id) await _switchProfile(id);
    _start();
  }

  /// Format a duration in seconds as "Xh Ym" / "Ym".
  String _fmtDur(int seconds) {
    final totalMin = (seconds / 60).floor();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '${h}h${m}m' : '${m}m';
  }
}
