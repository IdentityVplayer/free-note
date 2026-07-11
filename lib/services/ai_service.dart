import 'dart:convert';
import 'package:http/http.dart' as http;

/// AI service for writing assistance and Q&A.
/// Supports OpenAI-compatible API endpoints.
class AIService {
  String? apiKey;
  String model;
  String baseUrl;

  AIService({
    this.apiKey,
    this.model = 'gpt-3.5-turbo',
    this.baseUrl = 'https://api.openai.com/v1',
  });

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Ask AI a question and get a response.
  Future<String> ask(String question, {String? context}) async {
    if (!isConfigured) {
      return _localFallback(question);
    }
    try {
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content':
              'You are a helpful writing assistant integrated into a note-taking app. '
              'Provide clear, concise, and useful responses. Support markdown formatting.',
        },
      ];
      if (context != null && context.isNotEmpty) {
        messages.add({'role': 'user', 'content': 'Context:\n$context\n\nQuestion: $question'});
      } else {
        messages.add({'role': 'user', 'content': question});
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] as String;
        }
      }
      return _localFallback(question);
    } catch (_) {
      return _localFallback(question);
    }
  }

  /// AI-assisted writing: continue or improve text.
  Future<String> assistWriting(String text, {WritingMode mode = WritingMode.continue_}) async {
    if (!isConfigured) {
      return '$text\n\n[AI not configured. Please set API key in settings.]';
    }
    final prompt = switch (mode) {
      WritingMode.continue_ => 'Continue writing the following text naturally:\n\n$text',
      WritingMode.improve => 'Improve the following text for clarity, grammar, and style. Keep the meaning:\n\n$text',
      WritingMode.summarize => 'Summarize the following text concisely:\n\n$text',
      WritingMode.translate => 'Translate the following text to English if it is in another language, or to Chinese if it is in English:\n\n$text',
      WritingMode.expand => 'Expand and elaborate on the following text with more details:\n\n$text',
    };

    return ask(prompt);
  }

  /// Fallback when AI is not configured — provides basic text utilities.
  String _localFallback(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi') || lower.contains('你好')) {
      return 'Hello! I\'m your AI writing assistant. To enable full AI capabilities, please configure your API key in Settings.\n\n你好！我是你的 AI 写作助手。要启用完整的 AI 功能，请在设置中配置 API 密钥。';
    }
    return 'AI is not configured. Please set your API key in Settings.\n\nAI 未配置，请在设置中填写 API 密钥。\n\nYour question was: "$question"';
  }
}

enum WritingMode {
  continue_,
  improve,
  summarize,
  translate,
  expand,
}
