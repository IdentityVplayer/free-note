import 'plugin_base.dart';
import '../models/plugin.dart';

/// Built-in Auto Save plugin — enabled by default. When enabled, the editor
/// forces a save of the current note's `.md` file on exit, even if the
/// in-memory dirty flag wasn't tripped. The actual save is performed by the
/// editor's dispose path, which checks this plugin's enabled state.
class AutoSavePlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.autosave';

  @override
  String get name => 'Auto Save';

  @override
  String get description =>
      'Automatically saves the .md file when you leave the editor.';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Borderless Notes';

  @override
  PluginType get type => PluginType.utility;

  /// Default-enabled per app requirements.
  @override
  bool get isEnabled => true;
}
