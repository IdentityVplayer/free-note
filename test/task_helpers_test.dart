import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/models/task.dart';
import 'package:free_note/utils/task_helpers.dart';

Task _t(
  String id, {
  bool done = false,
  String? parentId,
  DateTime? reminder,
  RepeatConfig? repeat,
  String title = 't',
}) => Task(
  id: id,
  title: title,
  createdAt: DateTime(2026),
  done: done,
  parentId: parentId,
  reminder: reminder,
  repeat: repeat,
);

void main() {
  group('recomputeMainDone', () {
    test('marks main done when all subtasks done (auto on)', () {
      final tasks = [
        _t('m'),
        _t('s1', parentId: 'm', done: true),
        _t('s2', parentId: 'm', done: true),
      ];
      final out = recomputeMainDone(tasks, 'm', true);
      expect(out.firstWhere((t) => t.id == 'm').done, isTrue);
    });

    test('keeps main undone when a subtask is open', () {
      final tasks = [
        _t('m'),
        _t('s1', parentId: 'm', done: true),
        _t('s2', parentId: 'm', done: false),
      ];
      final out = recomputeMainDone(tasks, 'm', true);
      expect(out.firstWhere((t) => t.id == 'm').done, isFalse);
    });

    test('no-op when auto is false', () {
      final tasks = [
        _t('m'),
        _t('s1', parentId: 'm', done: true),
        _t('s2', parentId: 'm', done: true),
      ];
      final out = recomputeMainDone(tasks, 'm', false);
      expect(identical(out, tasks), isTrue);
      expect(out.firstWhere((t) => t.id == 'm').done, isFalse);
    });

    test('no-op for main task with no subtasks', () {
      final tasks = [_t('m', done: false)];
      final out = recomputeMainDone(tasks, 'm', true);
      expect(out.firstWhere((t) => t.id == 'm').done, isFalse);
    });
  });

  group('nextRepeatDue', () {
    final base = DateTime(2026, 1, 1, 9, 0);
    test('day', () {
      expect(
        nextRepeatDue(base, const RepeatConfig(every: 2, unit: 'day')),
        DateTime(2026, 1, 3, 9, 0),
      );
    });
    test('week', () {
      expect(
        nextRepeatDue(base, const RepeatConfig(every: 1, unit: 'week')),
        DateTime(2026, 1, 8, 9, 0),
      );
    });
    test('month rolls over', () {
      expect(
        nextRepeatDue(
          DateTime(2026, 11, 15, 9, 0),
          const RepeatConfig(every: 2, unit: 'month'),
        ),
        DateTime(2027, 1, 15, 9, 0),
      );
    });
    test('year', () {
      expect(
        nextRepeatDue(base, const RepeatConfig(every: 1, unit: 'year')),
        DateTime(2027, 1, 1, 9, 0),
      );
    });
  });

  group('freshTaskCopy', () {
    test('copies main + subtasks with new ids, all undone', () {
      final main = _t('m', done: true);
      final subs = [
        _t('s1', parentId: 'm', done: true),
        _t('s2', parentId: 'm'),
      ];
      final (newId, freshMain, freshSubs) = freshTaskCopy(main, subs);
      expect(newId, isNot('m'));
      expect(freshMain.id, newId);
      expect(freshMain.done, isFalse);
      expect(freshMain.parentId, isNull);
      expect(freshSubs.length, 2);
      expect(freshSubs.every((s) => s.done == false), isTrue);
      expect(freshSubs.every((s) => s.parentId == newId), isTrue);
      expect(freshSubs.every((s) => s.id != s.parentId), isTrue);
    });
  });
}
