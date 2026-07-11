import 'package:flutter_test/flutter_test.dart';

import 'package:free_note/models/note.dart';

void main() {
  test('Note model creates and serializes correctly', () {
    final now = DateTime.now();
    final note = Note(
      id: 'test-1',
      title: 'Test Note',
      content: '# Hello\nThis is a **test**.',
      createdAt: now,
      updatedAt: now,
      tags: ['test', 'demo'],
    );

    final json = note.toJson();
    expect(json['title'], 'Test Note');
    expect(json['tags'], ['test', 'demo']);

    final restored = Note.fromJson(json);
    expect(restored.title, 'Test Note');
    expect(restored.content, '# Hello\nThis is a **test**.');
    expect(restored.tags, ['test', 'demo']);
  });

  test('Note preview strips markdown characters', () {
    final note = Note(
      id: 'test-2',
      title: 'Preview Test',
      content: '**Bold** and *italic* and `code`',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expect(note.preview, contains('Bold'));
    expect(note.preview, contains('italic'));
    expect(note.preview, isNot(contains('**')));
  });
}
