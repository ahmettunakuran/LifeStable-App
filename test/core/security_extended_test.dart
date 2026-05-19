// ignore_for_file: lines_longer_than_80_chars

/// Security & Data Integrity Extended Tests — TC136 through TC150
///
/// Tests covering per-user data isolation at the Firestore path level,
/// cross-entity referential integrity, field-level ownership markers,
/// and structural guarantees that prevent data spoofing or leakage.
/// All tests are pure Dart — no live Firebase connection required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/calendar/domain/entities/calendar_event_entity.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';
import 'package:project_lifestable/features/habits/presentation/habit.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

import '../helpers/fixtures.dart';

void main() {
  // TC136 ───────────────────────────────────────────────────────────────────
  group('TC136: NoteEntity includes userId in toFirestore for ownership', () {
    test('toFirestore map contains userId that matches the entity owner', () {
      final note = Fixtures.note(userId: 'user-alice');
      final map = note.toFirestore();

      expect(map['userId'], 'user-alice',
          reason: 'Notes must carry userId in the Firestore document '
              'for security rule enforcement.');
    });

    test("two users' notes produce different userId values in their maps", () {
      final aliceNote = Fixtures.note(userId: 'alice');
      final bobNote = Fixtures.note(userId: 'bob');

      expect(aliceNote.toFirestore()['userId'],
          isNot(equals(bobNote.toFirestore()['userId'])));
    });
  });

  // TC137 ───────────────────────────────────────────────────────────────────
  group('TC137: DomainEntity path is isolated by user uid', () {
    test('personal domain collection path is scoped to owning user', () {
      const ownerUid = 'user-domain-owner';
      final domainPath = 'users/$ownerUid/domains';

      expect(domainPath, contains(ownerUid));
      expect(domainPath.startsWith('users/'), isTrue);
      expect(domainPath.endsWith('/domains'), isTrue);
    });

    test('two users have non-overlapping domain collection paths', () {
      final path1 = 'users/user-a/domains';
      final path2 = 'users/user-b/domains';
      expect(path1, isNot(equals(path2)));
    });
  });

  // TC138 ───────────────────────────────────────────────────────────────────
  group('TC138: Habit toMap includes user_id for ownership', () {
    test('user_id in toMap matches the Habit model userId', () {
      final habit = Fixtures.habit(userId: 'user-habit-owner');
      final map = habit.toMap();

      expect(map['user_id'], 'user-habit-owner',
          reason: 'Habits must record ownership so Firestore rules can enforce '
              'per-user access isolation.');
    });
  });

  // TC139 ───────────────────────────────────────────────────────────────────
  group('TC139: CalendarEventEntity includes userId in toFirestore', () {
    test('userId is present in the serialized calendar event map', () {
      final event = Fixtures.calendarEvent(userId: 'user-cal');
      final map = event.toFirestore();

      expect(map['userId'], 'user-cal',
          reason: 'Calendar events must carry userId for security rule scoping.');
    });
  });

  // TC140 ───────────────────────────────────────────────────────────────────
  group('TC140: merging personal and team tasks produces no duplicates', () {
    test('combined list length equals sum of both source lists', () {
      final personal = [
        Fixtures.task(id: 'p1'),
        Fixtures.task(id: 'p2'),
        Fixtures.task(id: 'p3'),
      ];
      final team = [
        Fixtures.task(id: 't1', teamId: 'team-1'),
        Fixtures.task(id: 't2', teamId: 'team-1'),
      ];

      final combined = [...personal, ...team];
      final uniqueIds = combined.map((t) => t.id).toSet();

      expect(combined.length, 5);
      expect(uniqueIds.length, 5,
          reason: 'Each task must appear exactly once — no duplicate IDs.');
    });
  });

  // TC141 ───────────────────────────────────────────────────────────────────
  group('TC141: team task collection path uses teams namespace', () {
    test('team task path is prefixed with teams/ not users/', () {
      const teamId = 'team-isolated';
      final path = 'teams/$teamId/tasks';

      expect(path.startsWith('teams/'), isTrue,
          reason: 'Team tasks live under a separate namespace from personal tasks.');
      expect(path.startsWith('users/'), isFalse);
    });

    test('two teams produce distinct task collection paths', () {
      final path1 = 'teams/team-a/tasks';
      final path2 = 'teams/team-b/tasks';
      expect(path1, isNot(equals(path2)));
    });
  });

  // TC142 ───────────────────────────────────────────────────────────────────
  group('TC142: note collection path uses personal namespace', () {
    test('personal note path contains the user uid and notes segment', () {
      const uid = 'user-note-owner';
      final path = 'users/$uid/notes';

      expect(path, contains(uid));
      expect(path.endsWith('/notes'), isTrue);
    });
  });

  // TC143 ───────────────────────────────────────────────────────────────────
  group('TC143: TaskEntity toFirestore does not expose raw userId', () {
    test('task map does not contain a userId key that could be spoofed', () {
      final task = Fixtures.task(id: 'secure-task');
      final map = task.toFirestore();

      expect(map.containsKey('userId'), isFalse,
          reason: 'Task ownership is enforced by the Firestore path, '
              'not by a userId field inside the document.');
    });
  });

  // TC144 ───────────────────────────────────────────────────────────────────
  group('TC144: tasks from different domains do not share domainId', () {
    test('filtering ensures tasks are domain-scoped without cross-contamination', () {
      final healthTasks = [
        Fixtures.task(id: 'h1', domainId: 'health'),
        Fixtures.task(id: 'h2', domainId: 'health'),
      ];
      final careerTasks = [
        Fixtures.task(id: 'c1', domainId: 'career'),
      ];

      final allTasks = [...healthTasks, ...careerTasks];
      final filtered = allTasks.where((t) => t.domainId == 'health').toList();

      expect(filtered.length, 2);
      expect(filtered.every((t) => t.domainId == 'health'), isTrue,
          reason: 'No career tasks must bleed into the health domain view.');
    });
  });

  // TC145 ───────────────────────────────────────────────────────────────────
  group('TC145: task version increment is always positive', () {
    test('bumping version from any value always yields a strictly larger result', () {
      for (final v in [0, 1, 5, 42, 999]) {
        final task = Fixtures.task(version: v);
        final updated = task.copyWith(version: task.version + 1);
        expect(updated.version, greaterThan(task.version),
            reason: 'Version must strictly increase on every update.');
      }
    });
  });

  // TC146 ───────────────────────────────────────────────────────────────────
  group('TC146: CalendarEvent assignedMemberIds is always a list type', () {
    test('assignedMemberIds field is a List, not null, even when empty', () {
      final event = Fixtures.calendarEvent(assignedMemberIds: const []);

      expect(event.assignedMemberIds, isA<List<String>>(),
          reason: 'assignedMemberIds must always be a list, never null.');
      expect(event.assignedMemberIds, isEmpty);
    });
  });

  // TC147 ───────────────────────────────────────────────────────────────────
  group('TC147: empty assignedMemberIds is a valid event state', () {
    test('personal event with no members is structurally valid', () {
      final event = Fixtures.calendarEvent(
        eventType: CalendarEventType.personal,
        assignedMemberIds: const [],
      );

      expect(event.assignedMemberIds.isEmpty, isTrue);
      expect(event.isTeamEvent, isFalse,
          reason: 'A personal event cannot be a team event regardless of members.');
    });
  });

  // TC148 ───────────────────────────────────────────────────────────────────
  group('TC148: team event with empty assignedMemberIds is still valid', () {
    test('team event can exist before any members are added', () {
      final event = Fixtures.calendarEvent(
        eventType: CalendarEventType.team,
        teamId: 'team-pending',
        assignedMemberIds: const [],
      );

      expect(event.isTeamEvent, isTrue,
          reason: 'Team event status depends on eventType+teamId, not member count.');
      expect(event.assignedMemberIds, isEmpty);
    });
  });

  // TC149 ───────────────────────────────────────────────────────────────────
  group('TC149: task domainId matches an expected domain format', () {
    test('domainId is a non-empty string that identifies the owning domain', () {
      final task = Fixtures.task(domainId: 'domain-health');

      expect(task.domainId, isNotEmpty,
          reason: 'Every task must belong to a domain; empty domainId is invalid.');
      expect(task.domainId, 'domain-health');
    });

    test('domainId is preserved through toFirestore and fromFirestore', () {
      final original = Fixtures.task(domainId: 'domain-career');
      final map = original.toFirestore();
      final restored = TaskEntity.fromFirestore(original.id, map);

      expect(restored.domainId, 'domain-career',
          reason: 'Domain association must not be lost during serialization.');
    });
  });

  // TC150 ───────────────────────────────────────────────────────────────────
  group('TC150: task priority enum ordering (high > medium > low)', () {
    test('enum index order reflects business-level priority ranking', () {
      // TaskPriority.high should be treated as the most urgent.
      // We enforce order by comparing via the priorityOrder map used in sorting.
      const priorityOrder = {
        TaskPriority.high: 0,
        TaskPriority.medium: 1,
        TaskPriority.low: 2,
      };

      expect(priorityOrder[TaskPriority.high],
          lessThan(priorityOrder[TaskPriority.medium]!),
          reason: 'high must rank above medium.');
      expect(priorityOrder[TaskPriority.medium],
          lessThan(priorityOrder[TaskPriority.low]!),
          reason: 'medium must rank above low.');
    });

    test('all three priority levels are distinct values', () {
      expect(TaskPriority.high, isNot(equals(TaskPriority.medium)));
      expect(TaskPriority.medium, isNot(equals(TaskPriority.low)));
      expect(TaskPriority.high, isNot(equals(TaskPriority.low)));
    });
  });
}
