import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';

/// AI Assistant screen — standalone chat-like interface for Q&A.
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  String? _currentModel;

  @override
  void initState() {
    super.initState();
    final models = context.read<AppProvider>().settings.allModels;
    _currentModel = models.isNotEmpty ? models.first : null;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    final provider = context.read<AppProvider>();
    // Only override the model when one is actually selected, otherwise fall
    // back to the service's configured default.
    final modelOverride = (_currentModel != null && _currentModel!.isNotEmpty)
        ? _currentModel
        : null;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: question));
      _loading = true;
      _questionController.clear();
    });
    _scrollToBottom();

    final answer = await (() async {
      try {
        return await provider.aiService.ask(question, model: modelOverride);
      } on AIException catch (e) {
        return '⚠️ ${e.message}';
      }
    })();

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: answer));
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Intercept the back gesture. If there is a conversation, ask whether to
  /// save it as a standalone `.md` note before leaving.
  Future<void> _handleBack() async {
    final l10n = AppLocalizations.of(context)!;
    if (_messages.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('saveChatTitle')),
        content: Text(l10n.t('saveChatHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(l10n.t('saveChatDiscard')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l10n.t('saveChat')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _saveChat();
      if (mounted) Navigator.pop(context);
    } else if (choice == 'discard') {
      if (mounted) Navigator.pop(context);
    }
    // 'cancel' or dismissed → stay on the screen.
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _timestamp(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}-${_pad(d.hour)}-${_pad(d.minute)}-${_pad(d.second)}';

  String _buildChatMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Chat ${_timestamp(DateTime.now())}');
    buf.writeln();
    for (final m in _messages) {
      buf.writeln(m.role == 'user' ? '## User' : '## Assistant');
      buf.writeln();
      buf.writeln(m.text);
      buf.writeln();
    }
    return buf.toString();
  }

  /// Persist the conversation as `Chat-YYYY-MM-DD-HH-MM-SS.md` in the notes
  /// folder, then refresh the note list so it appears immediately.
  Future<void> _saveChat() async {
    final l10n = AppLocalizations.of(context)!;
    final fileName = 'Chat-${_timestamp(DateTime.now())}.md';
    final provider = context.read<AppProvider>();
    final path = await StorageService.instance.writeMarkdownFile(
      fileName,
      _buildChatMarkdown(),
    );
    await provider.reloadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.t('chatSaved')}: $path')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final models = provider.settings.allModels;
    final selectedModel =
        (_currentModel != null && models.contains(_currentModel))
        ? _currentModel!
        : (models.isNotEmpty ? models.first : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('aiAssistant')),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.model_training, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedModel,
                      hint: Text(l10n.t('model')),
                      items: models
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _currentModel = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('askAI'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('aiNotConfigured'),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final msg = _messages[index];
                        return Align(
                          alignment: msg.role == 'user'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: msg.role == 'user'
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(msg.text),
                          ),
                        );
                      },
                    ),
            ),
            // Input bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          hintText: l10n.t('askAI'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _ask(),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: _loading ? null : _ask,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;

  _ChatMessage({required this.role, required this.text});
}
