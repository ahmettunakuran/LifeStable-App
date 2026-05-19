// ignore_for_file: lines_longer_than_80_chars

/// Task Entity Extended Tests — TC61 through TC75
///
/// Additional pure-Dart tests for TaskEntity: copyWith field updates,
/// sorting, grouping, and Firestore map shape.
/// No Firebase connection required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC61 ────────────────────────────────────────────────────────────────────
  group('TC61: copyWith updates title field', () {
    test('updated title is reflected while all other fields are unchanged', () {
      final original = Fixtures.task(title: 'Original Title');
      final updated = original.copyWith(title: 'Updated Title');

      expect(updated.title, 'Updated Title');
      expect(updated.id, original.id);
      expect(updated.domainId, original.domainId);
      expect(updated.status, original.status);
      expect(updated.priority, original.priority);
    });
  });

  // TC62 ────────────────────────────────────────────────────────────────────
  group('TC62: copyWith updates priority field', () {
    test('changing priority to high leaves other fields intact', () {
      final original = Fixtures.task(priority: TaskPriority.low);
      final updated = original.copyWith(priority: TaskPriority.high);

      expect(updated.priority, TaskPriority.high);
      expect(updated.title, original.title);
      expect(updated.status, original.status);
    });

    test('changing priority to low from medium works correctly', () {
      final original = Fixtures.task(priority: TaskPriority.medium);
      final updated = original.copyWith(priority: TaskPriority.low);
      expect(updated.priority, TaskPriority.low);
    });
  });

  // TC63 ────────────────────────────────────────────────────────────────────
  group('TC63: copyWith updates domainId field', () {
    test('new domainId is stored while task id remains the same', () {
      final original = Fixtures.task(id: 'task-x', domainId: 'domain-old');
      final moved = original.copyWith(domainId: 'domain-new');

      expect(moved.domainId, 'domain-new');
      expect(moved.id, 'task-x');
    });
  });

  // TC64 ────────────────────────────────────────────────────────────────────
  group('TC64: copyWith updates version field', () {
    test('version increments via copyWith', () {
      final original = Fixtures.task(version: 3);
      final bumped = original.copyWith(version: original.version + 1);

      expect(bumped.version, 4);
      expect(original.version, 3, reason: 'Original must not be mutated.');
    });
  });

  // TC65 ────────────────────────────────────────────────────────────────────
  group('TC65: copyWith updates lastModifiedBy field', () {
    test('lastModifiedBy can be set for audit trail', () {
      final original = Fixtures.task(lastModifiedBy: null);
      final updated = original.copyWith(lastModifiedBy: 'user-editor-1');

      expect(updated.lastModifiedBy, 'user-editor-1');
      expect(original.lastModifiedBy, isNull);
    });
  });

  // TC66 ────────────────────────────────────────────────────────────────────
  group('TC66: tasks sorted by priority (high first)', () {
    test('sorting puts high-priority tasks before medium and low', () {
      final tasks = [
        Fixtures.task(id: 'lo', priority: TaskPriority.low),
        Fixtures.task(id: 'hi', priority: TaskPriority.high),
        Fixtures.task(id: 'me', priority: TaskPriority.medium),
      ];

      const priorityOrder = {
        TaskPriority.high: 0,
        TaskPriority.medium: 1,
        TaskPriority.low: 2,
      };

      final sorted = tasks
        ..sort((a, b) =>
            priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!));

      expect(sorted.first.priority, TaskPriority.high);
      expect(sorted.last.priority, TaskPriority.low);
    });
  });

  // TC67 ────────────────────────────────────────────────────────────────────
  group('TC67: tasks sorted by dueDate ascending', () {
    test('earliest dueDate appears first after sorting', () {
      final tasks = [
        Fixtures.task(id: 'far', dueDate: DateTime(2025, 12, 31)),
        Fixtures.task(id: 'near', dueDate: DateTime(2025, 1, 15)),
        Fixtures.task(id: 'mid', dueDate: DateTime(2025, 6, 1)),
      ];

      final sorted = tasks
        ..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });

      expect(sorted.first.id, 'near',
          reason: 'Task with the nearest dueDate must come first.');
      expect(sorted.last.id, 'far');
    });

    test('tasks with null dueDate are placed last', () {
      final tasks = [
        Fixtures.task(id: 'no-date', dueDate: null),
        Fixtures.task(id: 'has-date', dueDate: DateTime(2025, 3, 1)),
      ];

      final sorted = tasks
        ..sort((a, b) {
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });

      expect(sorted.last.id, 'no-date',
          reason: 'Tasks without a due date must be placed at the end.');
    });
  });

  // TC68 ────────────────────────────────────────────────────────────────────
  group('TC68: tasks grouped by status', () {
    test('grouping produces correct counts per status bucket', () {
      final tasks = [
        Fixtures.task(id: '1', status: TaskStatus.todo),
        Fixtures.task(id: '2', status: TaskStatus.todo),
        Fixtures.task(id: '3', status: TaskStatus.inProgress),
        Fixtures.task(id: '4', status: TaskStatus.done),
        Fixtures.task(id: '5', status: TaskStatus.done),
        Fixtures.task(id: '6', status: TaskStatus.done),
      ];

      final grouped = <TaskStatus, List<TaskEntity>>{};
      for (final t in tasks) {
        grouped.putIfAbsent(t.status, () => []).add(t);
      }

      expect(grouped[TaskStatus.todo]!.length, 2);
      expect(grouped[TaskStatus.inProgress]!.length, 1);
      expect(grouped[TaskStatus.done]!.length, 3);
    });
  });

  // TC69 ────────────────────────────────────────────────────────────────────
  group('TC69: filter tasks by done status', () {
    test('only completed tasks are returned when filtering by done', () {
      final tasks = [
        Fixtures.task(id: 'a', status: TaskStatus.done),
        Fixtures.task(id: 'b', status: TaskStatus.todo),
        Fixtures.task(id: 'c', status: TaskStatus.done),
        Fixtures.task(id: 'd', status: TaskStatus.inProgress),
      ];

      final done = tasks.where((t) => t.status == TaskStatus.done).toList();

      expect(done.length, 2);
      expect(done.every((t) => t.status == TaskStatus.done), isTrue);
      expect(done.map((t) => t.id), containsAll(['a', 'c']));
    });
  });

  // TC70 ────────────────────────────────────────────────────────────────────
  group('TC70: filter tasks by assignedTo', () {
    test('only tasks assigned to the requested member are returned', () {
      final tasks = [
        Fixtures.task(id: '1', assignedTo: 'member-alice'),
        Fixtures.task(id: '2', assignedTo: 'member-bob'),
        Fixtures.task(id: '3', assignedTo: 'member-alice'),
        Fixtures.task(id: '4', assignedTo: null),
      ];

      const target = 'member-alice';
      final aliceTasks =
          tasks.where((t) => t.assignedTo == target).toList();

      expect(aliceTasks.length, 2);
      expect(aliceTasks.map((t) => t.id), containsAll(['1', '3']));
    });
  });

  // TC71 ────────────────────────────────────────────────────────────────────
  group('TC71: toFirestore omits teamId when null', () {
    test('personal task map does not contain teamId key', () {
      final task = Fixtures.task(teamId: null);
      final map = task.toFirestore();

      expect(map.containsKey('teamId'), isFalse,
          reason: 'Firestore map must not include teamId for personal tasks.');
    });
  });

  // TC72 ────────────────────────────────────────────────────────────────────
  group('TC72: toFirestore omits assignedTo when null', () {
    test('unassigned task map does not contain assignedTo key', () {
      final task = Fixtures.task(assignedTo: null);
      final map = task.toFirestore();

      expect(map.containsKey('assignedTo'), isFalse,
          reason: 'Unassigned task must not carry an assignedTo field.');
    });
  });

  // TC73 ────────────────────────────────────────────────────────────────────
  group('TC73: toFirestore includes description when set', () {
    test('map contains non-null description value', () {
      final task = Fixtures.task(description: 'Write unit tests for the API');
      final map = task.toFirestore();

      expect(map['description'], 'Write unit tests for the API');
    });

    test('map contains null when description is not set', () {
      final task = Fixtures.task(description: null);
      final map = task.toFirestore();

      expect(map['description'], isNull);
    });
  });

  // TC74 ────────────────────────────────────────────────────────────────────
  group('TC74: fromFirestore parses version field', () {
    test('explicit version value is parsed correctly', () {
      final entity = TaskEntity.fromFirestore('v-task', {
        'domainId': 'dom-1',
        'title': 'Versioned task',
        'version': 7,
      });

      expect(entity.version, 7,
          reason: 'version field must be read from the Firestore map.');
    });

    test('missing version defaults to 0', () {
      final entity = TaskEntity.fromFirestore('v-task-2', {
        'domainId': 'dom-1',
        'title': 'No version task',
        // 'version' intentionally omitted
      });

      expect(entity.version, 0,
          reason: 'Absent version field must default to 0 for backwards compat.');
    });
  });

  // TC75 ────────────────────────────────────────────────────────────────────
  group('TC75: fromFirestore parses lastModifiedBy field', () {
    test('lastModifiedBy is parsed when present', () {
      final entity = TaskEntity.fromFirestore('lmb-task', {
        'domainId': 'dom-1',
        'title': 'Audited task',
        'lastModifiedBy': 'user-auditor-99',
      });

      expect(entity.lastModifiedBy, 'user-auditor-99');
    });

    test('missing lastModifiedBy defaults to null', () {
      final entity = TaskEntity.fromFirestore('lmb-task-2', {
        'domainId': 'dom-1',
        'title': 'No audit task',
      });

      expect(entity.lastModifiedBy, isNull);
    });
  });
}
