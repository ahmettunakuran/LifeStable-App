// ignore_for_file: lines_longer_than_80_chars

/// Task Entity / Data Layer Tests — TC14, TC15, TC16, TC17, TC18, TC20
///
/// Pure Dart tests for TaskEntity serialization, filtering, and helper logic.
/// These require no mocking and run without any Firebase connection.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC14 ────────────────────────────────────────────────────────────────────
  group('TC14: filter tasks by priority', () {
    test('filtering by high priority returns only high-priority tasks', () {
      final tasks = [
        Fixtures.task(id: '1', title: 'Critical issue', priority: TaskPriority.high),
        Fixtures.task(id: '2', title: 'Nice-to-have', priority: TaskPriority.low),
        Fixtures.task(id: '3', title: 'Regular work', priority: TaskPriority.medium),
        Fixtures.task(id: '4', title: 'Urgent fix', priority: TaskPriority.high),
      ];

      final highPriority = tasks
          .where((t) => t.priority == TaskPriority.high)
          .toList();

      expect(highPriority.length, 2);
      expect(highPriority.every((t) => t.priority == TaskPriority.high), isTrue);
      expect(highPriority.map((t) => t.id), containsAll(['1', '4']));
    });

    test('filtering by low priority excludes medium and high tasks', () {
      final tasks = [
        Fixtures.task(priority: TaskPriority.low),
        Fixtures.task(id: 'x', priority: TaskPriority.high),
      ];
      final lowOnly = tasks.where((t) => t.priority == TaskPriority.low).toList();
      expect(lowOnly.length, 1);
    });
  });

  // TC15 ────────────────────────────────────────────────────────────────────
  group('TC15: TaskEntity fromFirestore handles invalid/missing fields', () {
    test('missing status defaults to todo', () {
      final entity = TaskEntity.fromFirestore('t1', {
        'domainId': 'dom-1',
        'title': 'Task without status',
        // 'status' intentionally omitted
      });
      expect(entity.status, TaskStatus.todo);
    });

    test('unknown status string defaults to todo', () {
      final entity = TaskEntity.fromFirestore('t2', {
        'domainId': 'dom-1',
        'title': 'Bad status task',
        'status': 'invalid_value',
      });
      expect(entity.status, TaskStatus.todo);
    });

    test('missing priority defaults to medium', () {
      final entity = TaskEntity.fromFirestore('t3', {
        'domainId': 'dom-1',
        'title': 'Task without priority',
      });
      expect(entity.priority, TaskPriority.medium);
    });

    test('valid dueDate string is parsed correctly', () {
      const iso = '2024-12-31T00:00:00.000';
      final entity = TaskEntity.fromFirestore('t4', {
        'domainId': 'dom-1',
        'title': 'Deadline task',
        'dueDate': iso,
      });
      expect(entity.dueDate, isNotNull);
      expect(entity.dueDate!.year, 2024);
      expect(entity.dueDate!.month, 12);
      expect(entity.dueDate!.day, 31);
    });

    test('null dueDate leaves field as null', () {
      final entity = TaskEntity.fromFirestore('t5', {
        'domainId': 'dom-1',
        'title': 'No deadline task',
        'dueDate': null,
      });
      expect(entity.dueDate, isNull);
    });
  });

  // TC16 ────────────────────────────────────────────────────────────────────
  group('TC16: past dueDate is detectable', () {
    test('task with dueDate in the past is overdue', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      final task = Fixtures.task(dueDate: pastDate);

      final isOverdue = task.dueDate != null &&
          task.dueDate!.isBefore(DateTime.now());

      expect(isOverdue, isTrue,
          reason: 'Tasks with past dueDate must be flagged as overdue.');
    });

    test('task with future dueDate is not overdue', () {
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final task = Fixtures.task(dueDate: futureDate);

      final isOverdue = task.dueDate != null &&
          task.dueDate!.isBefore(DateTime.now());

      expect(isOverdue, isFalse);
    });

    test('task with null dueDate is never overdue', () {
      final task = Fixtures.task(dueDate: null);
      final isOverdue = task.dueDate != null &&
          task.dueDate!.isBefore(DateTime.now());
      expect(isOverdue, isFalse);
    });
  });

  // TC17 ────────────────────────────────────────────────────────────────────
  group('TC17: update task description via copyWith', () {
    test('copyWith replaces description while keeping all other fields', () {
      final original = Fixtures.task(
        id: 'task-a',
        title: 'Design sprint',
        description: null,
        status: TaskStatus.inProgress,
      );

      final updated = original.copyWith(
        description: 'Prepare wireframes and user flows for review.',
      );

      expect(updated.description, 'Prepare wireframes and user flows for review.');
      expect(updated.id, original.id);
      expect(updated.title, original.title);
      expect(updated.status, original.status);
    });

    test('copyWith with no arguments returns equivalent task', () {
      final task = Fixtures.task(description: 'Some description');
      final copy = task.copyWith();
      expect(copy.description, task.description);
      expect(copy.title, task.title);
      expect(copy.status, task.status);
    });
  });

  // TC18 ────────────────────────────────────────────────────────────────────
  group('TC18: filter tasks by domainId', () {
    test('only tasks matching the requested domainId are returned', () {
      final tasks = [
        Fixtures.task(id: '1', domainId: 'health'),
        Fixtures.task(id: '2', domainId: 'career'),
        Fixtures.task(id: '3', domainId: 'health'),
        Fixtures.task(id: '4', domainId: 'personal'),
      ];

      const targetDomain = 'health';
      final filtered = tasks.where((t) => t.domainId == targetDomain).toList();

      expect(filtered.length, 2);
      expect(filtered.every((t) => t.domainId == targetDomain), isTrue);
      expect(filtered.map((t) => t.id), containsAll(['1', '3']));
    });
  });

  // TC20 ────────────────────────────────────────────────────────────────────
  group('TC20: task search by title substring', () {
    test('case-insensitive substring search returns matching tasks', () {
      final tasks = [
        Fixtures.task(id: '1', title: 'Buy groceries'),
        Fixtures.task(id: '2', title: 'Complete project report'),
        Fixtures.task(id: '3', title: 'Call doctor appointment'),
        Fixtures.task(id: '4', title: 'Project planning meeting'),
      ];

      const query = 'project';
      final results = tasks
          .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(results.length, 2);
      expect(results.map((t) => t.id), containsAll(['2', '4']));
    });

    test('empty query returns all tasks', () {
      final tasks = List.generate(5, (i) => Fixtures.task(id: 'task-$i'));
      final results = tasks
          .where((t) => t.title.toLowerCase().contains(''))
          .toList();
      expect(results.length, 5);
    });

    test('query with no match returns empty list', () {
      final tasks = [Fixtures.task(title: 'Buy milk')];
      final results = tasks
          .where((t) => t.title.toLowerCase().contains('xyz'))
          .toList();
      expect(results, isEmpty);
    });
  });

  // Serialization round-trip (supports TC15)
  group('TaskEntity toFirestore / fromFirestore round-trip', () {
    test('serialized and deserialized entity preserves all fields', () {
      final original = Fixtures.task(
        id: 'rt-1',
        domainId: 'dom-rt',
        title: 'Round-trip task',
        description: 'Some description',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        dueDate: DateTime(2025, 3, 15),
        teamId: 'team-abc',
        assignedTo: 'user-xyz',
      );

      final map = original.toFirestore();
      final restored = TaskEntity.fromFirestore(original.id, map);

      expect(restored.domainId, original.domainId);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.status, original.status);
      expect(restored.priority, original.priority);
      expect(restored.dueDate!.toIso8601String(),
          original.dueDate!.toIso8601String());
      expect(restored.teamId, original.teamId);
      expect(restored.assignedTo, original.assignedTo);
    });
  });
}
