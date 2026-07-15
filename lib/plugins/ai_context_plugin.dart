import '../models/chat_message.dart';
import '../models/plugin.dart';
import 'plugin_base.dart';

/// Magic first line marking a markdown file as a Free Note AI chat export.
/// Every chat saved by the AI assistant begins with this line.
const String aiChatMagic = '! Free note ai chat';

/// Built-in AI plugin — powers the in-app AI assistant (writing assist + chat).
///
/// It is the single toggle that enables every AI feature in the editor:
/// the AI writing menu and the in-file chat dialog. It also recognizes AI
/// chat files (those whose content starts with [aiChatMagic]) and turns them
/// into resumable conversations for the assistant.
class AiContextPlugin extends FreeNotePlugin {
  @override
  String get id => 'builtin.aicontext';

  @override
  String get name => 'AI Assistant';

  @override
  String get description =>
      'Enables in-app AI writing and chat. Recognizes AI chat notes and resumes them as conversations.';

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
