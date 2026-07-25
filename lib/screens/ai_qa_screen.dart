import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import '../l10n/app_localizations.dart';
import 'ai_assistant_screen.dart';

/// Split "AI 问答" view: the note occupies the top half (editable), the AI
/// chat the bottom half.
///
/// v1.16.0 changed the interaction model: instead of long-pressing a word in
/// the note and dragging it, the user now **selects text inside any AI chat
/// message** in the bottom half — an "Insert into note" button appears, and
/// tapping it appends the selection to the end of the note file.
///
/// Closing the screen (`dispose`) auto-saves the note.
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

  /// Currently selected text inside the bottom AI chat (null when the user
  /// has not selected anything). Reported by [AIAssistantScreen.onSelectionChanged].
  String? _aiSelectedText;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _note = _provider.getNote(widget.noteId) ?? _provider.createNote();
    _noteController = TextEditingController(text: _note.content);
  }

  @override
  void dispose() {
    _saveNote();
    _noteController.dispose();
    super.dispose();
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

  /// Append [text] at the end of the note file, separated by a blank line
  /// if the file is non-empty. Saves immediately and clears the selection.
  void _insertAtEnd(String text) {
    if (text.isEmpty) return;
    final cur = _noteController.text;
    final needsBlankLine = cur.isNotEmpty && !cur.endsWith('\n');
    final sep = needsBlankLine ? '\n\n' : (cur.isEmpty ? '' : '\n');
    final newText = '$cur$sep$text';
    _noteController.text = newText;
    setState(() => _aiSelectedText = null);
    _saveNote();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasSelection =
        _aiSelectedText != null && _aiSelectedText!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('aiQa'))),
      body: Column(
        children: [
          // Top half: the note (editable).
          Expanded(
            flex: 1,
            child: TextField(
              controller: _noteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          Container(height: 1, color: theme.dividerColor),
          // Bottom half: the AI chat (with selection reporting).
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                AIAssistantScreen(
                  embedded: true,
                  initialContextContent: _note.content,
                  noteId: widget.noteId,
                  onSelectionChanged: (sel) {
                    if (sel != _aiSelectedText) {
                      setState(() => _aiSelectedText = sel);
                    }
                  },
                ),
                // Floating "Insert into note" button — appears whenever the
                // user has selected non-empty text in any AI message.
                if (hasSelection)
                  Positioned(
                    right: 12,
                    top: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.primary,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _insertAtEnd(_aiSelectedText!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_comment_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.t('insertToNote'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
