import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../models/chat_message.dart';
import '../models/note.dart';
import '../plugins/ai_context_plugin.dart';
import '../l10n/app_localizations.dart';
import '../markdown/math_markdown.dart';
import 'context_file_picker_screen.dart';

/// AI Assistant screen — standalone chat-like interface for Q&A.
///
/// A markdown file can be loaded as **context** (via the ai-context plugin):
/// its content is prepended to the user's input when they send a message, so
/// the model answers with that file in mind.
class AIAssistantScreen extends StatefulWidget {
  /// Optional markdown file to pre-load as context (e.g. when the user taps
  /// the upload icon on a note in the editor).
  final String? initialContextContent;
  final String? initialContextName;

  /// Pre-filled conversation, used when resuming an existing AI chat note.
  final List<ChatMessage>? initialMessages;

  /// When set, this screen is editing an existing AI chat note: closing it
  /// auto-saves the conversation back into that note (no "save?" prompt).
  final String? noteId;

  const AIAssistantScreen({
    super.key,
    this.initialContextContent,
    this.initialContextName,
    this.initialMessages,
    this.noteId,
  });

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String? _currentModel;

  /// Loaded context file content (prepended to the user's input on send).
  String? _contextContent;
  String? _contextName;

  @override
  void initState() {
    super.initState();
    final models = context.read<AppProvider>().settings.allModels;
    _currentModel = models.isNotEmpty ? models.first : null;
    if (widget.initialMessages != null && widget.initialMessages!.isNotEmpty) {
      // Resuming an existing AI chat note — show the conversation directly.
      _messages.addAll(widget.initialMessages!);
    } else if (widget.initialContextContent != null &&
        widget.initialContextContent!.trim().isNotEmpty) {
      _contextContent = widget.initialContextContent;
      _contextName = widget.initialContextName;
    }
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
    final modelOverride = (_currentModel != null && _currentModel!.isNotEmpty)
        ? _currentModel
        : null;

    // Prepend the loaded context file's content before the user's question.
    final prompt = (_contextContent != null && _contextContent!.isNotEmpty)
        ? '${_contextContent!}\n\n$question'
        : question;

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: question));
      _loading = true;
      _questionController.clear();
    });
    _scrollToBottom();

    final answer = await (() async {
      try {
        return await provider.aiService.ask(prompt, model: modelOverride);
      } on AIException catch (e) {
        return '⚠️ ${e.message}';
      }
    })();

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', text: answer));
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

  /// Open the folder-classified markdown picker and load the chosen file as
  /// context.
  Future<void> _addContext() async {
    final note = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => const ContextFilePickerScreen()),
    );
    if (note != null && mounted) {
      setState(() {
        _contextContent = note.content;
        _contextName = note.relativePath ?? note.title;
      });
    }
  }

  void _clearContext() {
    setState(() {
      _contextContent = null;
      _contextName = null;
    });
  }

  /// Intercept the back gesture. If there is a conversation, ask whether to
  /// save it as a standalone `.md` note before leaving.
  Future<void> _handleBack() async {
    final l10n = AppLocalizations.of(context)!;
    // Editing an existing AI chat note → auto-save the conversation back into
    // the note (no "save?" prompt). The conversation is always persisted.
    if (widget.noteId != null) {
      final provider = context.read<AppProvider>();
      final note = provider.getNote(widget.noteId!);
      final markdown = _buildChatMarkdown();
      if (note != null && mounted) {
        provider.updateNote(
          note.copyWith(content: markdown, updatedAt: DateTime.now()),
        );
      }
      if (mounted) Navigator.pop(context, markdown);
      return;
    }
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
    buf.writeln(aiChatMagic);
    buf.writeln();
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

  /// Open a URL in the default browser (used by markdown links).
  Future<void> _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildMessage(ChatMessage msg, ThemeData theme) {
    return Align(
      alignment: msg.role == 'user'
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: msg.role == 'user'
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: safeMarkdown(
          data: msg.text,
          onTapLink: (text, href, title) => _launchUrl(href),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
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
          actions: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: l10n.t('addToContext'),
              onPressed: _addContext,
            ),
            if (_contextContent != null)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: l10n.t('clearContext'),
                onPressed: _clearContext,
              ),
          ],
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
            // Context banner
            if (_contextContent != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.secondaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.source, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.tArgs('contextActive', [
                          _contextName ?? l10n.t('context'),
                        ]),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _clearContext,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                        return _buildMessage(msg, theme);
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
