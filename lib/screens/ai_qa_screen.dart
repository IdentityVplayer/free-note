import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import '../l10n/app_localizations.dart';
import 'ai_assistant_screen.dart';

/// Split "AI 问答" view: the note occupies the top half (editable, so it has a
/// real caret), the AI chat the bottom half. Long-press a word in the note to
/// select it, then drag the floating chip up onto the note to append the
/// selection right after the caret.
class AiQaScreen extends StatefulWidget {
  final String noteId;

  const AiQaScreen({super.key, required this.noteId});

  @override
  State<AiQaScreen> createState() => _AiQaScreenState();
}

class _AiQaScreenState extends State<AiQaScreen> {
  late AppProvider _provider;
  late Note _note;
  late TextEditingController _noteController;

  /// Currently selected text in the note (null when the selection is
  /// collapsed). Kept fresh via the controller's change listener so the drag
  /// chip always carries the latest selection.
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _note = _provider.getNote(widget.noteId) ?? _provider.createNote();
    _noteController = TextEditingController(text: _note.content);
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _saveNote();
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    final sel = _noteController.selection;
    final selText = sel.isValid && !sel.isCollapsed
        ? sel.textInside(_noteController.text)
        : null;
    if (selText != _selectedText) {
      setState(() => _selectedText = selText);
    }
  }

  void _saveNote() {
    final updated = _note.copyWith(
      content: _noteController.text,
      updatedAt: DateTime.now(),
    );
    if (updated.content != _note.content) {
      _provider.updateNote(updated);
      _note = updated;
    }
  }

  /// Insert [text] at the caret (after the current selection end).
  void _appendToCursor(String text) {
    if (text.isEmpty) return;
    final sel = _noteController.selection;
    final pos = sel.isValid ? sel.end : _noteController.text.length;
    final newText = _noteController.text.replaceRange(pos, pos, text);
    _noteController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + text.length),
    );
    setState(() => _selectedText = null);
    _saveNote();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('aiQa'))),
      body: Column(
        children: [
          // Top half: the note (editable → real caret for "append after cursor").
          Expanded(
            flex: 1,
            child: DragTarget<String>(
              onAcceptWithDetails: (details) => _appendToCursor(details.data),
              builder: (ctx, candidateData, rejectedData) {
                final active = candidateData.isNotEmpty;
                return Container(
                  color: active
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.25,
                        )
                      : null,
                  child: Stack(
                    children: [
                      TextField(
                        controller: _noteController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            l10n.t('aiQaDragHint'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: theme.dividerColor),
          // Bottom half: the AI chat.
          Expanded(
            flex: 1,
            child: AIAssistantScreen(
              embedded: true,
              initialContextContent: _note.content,
              noteId: widget.noteId,
            ),
          ),
        ],
      ),
      // Drag the selected text up onto the note to append it.
      floatingActionButton: LongPressDraggable<String>(
        data: _selectedText ?? '',
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _selectedText ?? l10n.t('aiQa'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        child: FloatingActionButton.small(
          onPressed: () {},
          tooltip: l10n.t('aiQaDragHint'),
          child: const Icon(Icons.drag_indicator),
        ),
      ),
    );
  }
}
