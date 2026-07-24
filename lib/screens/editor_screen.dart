import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../markdown/math_markdown.dart';
import '../utils/text_edit.dart';
import 'subfolder_picker_screen.dart';
import 'ai_assistant_screen.dart';
import 'ai_qa_screen.dart';
import 'math_insert_screen.dart';
import '../plugins/ai_context_plugin.dart';
import '../plugins/plugin_host.dart';

/// Editor screen — Markdown editing with live preview and AI tools.
class EditorScreen extends StatefulWidget {
  final String? noteId;

  const EditorScreen({super.key, this.noteId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late Note _note;
  late AppProvider _provider;
  late TextEditingController _titleController;
  late TextEditingController _tagController;
  bool _hasChanges = false;

  /// The note body, kept as the single source of truth. The hybrid editor
  /// renders it line-by-line; only [ _activeLine ] is shown raw/editable.
  String _content = '';

  /// Index of the line currently being edited (raw TextField). When null the
  /// whole document is rendered as preview.
  int? _activeLine;

  /// Controller + focus for the single active line. Identity is stable so
  /// focus/caret survive ListView rebuilds while typing.
  final TextEditingController _lineController = TextEditingController();
  final FocusNode _lineFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    // Register the insert hook so user "editor" plugins can inject their
    // snippet at the caret via PluginHost. Cleared in dispose().
    PluginHost.insertHandler = _insertAtCursor;
    if (widget.noteId != null) {
      _note = _provider.getNote(widget.noteId!) ?? _provider.createNote();
    } else {
      _note = _provider.createNote();
    }
    _titleController = TextEditingController(text: _note.title);
    _content = _note.content;
    _tagController = TextEditingController();
    _lineFocus.addListener(_onLineFocusLost);
    WidgetsBinding.instance.addObserver(this);

    // AI-generated note: auto-open the chat dialog with the conversation as
    // context (and auto-save on close). Requires the AI plugin to be enabled.
    if (_note.content.startsWith(aiChatMagic) &&
        _provider.pluginManager.isPluginEnabled('builtin.aicontext')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAiNoteDialog();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveIfEnabled();
    // Detach the insert hook so no stale closure outlives this editor.
    PluginHost.insertHandler = null;
    _titleController.dispose();
    _lineController.dispose();
    _lineFocus.dispose();
    _tagController.dispose();
    super.dispose();
  }

  /// When the active line's focus leaves (e.g. the user taps the title or a
  /// toolbar control), drop back to all-preview. Switching between lines does
  /// NOT trigger this because both fields share the same focus node.
  void _onLineFocusLost() {
    if (!_lineFocus.hasFocus && _activeLine != null) {
      setState(() => _activeLine = null);
    }
  }

  /// Save the current note when the Auto Save plugin is enabled and there are
  /// unsaved changes. Triggered on back navigation (PopScope) and when the app
  /// goes to the background (lifecycle observer). Idempotent — a second call
  /// with no further edits is a no-op.
  void _autoSaveIfEnabled() {
    final autoSaveEnabled = _provider.pluginManager.isPluginEnabled(
      'builtin.autosave',
    );
    final contentChanged =
        _note.content != _content || _note.title != _titleController.text;
    if (!autoSaveEnabled) return;
    if (!_hasChanges && !contentChanged) return;
    final updated = _note.copyWith(
      title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
      content: _content,
      updatedAt: DateTime.now(),
    );
    _provider.updateNote(updated);
    _note = updated;
    _hasChanges = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App backgrounded / closed → auto-save the current note.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autoSaveIfEnabled();
    }
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
    final afterStr = after ?? before;
    if (_activeLine != null) {
      final sel = _lineController.selection;
      final selectedText = sel.textInside(_lineController.text);
      final newText = _lineController.text.replaceRange(
        sel.start,
        sel.end,
        '$before$selectedText$afterStr',
      );
      _lineController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + before.length + selectedText.length,
        ),
      );
      _content = applyLineEdit(_content, _activeLine!, newText);
    } else {
      _content = '$_content$before$afterStr';
    }
    setState(() => _hasChanges = true);
  }

  /// Open the split "AI 问答" view: note on top, AI chat on the bottom.
  void _openAiQa() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiQaScreen(noteId: _note.id)),
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    _autoSaveIfEnabled();
    final path = await StorageService.instance.exportNoteAsMarkdown(_note);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.t('exportSuccess')}: ${p.basename(path)}'),
        ),
      );
    }
  }

  /// Open the AI assistant as an in-file dialog, with this note's content as
  /// the initial context. Powered by the AI plugin (gated in the app bar).
  void _openAiDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      pageBuilder: (ctx, _, _) => AIAssistantScreen(
        initialContextContent: _note.content,
        initialContextName: _note.relativePath ?? _note.title,
      ),
    );
  }

  /// Open an existing AI chat note: resume its conversation and open the chat
  /// dialog over the editor. Closing auto-saves the conversation back into the
  /// note (see AIAssistantScreen._handleBack).
  void _openAiNoteDialog() {
    final l10n = AppLocalizations.of(context)!;
    final messages = AiContextPlugin().parseMessages(_note.content);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      pageBuilder: (ctx, _, _) => AIAssistantScreen(
        initialMessages: messages,
        noteId: _note.id,
        initialContextName: _note.relativePath ?? _note.title,
      ),
    ).then((result) {
      if (result is String && result.isNotEmpty && mounted) {
        _note = _note.copyWith(content: result, updatedAt: DateTime.now());
        _content = result;
        _activeLine = null;
        _hasChanges = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('aiNoteAutoSaved'))));
      }
    });
  }

  /// Open the dedicated LaTeX formula page; insert the resulting (wrapped)
  /// formula at the cursor when the user taps "Insert".
  Future<void> _openMathPage() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const MathInsertScreen()),
    );
    if (result != null && result.isNotEmpty) {
      _insertAtCursor(result);
    }
  }

  /// Insert [text] at the current caret (active line, else end of document),
  /// moving the caret to the end of the inserted text.
  void _insertAtCursor(String text) {
    if (_activeLine != null) {
      final sel = _lineController.selection;
      final newText = _lineController.text.replaceRange(
        sel.start,
        sel.end,
        text,
      );
      _lineController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + text.length),
      );
      _content = applyLineEdit(_content, _activeLine!, newText);
    } else {
      _content = '$_content$text';
    }
    setState(() => _hasChanges = true);
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

  /// The body: a scrollable list of lines. Every line is rendered as Markdown
  /// preview except [ _activeLine ], which is shown as a raw, editable field.
  Widget _buildHybridBody() {
    final lines = splitLines(_content);
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lines.length,
          itemBuilder: (ctx, i) {
            if (_activeLine == i) return _buildActiveLineField(i);
            return _buildPreviewLine(i, lines[i]);
          },
        ),
      ],
    );
  }

  /// The currently-edited line: a raw TextField with a highlighted left edge.
  Widget _buildActiveLineField(int i) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: TextField(
        controller: _lineController,
        focusNode: _lineFocus,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        style: theme.textTheme.bodyMedium,
        onChanged: (v) {
          if (v.contains('\n')) {
            // Enter inserted a newline — split this line there.
            _splitActiveLineAtText(v);
            return;
          }
          _content = applyLineEdit(_content, i, v);
          _hasChanges = true;
        },
      ),
    );
  }

  /// A preview line; tapping it makes that line the active (raw) one.
  ///
  /// The markdown is rendered non-selectable so the tap reaches this
  /// [GestureDetector] (a selectable [MarkdownBody] swallows taps for text
  /// selection, which previously blocked tap-to-edit). Links still open via
  /// [safeMarkdown]'s [onTapLink].
  Widget _buildPreviewLine(int i, String line) {
    final child = line.isEmpty
        ? const SizedBox(height: 22)
        : safeMarkdown(
            data: line,
            selectable: false,
            onTapLink: (text, href, title) {
              if (href != null) _launchUrl(href);
            },
          );
    return GestureDetector(onTap: () => _setActiveLine(i), child: child);
  }

  /// Activate line [i] for editing, seeding the raw field with its text and
  /// moving the caret to the end. Tapping the already-active line just refocuses.
  void _setActiveLine(int i) {
    if (_activeLine == i) {
      _lineFocus.requestFocus();
      return;
    }
    setState(() {
      _activeLine = i;
      final lines = splitLines(_content);
      _lineController.text = lines[i];
      _lineController.selection = TextSelection.collapsed(
        offset: _lineController.text.length,
      );
    });
    _lineFocus.requestFocus();
  }

  /// Split the active line at the inserted newline (entered via keyboard).
  void _splitActiveLineAtText(String v) {
    final i = _activeLine!;
    final local = v.indexOf('\n');
    int global = 0;
    final lines = splitLines(_content);
    for (var k = 0; k < i; k++) {
      global += lines[k].length + 1;
    }
    global += local;
    final (newContent, _) = insertLineBreak(_content, global);
    _content = newContent;
    final newLines = splitLines(_content);
    setState(() {
      _activeLine = i + 1;
      _lineController.text = newLines[i + 1];
      _lineController.selection = const TextSelection.collapsed(offset: 0);
    });
    _lineFocus.requestFocus();
    _hasChanges = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    final wordCountEnabled = provider.pluginManager.isPluginEnabled(
      'builtin.wordcount',
    );
    final exportEnabled = provider.pluginManager.isPluginEnabled(
      'builtin.exporter',
    );
    // AI is a plugin now — every AI entry point is gated on it.
    final aiEnabled = provider.pluginManager.isPluginEnabled(
      'builtin.aicontext',
    );

    // Word count comes from the Word Count plugin — only show when enabled.
    Map<String, int> counts = const {};
    if (wordCountEnabled) {
      final wordCountPlugin =
          provider.pluginManager.plugins['builtin.wordcount']!;
      counts = (wordCountPlugin as dynamic).count(_content) as Map<String, int>;
    }

    return PopScope(
      canPop: true,
      // Save when the user taps back (top-left / system gesture).
      onPopInvokedWithResult: (didPop, result) {
        _autoSaveIfEnabled();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _titleController.text.isEmpty
                ? l10n.t('newNote')
                : l10n.t('editNote'),
          ),
          actions: [
            if (aiEnabled)
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: l10n.t('aiChat'),
                onPressed: _openAiDialog,
              ),
            if (aiEnabled)
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: l10n.t('aiQa'),
                onPressed: _openAiQa,
              ),
            if (exportEnabled)
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
            // Markdown toolbar — always available; formats the active line.
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
                  _toolbarBtn(
                    Icons.functions,
                    () => _openMathPage(),
                    hint: l10n.t('math'),
                  ),
                  // User "editor" plugins render their insert buttons here.
                  ...provider.pluginManager.buildWidgets(context),
                ],
              ),
            ),
            const Divider(),
            // Hybrid editor: every line is preview; the active line is raw.
            Expanded(child: _buildHybridBody()),
            // Status bar (only when the Word Count plugin is enabled)
            if (wordCountEnabled)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
