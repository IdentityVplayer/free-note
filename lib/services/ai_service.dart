import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when an AI request fails (not configured, network, or API error).
/// Carries a user-facing message so the UI can show what actually went wrong
/// instead of silently pretending the key was never set.
class AIException implements Exception {
  final String message;
  const AIException(this.message);
  @override
  String toString() => message;
}

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

  /// Sensible default model per provider so the feature works out of the box
  /// once the user fills in a key.
  static const Map<String, String> defaultModel = {
    'openai': 'gpt-3.5-turbo',
    'deepseek': 'deepseek-chat',
    'moonshot': 'moonshot-v1-8k',
    'google': 'gemini-1.5-flash',
    'ollama': 'llama3',
    'custom': 'gpt-3.5-turbo',
  };

  static String defaultModelFor(String provider) =>
      defaultModel[provider] ?? defaultModel['openai']!;

  /// Whether [model] looks like one of the built-in defaults (vs. a model the
  /// user typed themselves). Used to decide whether to auto-switch the model
  /// when the provider changes.
  static bool isKnownDefaultModel(String model) =>
      defaultModel.values.contains(model);

  /// Ask AI a question and get a response.
  Future<String> ask(String question, {String? context}) async {
    if (!isConfigured) {
      throw const AIException('AI 未配置：请先在「设置 → AI」中填写 API Key。');
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
        messages.add({
          'role': 'user',
          'content': 'Context:\n$context\n\nQuestion: $question',
        });
      } else {
        messages.add({'role': 'user', 'content': question});
      }

      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'] as String;
        }
        throw AIException('AI 返回了空结果。');
      }

      // Surface the real error from the provider instead of masking it.
      final detail = _extractError(response);
      throw AIException('AI 请求失败 (HTTP ${response.statusCode})$detail');
    } on AIException {
      rethrow;
    } catch (e) {
      throw AIException('AI 请求出错：$e');
    }
  }

  /// AI-assisted writing: continue, improve, summarize, translate, or expand.
  Future<String> assistWriting(
    String text, {
    WritingMode mode = WritingMode.continue_,
  }) async {
    if (!isConfigured) {
      throw const AIException('AI 未配置：请先在「设置 → AI」中填写 API Key。');
    }
    final prompt = switch (mode) {
      WritingMode.continue_ =>
        'Continue writing the following text naturally:\n\n$text',
      WritingMode.improve =>
        'Improve the following text for clarity, grammar, and style. Keep the meaning:\n\n$text',
      WritingMode.summarize =>
        'Summarize the following text concisely:\n\n$text',
      WritingMode.translate =>
        'Translate the following text to English if it is in another language, or to Chinese if it is in English:\n\n$text',
      WritingMode.expand =>
        'Expand and elaborate on the following text with more details:\n\n$text',
    };

    return ask(prompt);
  }

  /// Pull a human-readable message out of a non-200 API response body.
  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = body['error']?['message'] ?? body['message'] ?? body['error'];
      if (msg != null && msg.toString().isNotEmpty) {
        return '：$msg';
      }
    } catch (_) {
      // Ignore — fall through to raw body snippet.
    }
    final snippet = response.body.length > 300
        ? '${response.body.substring(0, 300)}…'
        : response.body;
    return snippet.isNotEmpty ? '：$snippet' : '';
  }
}

enum WritingMode { continue_, improve, summarize, translate, expand }
