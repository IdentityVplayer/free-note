import '../models/chat_message.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

/// Magic first line marking a markdown file as a Free Note AI chat export.
/// Every chat saved by the AI assistant begins with this line.
const String aiChatMagic = '! Free note ai chat';

/// Built-in AI-context plugin — recognizes AI chat files produced by Free
/// Note and turns them into resumable context for the AI assistant.
///
/// When the editor opens a note whose content starts with [aiChatMagic], it
/// shows an upload icon; tapping it calls [parseMessages] and opens the AI
/// assistant pre-filled with the conversation.
class AiContextPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.aicontext';

  @override
  String get name => 'AI Context';

  @override
  String get description =>
      'Recognizes Free Note AI chat files; one tap fills the conversation into the AI assistant.';

  @override
  String get version => '1.0.0';

  @override
  String get author => 'Borderless Notes';

  @override
  PluginType get type => PluginType.importer;

  /// True when [content] is a Free Note AI chat export.
  bool isAiChat(String content) => content.startsWith(aiChatMagic);

  /// Parse the chat body (after the magic line) into ordered messages.
  ///
  /// The expected layout (produced by the AI assistant's save routine) is:
  ///   ! Free note ai chat
  ///   # Chat ...
  ///   ## User
  ///   message text
  ///   ## Assistant
  ///   message text
  List<ChatMessage> parseMessages(String content) {
    final lines = content.split('\n');
    final magicIdx = lines.indexWhere((l) => l.trim() == aiChatMagic);
    final body = magicIdx >= 0 ? lines.sublist(magicIdx + 1) : lines;

    final messages = <ChatMessage>[];
    final roleRe = RegExp(r'^##\s+(user|assistant)\s*$', caseSensitive: false);
    String? currentRole;
    final buf = StringBuffer();

    void flush() {
      if (currentRole != null && buf.toString().trim().isNotEmpty) {
        messages.add(
          ChatMessage(role: currentRole, text: buf.toString().trim()),
        );
      }
      buf.clear();
    }

    for (final line in body) {
      final m = roleRe.firstMatch(line.trim());
      if (m != null) {
        flush();
        currentRole = m.group(1)!.toLowerCase();
      } else {
        buf.writeln(line);
      }
    }
    flush();
    return messages;
  }
}
