/// Pure, testable text-edit helpers for the per-line hybrid editor.
///
/// The hybrid editor keeps the whole document as a single [String] and tracks
/// which single line is currently "active" (shown raw / editable). Every
/// mutation is expressed against the full document + a global caret offset so
/// it can be unit-tested without Flutter.
library;

/// Split a document into its lines. A trailing newline yields a trailing
/// empty line (so round-tripping through [applyLineEdit] is lossless).
List<String> splitLines(String content) => content.split('\n');

/// Replace the line at [lineIndex] with [newText] and return the new document.
/// Out-of-range indices are a no-op.
String applyLineEdit(String content, int lineIndex, String newText) {
  final lines = content.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return content;
  lines[lineIndex] = newText;
  return lines.join('\n');
}

/// Insert a line break at the global [caret] offset.
/// Returns the new document and the new caret (just after the inserted '\n').
(String, int) insertLineBreak(String content, int caret) {
  final c = caret.clamp(0, content.length);
  final newContent = content.replaceRange(c, c, '\n');
  return (newContent, c + 1);
}

/// Merge the line that begins at global [caret] upward into the previous line
/// by removing the '\n' just before it.
/// Returns the new document and the new caret (at the join point).
/// A no-op when [caret] is at the very start (nothing above to merge).
(String, int) mergeLineUp(String content, int caret) {
  if (caret <= 0) return (content, caret);
  final idx = content.lastIndexOf('\n', caret - 1);
  if (idx < 0) return (content, caret); // first line — nothing above
  final newContent = content.replaceRange(idx, idx + 1, '');
  return (newContent, caret - 1);
}
