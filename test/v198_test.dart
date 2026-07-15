import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/settings.dart';
import 'package:free_note/models/plugin.dart';
import 'package:free_note/plugins/user_plugin.dart';
import 'package:free_note/plugins/ai_context_plugin.dart';
import 'package:free_note/plugins/builtin_plugins.dart';
import 'package:free_note/plugins/plugin_manager.dart';
import 'package:free_note/services/storage_service.dart';

void main() {
  group('v1.9.8 — user plugins & .fne backup', () {
    test('AppSettings.userPlugins round-trips through JSON', () {
      final plugin = PluginInfo(
        id: 'user.demo_123',
        name: 'Demo',
        description: 'A demo plugin',
        version: '1.0.0',
        author: 'User',
        type: PluginType.utility,
        hasSettings: false,
      );
      final settings = AppSettings(userPlugins: [plugin]);
      final json = settings.toJson();
      expect(json['userPlugins'], isA<List>());
      expect((json['userPlugins'] as List).length, 1);

      final restored = AppSettings.fromJson(json);
      expect(restored.userPlugins.length, 1);
      expect(restored.userPlugins.first.id, 'user.demo_123');
      expect(restored.userPlugins.first.type, PluginType.utility);
    });

    test('UserPlugin reconstructs from PluginInfo and id is detected', () {
      final info = PluginInfo(
        id: 'user.my_999',
        name: 'My',
        description: 'desc',
        version: '2.0.0',
        author: 'User',
        type: PluginType.theme,
      );
      final plugin = UserPlugin.fromInfo(info);
      expect(plugin.name, 'My');
      expect(plugin.type, PluginType.theme);
      expect(plugin.version, '2.0.0');
      expect(UserPlugin.isUserPluginId(plugin.id), isTrue);
      expect(UserPlugin.isUserPluginId('builtin.wordcount'), isFalse);
    });

    test('.fne archive export/import round-trips folder contents', () async {
      final src = Directory.systemTemp.createTempSync('fne_src_');
      final dst = Directory.systemTemp.createTempSync('fne_dst_');
      try {
        final md = File('${src.path}/note.md')..writeAsStringSync('# Hi\n');
        Directory('${src.path}/.config').createSync(recursive: true);
        File('${src.path}/.config/1.json').writeAsStringSync('{"id":"1"}');

        StorageService.instance.currentFolder = src.path;
        final bytes = await StorageService.instance.buildFolderFneBytes();
        expect(bytes, isNotNull);
        expect(bytes!.length, greaterThan(0));
        expect(StorageService.instance.currentFolderName, isNotNull);

        StorageService.instance.currentFolder = dst.path;
        final count = await StorageService.instance.importFolderFromFneBytes(
          bytes,
        );
        // note.md + .config/1.json
        expect(count, 2);
        final restored = File('${dst.path}/note.md');
        expect(restored.existsSync(), isTrue);
        expect(restored.readAsStringSync(), '# Hi\n');
        expect(File('${dst.path}/.config/1.json').existsSync(), isTrue);
        md.deleteSync();
      } finally {
        src.deleteSync(recursive: true);
        dst.deleteSync(recursive: true);
      }
    });

    test('default languageCode follows system (empty = system)', () {
      final s = AppSettings();
      expect(s.languageCode, '');
      final json = s.toJson();
      final restored = AppSettings.fromJson(json);
      expect(restored.languageCode, '');
    });
  });

  group('v1.9.8b — AI plugin & chat resume', () {
    test('AiContextPlugin parses a saved chat back into messages', () {
      final chat = [
        '! Free note ai chat',
        '',
        '# Chat 2026-07-15',
        '',
        '## User',
        'Hello there',
        '',
        '## Assistant',
        'Hi! How can I help?',
        '',
      ].join('\n');
      final plugin = AiContextPlugin();
      expect(plugin.isAiChat(chat), isTrue);
      final msgs = plugin.parseMessages(chat);
      expect(msgs.length, 2);
      expect(msgs[0].role, 'user');
      expect(msgs[0].text, 'Hello there');
      expect(msgs[1].role, 'assistant');
      expect(msgs[1].text, 'Hi! How can I help?');
    });

    test('AI features are gated on the builtin.aicontext plugin', () {
      final manager = PluginManager();
      manager.register(WordCountPlugin());
      manager.register(AiContextPlugin());
      expect(manager.isPluginEnabled('builtin.aicontext'), isTrue);
      // Disabling the AI plugin flips the gate used by the editor.
      manager.disable('builtin.aicontext');
      expect(manager.isPluginEnabled('builtin.aicontext'), isFalse);
    });
  });
}
