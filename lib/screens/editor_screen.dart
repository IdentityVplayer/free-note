import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

/// Editor screen — Markdown editing with live preview and AI tools.
class EditorScreen extends StatefulWidget {
  final String? noteId;

  const EditorScreen({super.key, this.noteId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Note _note;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  bool _isPreview = false;
  bool _aiLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    if (widget.noteId != null) {
      _note = provider.getNote(widget.noteId!) ?? provider.createNote();
    } else {
      _note = provider.createNote();
    }
    _titleController = TextEditingController(text: _note.title);
    _contentController = TextEditingController(text: _note.content);
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _saveIfChanged();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _saveIfChanged() {
    if (!_hasChanges) return;
    final provider = context.read<AppProvider>();
    final updated = _note.copyWith(
      title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    provider.updateNote(updated);
  }

  void _insertText(String before, [String? after]) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final selectedText = selection.textInside(text);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$before$selectedText${after ?? before}',
    );
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + before.length + selectedText.length,
      ),
    );
    setState(() => _hasChanges = true);
  }

  Future<void> _askAI(WritingMode mode) async {
    final provider = context.read<AppProvider>();
    final l10n = AppLocalizations.of(context)!;

    setState(() => _aiLoading = true);
    try {
      String result;
      if (mode == WritingMode.continue_ || mode == WritingMode.expand) {
        result = await provider.aiService.assistWriting(
          _contentController.text,
          mode: mode,
        );
        if (mode == WritingMode.continue_) {
          _contentController.text += '\n\n$result';
        } else {
          _contentController.text = result;
        }
      } else {
        result = await provider.aiService.assistWriting(
          _contentController.text,
          mode: mode,
        );
        _contentController.text = result;
      }
      setState(() => _hasChanges = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('aiNotConfigured'))));
      }
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _showAIMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.t('aiWriting'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(l.t('continueWriting')),
                onTap: () {
                  Navigator.pop(ctx);
                  _askAI(WritingMode.continue_);
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: Text(l.t('improve')),
                onTap: () {
                  Navigator.pop(ctx);
                  _askAI(WritingMode.improve);
                },
              ),
              ListTile(
                leading: const Icon(Icons.summarize),
                title: Text(l.t('summarize')),
                onTap: () {
                  Navigator.pop(ctx);
                  _askAI(WritingMode.summarize);
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l.t('translate')),
                onTap: () {
                  Navigator.pop(ctx);
                  _askAI(WritingMode.translate);
                },
              ),
              ListTile(
                leading: const Icon(Icons.expand),
                title: Text(l.t('expand')),
                onTap: () {
                  Navigator.pop(ctx);
                  _askAI(WritingMode.expand);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    _saveIfChanged();
    final path = await StorageService.instance.exportNoteAsMarkdown(_note);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.t('exportSuccess')}: $path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();

    // Get word count from plugin.
    final wordCountPlugin =
        provider.pluginManager.plugins['builtin.wordcount']!;
    final counts =
        (wordCountPlugin as dynamic).count(_contentController.text)
            as Map<String, int>;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titleController.text.isEmpty
              ? l10n.t('newNote')
              : l10n.t('editNote'),
        ),
        actions: [
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.preview),
            tooltip: _isPreview ? l10n.t('edit') : l10n.t('preview'),
            onPressed: () => setState(() => _isPreview = !_isPreview),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.t('aiWriting'),
            onPressed: _aiLoading ? null : _showAIMenu,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l10n.t('export'),
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          // Title field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: l10n.t('title'),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() => _hasChanges = true),
            ),
          ),
          // Tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 4,
              children: [
                ..._note.tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        _note.tags.remove(tag);
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: l10n.t('addTag'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _note.tags.add(value);
                          _tagController.clear();
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Markdown toolbar (edit mode only)
          if (!_isPreview) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _toolbarBtn(
                    Icons.title,
                    () => _insertText('## '),
                    hint: l10n.t('insertHeading'),
                  ),
                  _toolbarBtn(
                    Icons.format_bold,
                    () => _insertText('**'),
                    hint: l10n.t('insertBold'),
                  ),
                  _toolbarBtn(
                    Icons.format_italic,
                    () => _insertText('*'),
                    hint: l10n.t('insertItalic'),
                  ),
                  _toolbarBtn(
                    Icons.code,
                    () => _insertText('`'),
                    hint: l10n.t('insertCode'),
                  ),
                  _toolbarBtn(
                    Icons.link,
                    () => _insertText('[', ']()'),
                    hint: l10n.t('insertLink'),
                  ),
                  _toolbarBtn(
                    Icons.list,
                    () => _insertText('- '),
                    hint: l10n.t('insertList'),
                  ),
                  _toolbarBtn(
                    Icons.format_quote,
                    () => _insertText('> '),
                    hint: l10n.t('insertQuote'),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
          // Editor / Preview
          Expanded(
            child: _isPreview
                ? Markdown(
                    data: _contentController.text,
                    padding: const EdgeInsets.all(16),
                  )
                : Stack(
                    children: [
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        onChanged: (_) => setState(() => _hasChanges = true),
                      ),
                      if (_aiLoading)
                        Container(
                          color: Colors.black38,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.t('aiThinking'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.t('words')}: ${counts['words']}  '
                  '${l10n.t('characters')}: ${counts['chars']}  '
                  '${l10n.t('lines')}: ${counts['lines']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${_note.updatedAt.day}/${_note.updatedAt.month}/${_note.updatedAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(
    IconData icon,
    VoidCallback onTap, {
    required String hint,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: hint,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
