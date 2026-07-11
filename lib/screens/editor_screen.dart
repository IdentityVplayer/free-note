import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../plugins/ai_context_plugin.dart';
import 'subfolder_picker_screen.dart';
import 'ai_assistant_screen.dart';

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

  /// The note's current subfolder (relative to the base notes folder), or
  /// null when it sits at the top level.
  String? get _currentSubfolder {
    final rp = _note.relativePath;
    if (rp == null || rp.isEmpty) return null;
    final dir = p.dirname(rp);
    return dir == '.' ? null : dir;
  }

  /// Choose a subfolder inside the selected notes folder (without changing
  /// the base folder in Settings). The note's relativePath is updated so the
  /// file is written into that subfolder on next save.
  Future<void> _pickSubfolder() async {
    final base = StorageService.instance.currentFolder;
    if (base == null) return;
    final rel = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SubfolderPickerScreen(
          baseFolder: base,
          initialRelative: _note.relativePath,
        ),
      ),
    );
    if (rel != null) {
      final newRel = rel.isEmpty ? _note.fileName : p.join(rel, _note.fileName);
      setState(() {
        _note = _note.copyWith(relativePath: newRel);
        _hasChanges = true;
      });
    }
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
      final result = await provider.aiService.assistWriting(
        _contentController.text,
        mode: mode,
      );
      if (mode == WritingMode.continue_) {
        _contentController.text += '\n\n$result';
      } else {
        _contentController.text = result;
      }
      setState(() => _hasChanges = true);
    } on AIException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
        SnackBar(
          content: Text('${l10n.t('exportSuccess')}: ${p.basename(path)}'),
        ),
      );
    }
  }

  /// Open this AI chat file's conversation in the AI assistant, pre-filled as
  /// context (via the ai-context plugin).
  void _openAiContext() {
    final aicontext = context
        .read<AppProvider>()
        .pluginManager
        .plugins['builtin.aicontext'];
    if (aicontext is AiContextPlugin) {
      final messages = aicontext.parseMessages(_note.content);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIAssistantScreen(initialMessages: messages),
        ),
      );
    }
  }

  /// A compact, tappable row showing where this note is saved and letting the
  /// user pick a subfolder inside the selected notes folder.
  Widget _buildSaveLocation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final base = StorageService.instance.currentFolder;
    final theme = Theme.of(context);

    if (base == null) {
      return InkWell(
        onTap: _pickSubfolder,
        child: _saveRow(
          theme,
          Icons.folder_outlined,
          '${l10n.t('saveLocation')}: ${l10n.t('defaultSaveHint')}',
          null,
        ),
      );
    }

    final sub = _currentSubfolder;
    final subLabel = sub ?? l10n.t('topLevel');
    return InkWell(
      onTap: _pickSubfolder,
      child: _saveRow(
        theme,
        Icons.folder_outlined,
        '${l10n.t('saveLocation')}: $base',
        '${l10n.t('subfolder')}: $subLabel',
      ),
    );
  }

  Widget _saveRow(
    ThemeData theme,
    IconData icon,
    String line1,
    String? line2,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line1,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (line2 != null) ...[
                const SizedBox(height: 2),
                Text(
                  line2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 18),
      ],
    ),
  );

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

    // Is this note a Free Note AI chat? (ai-context plugin recognizes it.)
    final aicontext = provider.pluginManager.plugins['builtin.aicontext'];
    final isAiChat =
        aicontext is AiContextPlugin && aicontext.isAiChat(_note.content);

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
          if (isAiChat)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: l10n.t('fillContext'),
              onPressed: _openAiContext,
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
          // Save location + subfolder picker
          _buildSaveLocation(context),
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
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Html(
                      data: md.markdownToHtml(
                        _contentController.text,
                        extensionSet: md.ExtensionSet.gitHubFlavored,
                      ),
                      onLinkTap: (url, _, _) {
                        if (url != null) _launchUrl(url);
                      },
                      style: {
                        'body': Style(fontSize: FontSize(16.0)),
                        'a': Style(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      },
                    ),
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

  /// Open a URL in the default browser.
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
