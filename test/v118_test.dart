import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/note.dart';
import 'package:free_note/services/storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sanitizeFileName', () {
    test('strips illegal chars and trims', () {
      expect(sanitizeFileName('  Hello / World?  '), 'Hello World');
    });
    test('collapses whitespace', () {
      expect(sanitizeFileName('a   b\tc'), 'a bc');
    });
    test('empty -> Untitled', () {
      expect(sanitizeFileName(''), 'Untitled');
      expect(sanitizeFileName('   '), 'Untitled');
    });
    test('caps length', () {
      final long = 'x' * 200;
      expect(sanitizeFileName(long).length, lessThanOrEqualTo(80));
    });
  });

  group('Note.fileName / isPrivate', () {
    test('fileName derives from title', () {
      final n = Note(
        id: '1',
        title: 'My Note',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(n.fileName, 'My Note.md');
    });
    test('isPrivate true inside 私人笔记', () {
      final n = Note(
        id: '1',
        title: 'secret',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        relativePath: '私人笔记/secret.md',
      );
      expect(n.isPrivate, isTrue);
    });
    test('isPrivate false at root', () {
      final n = Note(
        id: '1',
        title: 'public',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        relativePath: 'public.md',
      );
      expect(n.isPrivate, isFalse);
    });
  });

  group('StorageService title-based rename', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fn_test_');
      await StorageService.instance.setFolder(tmp.path);
    });

    tearDown(() async {
      StorageService.instance.currentFolder = null;
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('saving a renamed note moves the file on disk', () async {
      final svc = StorageService.instance;
      final note = Note(
        id: '42',
        title: 'First',
        content: '# hi',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // First save: file named after title.
      await svc.saveNote(note);
      expect(File(p.join(tmp.path, 'First.md')).existsSync(), isTrue);

      // Rename title -> file should move to the new name.
      final renamed = note.copyWith(title: 'Second');
      await svc.saveNote(renamed);
      expect(File(p.join(tmp.path, 'First.md')).existsSync(), isFalse);
      expect(File(p.join(tmp.path, 'Second.md')).existsSync(), isTrue);

      // Old id-based legacy file must not linger.
      expect(File(p.join(tmp.path, '42.md')).existsSync(), isFalse);
    });

    test('two notes with same title get distinct files', () async {
      final svc = StorageService.instance;
      final a = Note(
        id: 'a',
        title: 'Dup',
        content: 'a',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final b = Note(
        id: 'b',
        title: 'Dup',
        content: 'b',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await svc.saveNote(a);
      await svc.saveNote(b);
      expect(File(p.join(tmp.path, 'Dup.md')).existsSync(), isTrue);
      expect(File(p.join(tmp.path, 'Dup (2).md')).existsSync(), isTrue);
    });

    test('setFolder auto-creates the private folder', () async {
      final private = Directory(p.join(tmp.path, '私人笔记'));
      // Already created by setUp's setFolder.
      expect(private.existsSync(), isTrue);
    });
  });
}
