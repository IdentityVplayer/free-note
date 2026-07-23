import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/utils/text_edit.dart';

void main() {
  group('text_edit helpers', () {
    test('splitLines round-trips and preserves trailing newline', () {
      expect(splitLines('a\nb\nc'), ['a', 'b', 'c']);
      expect(splitLines('a\nb\n'), ['a', 'b', '']);
      expect(splitLines(''), ['']);
    });

    test('applyLineEdit replaces a single line', () {
      expect(applyLineEdit('a\nb\nc', 1, 'B'), 'a\nB\nc');
      // out-of-range is a no-op
      expect(applyLineEdit('a\nb', 5, 'x'), 'a\nb');
      expect(applyLineEdit('a\nb', -1, 'x'), 'a\nb');
    });

    test('insertLineBreak splits at caret and returns new caret', () {
      final (doc, caret) = insertLineBreak('hello world', 5);
      expect(doc, 'hello\n world');
      expect(caret, 6);
      // caret at end appends an empty line
      final (doc2, caret2) = insertLineBreak('hi', 2);
      expect(doc2, 'hi\n');
      expect(caret2, 3);
      // caret is clamped
      final (doc3, caret3) = insertLineBreak('hi', 99);
      expect(doc3, 'hi\n');
      expect(caret3, 3);
    });

    test('mergeLineUp joins with previous line', () {
      // caret at start of line 2 ("world" begins at index 6)
      final (doc, caret) = mergeLineUp('hello\nworld', 6);
      expect(doc, 'helloworld');
      expect(caret, 5);
    });

    test('mergeLineUp is a no-op on the first line', () {
      final (doc, caret) = mergeLineUp('hello', 0);
      expect(doc, 'hello');
      expect(caret, 0);
    });

    test('split then merge round-trips', () {
      const original = 'line one\nline two\nline three';
      final (split, _) = insertLineBreak(original, 8); // after "line one"
      expect(split, 'line one\n\nline two\nline three');
      // merge the empty middle line back up
      final (merged, caret) = mergeLineUp(split, 9); // start of the empty line
      expect(merged, original);
      expect(caret, 8);
    });
  });
}
