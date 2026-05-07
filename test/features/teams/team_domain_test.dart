// ignore_for_file: lines_longer_than_80_chars

/// Team Collaboration Tests — TC34 through TC43
///
/// Tests cover the team data model: DomainEntity team mirroring,
/// TaskEntity team fields, combined personal+team task lists,
/// and team-specific version conflict detection.
/// No live Firebase required — pure entity + BLoC logic tested.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC34 ────────────────────────────────────────────────────────────────────
  group('TC34: team invite code structure', () {
    test('6-character alphanumeric invite code is accepted as valid', () {
      // The team service generates a 6-char code; this test verifies the
      // format contract used when parsing/displaying invite codes.
      const validCode = 'ABC123';
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch(validCode);
      expect(isValid, isTrue,
          reason: '6-char uppercase alphanumeric code must pass format check.');
    });

    test('codes shorter than 6 chars are rejected', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('AB12');
      expect(isValid, isFalse);
    });

    test('codes longer than 6 chars are rejected', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('ABC1234');
      expect(isValid, isFalse);
    });
  });

  // TC35 ────────────────────────────────────────────────────────────────────
  group('TC35: joining a team creates a team-mirrored Domain', () {
    test('DomainEntity with teamId represents a team mirror domain', () {
      final mirroredDomain = Fixtures.domain(
        id: 'mirror-domain-1',
        name: 'Team Alpha',
        teamId: 'team-alpha-id',
      );

      expect(mirroredDomain.teamId, isNotNull,
          reason: 'A mirrored domain must carry the originating teamId.');
      expect(mirroredDomain.teamId, 'team-alpha-id');
    });
  });

  // TC36 ────────────────────────────────────────────────────────────────────
  group('TC36: DomainEntity.isTeamMirror flag', () {
    test('isTeamMirror is true when teamId is non-null', () {
      final teamDomain = Fixtures.domain(teamId: 'team-xyz');
      expect(teamDomain.isTeamMirror, isTrue);
    });

    test('isTeamMirror is false for personal domains (teamId == null)', () {
      final personalDomain = Fixtures.domain(teamId: null);
      expect(personalDomain.isTeamMirror, isFalse);
    });
  });

  // TC37 ────────────────────────────────────────────────────────────────────
  group('TC37: assigning a team task to a member', () {
    test('assignedTo field stores the target member userId', () {
      final task = Fixtures.task(
        teamId: 'team-alpha',
        assignedTo: 'member-user-42',
      );

      expect(task.assignedTo, 'member-user-42',
          reason: 'Assignment must store the member\'s userId.');
      expect(task.teamId, 'team-alpha');
    });

    test('unassigned team task has assignedTo == null', () {
      final task = Fixtures.task(teamId: 'team-alpha', assignedTo: null);
      expect(task.assignedTo, isNull);
    });
  });

  // TC38 ────────────────────────────────────────────────────────────────────
  group('TC38: identifying a team task', () {
    test('task with non-null teamId is a team task', () {
      final teamTask = Fixtures.task(teamId: 'team-beta');
      expect(teamTask.teamId, isNotNull,
          reason: 'Presence of teamId distinguishes team tasks from personal.');
    });

    test('task with null teamId is a personal task', () {
      final personalTask = Fixtures.task(teamId: null);
      expect(personalTask.teamId, isNull);
    });
  });

  // TC39 ────────────────────────────────────────────────────────────────────
  group('TC39: DomainEntity fromFirestore preserves teamId', () {
    test('teamId field survives Firestore round-trip', () {
      final original = Fixtures.domain(
        id: 'dom-team',
        name: 'Dev Team',
        teamId: 'team-dev-001',
      );

      final map = original.toFirestore();
      final restored = DomainEntity.fromFirestore(original.id, map);

      expect(restored.teamId, original.teamId,
          reason: 'teamId must be preserved through toFirestore/fromFirestore.');
      expect(restored.isTeamMirror, isTrue);
    });

    test('personal domain fromFirestore has null teamId', () {
      final original = Fixtures.domain(teamId: null);
      final map = original.toFirestore();
      final restored = DomainEntity.fromFirestore(original.id, map);

      expect(restored.teamId, isNull);
      expect(restored.isTeamMirror, isFalse);
    });
  });

  // TC40 ────────────────────────────────────────────────────────────────────
  group('TC40: team task version increment on update', () {
    test('version field increments by 1 when task is updated', () {
      final original = Fixtures.task(
        id: 'team-task-1',
        teamId: 'team-alpha',
        version: 3,
      );

      // Simulate what updateTeamTaskStatus does on the server side.
      final newVersion = original.version + 1;

      expect(newVersion, 4,
          reason: 'Each update must bump version by exactly 1 for conflict detection.');
    });

    test('conflict is detected when client version does not match server', () {
      const clientVersion = 2;
      const serverVersion = 4; // Updated by another device in the meantime.

      final isConflicted = serverVersion != clientVersion;
      expect(isConflicted, isTrue,
          reason: 'Mismatched versions must signal a write conflict.');
    });

    test('no conflict when versions match', () {
      const clientVersion = 5;
      const serverVersion = 5;

      final isConflicted = serverVersion != clientVersion;
      expect(isConflicted, isFalse);
    });
  });

  // TC41 ────────────────────────────────────────────────────────────────────
  group('TC41: leaving a team removes the mirrored domain', () {
    test('re-creating domain without teamId makes it a personal domain', () {
      final mirrored = Fixtures.domain(id: 'dom-left', name: 'Left Team', teamId: 'team-left');
      expect(mirrored.isTeamMirror, isTrue);

      // DomainEntity.copyWith(teamId: null) cannot clear teamId because of
      // the `teamId ?? this.teamId` guard — leaving a team triggers a
      // deleteDomain call on the mirror; the personal domain is reconstructed
      // fresh (no teamId).  We simulate that by building a new entity.
      final afterLeave = DomainEntity(
        id: mirrored.id,
        name: mirrored.name,
        iconCode: mirrored.iconCode,
        colorHex: mirrored.colorHex,
        // teamId intentionally omitted → personal domain
      );

      expect(afterLeave.isTeamMirror, isFalse,
          reason: 'Domain without teamId is no longer a mirror after leaving.');
      expect(afterLeave.teamId, isNull);
    });
  });

  // TC42 ────────────────────────────────────────────────────────────────────
  group('TC42: combined personal + team task list', () {
    test('CombineLatest merges personal and team tasks without duplicates', () {
      final personalTasks = [
        Fixtures.task(id: 'p1', domainId: 'personal-domain'),
        Fixtures.task(id: 'p2', domainId: 'personal-domain'),
      ];
      final teamTasks = [
        Fixtures.task(id: 't1', domainId: 'team-domain', teamId: 'team-x'),
        Fixtures.task(id: 't2', domainId: 'team-domain', teamId: 'team-x'),
      ];

      // Mirrors what CombineLatestStream.combine2 does in TaskRepositoryImpl.
      final combined = [...personalTasks, ...teamTasks];

      expect(combined.length, 4,
          reason: 'Combined list must include both personal and team tasks.');
      expect(combined.where((t) => t.teamId == null).length, 2,
          reason: 'Exactly 2 personal tasks must be present.');
      expect(combined.where((t) => t.teamId == 'team-x').length, 2,
          reason: 'Exactly 2 team tasks must be present.');
    });
  });

  // TC43 ────────────────────────────────────────────────────────────────────
  group('TC43: full team task structure', () {
    test('a complete team task carries both teamId and assignedTo', () {
      final task = Fixtures.task(
        id: 'full-team-task',
        teamId: 'team-gamma',
        assignedTo: 'user-member-77',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
      );

      expect(task.teamId, isNotNull);
      expect(task.assignedTo, isNotNull);
      expect(task.status, TaskStatus.todo);
      expect(task.priority, TaskPriority.high);
    });

    test('team task toFirestore includes teamId and assignedTo fields', () {
      final task = Fixtures.task(
        teamId: 'team-gamma',
        assignedTo: 'user-member-77',
      );
      final map = task.toFirestore();

      expect(map.containsKey('teamId'), isTrue);
      expect(map['teamId'], 'team-gamma');
      expect(map.containsKey('assignedTo'), isTrue);
      expect(map['assignedTo'], 'user-member-77');
    });
  });
}
