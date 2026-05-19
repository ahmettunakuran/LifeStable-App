// ignore_for_file: lines_longer_than_80_chars

/// Team Collaboration Extended Tests — TC116 through TC125
///
/// Additional pure-Dart tests covering team invite code edge cases,
/// task assignment mutations, version handling, and combined list
/// composition. No Firebase connection required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC116 ───────────────────────────────────────────────────────────────────
  group('TC116: invite code with lowercase letters is rejected', () {
    test('code with lowercase letters fails the 6-char uppercase alphanumeric rule', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('abc123');
      expect(isValid, isFalse,
          reason: 'Invite codes must be uppercase; lowercase is not accepted.');
    });

    test('mixed-case code is also rejected', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('Abc123');
      expect(isValid, isFalse);
    });
  });

  // TC117 ───────────────────────────────────────────────────────────────────
  group('TC117: invite code with special characters is rejected', () {
    test('code containing a hyphen fails validation', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('AB-123');
      expect(isValid, isFalse);
    });

    test('code containing a space fails validation', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('ABC 23');
      expect(isValid, isFalse);
    });

    test('code with punctuation fails validation', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('AB!123');
      expect(isValid, isFalse);
    });
  });

  // TC118 ───────────────────────────────────────────────────────────────────
  group('TC118: all-digit invite code is valid', () {
    test('six-digit numeric code passes the format check', () {
      final isValid = RegExp(r'^[A-Z0-9]{6}$').hasMatch('123456');
      expect(isValid, isTrue,
          reason: 'Digits-only codes satisfy the [A-Z0-9]{6} constraint.');
    });
  });

  // TC119 ───────────────────────────────────────────────────────────────────
  group('TC119: team tasks can be filtered from a combined list', () {
    test('filtering by non-null teamId isolates team tasks', () {
      final combined = [
        Fixtures.task(id: 'p1', teamId: null),
        Fixtures.task(id: 't1', teamId: 'team-x'),
        Fixtures.task(id: 'p2', teamId: null),
        Fixtures.task(id: 't2', teamId: 'team-x'),
        Fixtures.task(id: 't3', teamId: 'team-y'),
      ];

      final teamTasks = combined.where((t) => t.teamId != null).toList();

      expect(teamTasks.length, 3);
      expect(teamTasks.every((t) => t.teamId != null), isTrue);
    });
  });

  // TC120 ───────────────────────────────────────────────────────────────────
  group('TC120: personal task count in combined list is correct', () {
    test('filtering by null teamId returns only personal tasks', () {
      final combined = [
        Fixtures.task(id: 'p1', teamId: null),
        Fixtures.task(id: 'p2', teamId: null),
        Fixtures.task(id: 't1', teamId: 'team-1'),
      ];

      final personalTasks = combined.where((t) => t.teamId == null).toList();

      expect(personalTasks.length, 2,
          reason: 'Exactly 2 personal tasks must be present in the list.');
    });
  });

  // TC121 ───────────────────────────────────────────────────────────────────
  group('TC121: task reassignment changes assignedTo via copyWith', () {
    test('reassigning from member-A to member-B updates assignedTo correctly', () {
      final original = Fixtures.task(
        teamId: 'team-alpha',
        assignedTo: 'member-A',
      );
      final reassigned = original.copyWith(assignedTo: 'member-B');

      expect(reassigned.assignedTo, 'member-B',
          reason: 'copyWith must allow task reassignment to a different member.');
      expect(original.assignedTo, 'member-A',
          reason: 'Original task must not be mutated.');
    });
  });

  // TC122 ───────────────────────────────────────────────────────────────────
  group('TC122: task lastModifiedBy field can be set', () {
    test('lastModifiedBy stores the uid of the user who last changed the task', () {
      final task = Fixtures.task(lastModifiedBy: 'user-editor-55');

      expect(task.lastModifiedBy, 'user-editor-55',
          reason: 'lastModifiedBy enables audit trail tracking.');
    });

    test('task with no modifier has null lastModifiedBy', () {
      final task = Fixtures.task(lastModifiedBy: null);
      expect(task.lastModifiedBy, isNull);
    });
  });

  // TC123 ───────────────────────────────────────────────────────────────────
  group('TC123: team task with null assignedTo is an unassigned team task', () {
    test('team task without an assignedTo member is still a valid team task', () {
      final task = Fixtures.task(teamId: 'team-beta', assignedTo: null);

      expect(task.teamId, isNotNull,
          reason: 'Team membership is from teamId, not assignedTo.');
      expect(task.assignedTo, isNull,
          reason: 'Unassigned team tasks are valid — they can be claimed later.');
    });
  });

  // TC124 ───────────────────────────────────────────────────────────────────
  group('TC124: version 0 is the default initial version', () {
    test('new task starts with version=0 when not specified', () {
      final task = TaskEntity(
        id: 'fresh-task',
        domainId: 'dom-1',
        title: 'Brand new task',
      );

      expect(task.version, 0,
          reason: 'Version 0 signals the first write; no conflicts can exist yet.');
    });

    test('version increments from 0 to 1 on first update', () {
      final original = Fixtures.task(version: 0);
      final afterFirstUpdate = original.copyWith(version: original.version + 1);

      expect(afterFirstUpdate.version, 1);
    });
  });

  // TC125 ───────────────────────────────────────────────────────────────────
  group('TC125: large version numbers increment correctly', () {
    test('version at 999 increments to 1000 without issues', () {
      final task = Fixtures.task(version: 999);
      final updated = task.copyWith(version: task.version + 1);

      expect(updated.version, 1000,
          reason: 'Version counter must handle large values for long-lived tasks.');
    });
  });
}
