/// A single message in an AI conversation.
///
/// Kept in its own file so both the AI assistant screen and the ai-context
/// plugin can reference it without creating an import cycle.
class ChatMessage {
  /// Role of the author: `'user'` or `'assistant'`.
  final String role;
  final String text;

  ChatMessage({required this.role, required this.text});

  bool get isUser => role == 'user';
}
