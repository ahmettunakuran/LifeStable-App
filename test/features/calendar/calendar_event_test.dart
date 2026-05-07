// ignore_for_file: lines_longer_than_80_chars

/// Calendar & AI Integration Tests — TC44 through TC48
///
/// Tests for CalendarEventEntity: computed helpers (duration, overlap,
/// isTeamEvent), event type labels, and chronological sorting.
/// Pure Dart — no Firebase required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/calendar/domain/entities/calendar_event_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC44 ────────────────────────────────────────────────────────────────────
  group('TC44: event duration computed property', () {
    test('duration returns correct difference between endAt and startAt', () {
      final start = DateTime(2024, 6, 15, 9, 0);
      final end = DateTime(2024, 6, 15, 10, 30);

      final event = Fixtures.calendarEvent(startAt: start, endAt: end);

      expect(event.duration, const Duration(hours: 1, minutes: 30));
    });

    test('back-to-back 1-hour events each report 60-minute duration', () {
      final base = DateTime(2024, 6, 15, 8);
      final e1 = Fixtures.calendarEvent(
        id: 'ev1',
        startAt: base,
        endAt: base.add(const Duration(hours: 1)),
      );
      final e2 = Fixtures.calendarEvent(
        id: 'ev2',
        startAt: base.add(const Duration(hours: 1)),
        endAt: base.add(const Duration(hours: 2)),
      );

      expect(e1.duration.inMinutes, 60);
      expect(e2.duration.inMinutes, 60);
    });
  });

  // TC45 ────────────────────────────────────────────────────────────────────
  group('TC45: overlapsWith conflict detection', () {
    final base = DateTime(2024, 6, 15, 10);

    test('fully overlapping events detect a conflict', () {
      final a = Fixtures.calendarEvent(
        id: 'a',
        startAt: base,
        endAt: base.add(const Duration(hours: 2)),
      );
      final b = Fixtures.calendarEvent(
        id: 'b',
        startAt: base.add(const Duration(minutes: 30)),
        endAt: base.add(const Duration(hours: 1, minutes: 30)),
      );

      expect(a.overlapsWith(b), isTrue,
          reason: 'b is nested inside a — must be flagged as overlapping.');
    });

    test('consecutive events (end == start) do NOT overlap', () {
      final a = Fixtures.calendarEvent(
        id: 'a',
        startAt: base,
        endAt: base.add(const Duration(hours: 1)),
      );
      final b = Fixtures.calendarEvent(
        id: 'b',
        startAt: base.add(const Duration(hours: 1)),
        endAt: base.add(const Duration(hours: 2)),
      );

      expect(a.overlapsWith(b), isFalse,
          reason: 'Events that share only a boundary point must not overlap.');
    });

    test('non-adjacent events do not overlap', () {
      final morning = Fixtures.calendarEvent(
        id: 'morning',
        startAt: DateTime(2024, 6, 15, 9),
        endAt: DateTime(2024, 6, 15, 10),
      );
      final afternoon = Fixtures.calendarEvent(
        id: 'afternoon',
        startAt: DateTime(2024, 6, 15, 14),
        endAt: DateTime(2024, 6, 15, 15),
      );

      expect(morning.overlapsWith(afternoon), isFalse);
    });

    test('event does not overlap with itself (same id)', () {
      final event = Fixtures.calendarEvent(id: 'same');
      expect(event.overlapsWith(event), isFalse,
          reason: 'An event cannot conflict with itself.');
    });

    test('partial overlap at the end of first event is detected', () {
      final a = Fixtures.calendarEvent(
        id: 'a',
        startAt: base,
        endAt: base.add(const Duration(hours: 2)),
      );
      final b = Fixtures.calendarEvent(
        id: 'b',
        startAt: base.add(const Duration(hours: 1, minutes: 30)),
        endAt: base.add(const Duration(hours: 3)),
      );

      expect(a.overlapsWith(b), isTrue);
    });
  });

  // TC46 ────────────────────────────────────────────────────────────────────
  group('TC46: CalendarEventType label values', () {
    test('personal event label is "Personal"', () {
      expect(CalendarEventType.personal.label, 'Personal');
    });

    test('task event label is "Task"', () {
      expect(CalendarEventType.task.label, 'Task');
    });

    test('classSchedule event label is "Class"', () {
      expect(CalendarEventType.classSchedule.label, 'Class');
    });

    test('team event label is "Team"', () {
      expect(CalendarEventType.team.label, 'Team');
    });

    test('fromFirestore defaults to personal when eventType is unknown', () {
      final map = {
        'userId': 'user-1',
        'title': 'Unknown type event',
        'startAt': '2024-06-15T10:00:00.000',
        'endAt': '2024-06-15T11:00:00.000',
        'eventType': 'nonexistent_type',
        'isRecurring': false,
        'assignedMemberIds': <String>[],
      };

      final event = CalendarEventEntity.fromFirestore('ev-x', map);
      expect(event.eventType, CalendarEventType.personal,
          reason: 'Unknown eventType strings must fall back to personal.');
    });
  });

  // TC47 ────────────────────────────────────────────────────────────────────
  group('TC47: AI-linked and team calendar event structure', () {
    test('team event isTeamEvent returns true when both eventType=team and teamId are set', () {
      final teamEvent = Fixtures.calendarEvent(
        id: 'team-ev-1',
        eventType: CalendarEventType.team,
        teamId: 'team-delta',
        assignedMemberIds: ['member-1', 'member-2'],
      );

      expect(teamEvent.isTeamEvent, isTrue);
      expect(teamEvent.teamId, 'team-delta');
      expect(teamEvent.assignedMemberIds.length, 2);
    });

    test('isTeamEvent is false when teamId is null even if eventType=team', () {
      final orphan = Fixtures.calendarEvent(
        eventType: CalendarEventType.team,
        teamId: null,
      );
      expect(orphan.isTeamEvent, isFalse,
          reason: 'Without a teamId, the event cannot be a valid team event.');
    });

    test('task-linked event hasLinkedTask returns true', () {
      final linked = Fixtures.calendarEvent(
        eventType: CalendarEventType.task,
        linkedTaskId: 'task-abc',
      );
      expect(linked.hasLinkedTask, isTrue);
    });

    test('event without linkedTaskId hasLinkedTask returns false', () {
      final unlinked = Fixtures.calendarEvent(linkedTaskId: null);
      expect(unlinked.hasLinkedTask, isFalse);
    });
  });

  // TC48 ────────────────────────────────────────────────────────────────────
  group('TC48: events sorted by startAt ascending', () {
    test('sorting a mixed list puts earliest event first', () {
      final events = [
        Fixtures.calendarEvent(
          id: 'ev-3',
          startAt: DateTime(2024, 6, 15, 15),
          endAt: DateTime(2024, 6, 15, 16),
        ),
        Fixtures.calendarEvent(
          id: 'ev-1',
          startAt: DateTime(2024, 6, 15, 8),
          endAt: DateTime(2024, 6, 15, 9),
        ),
        Fixtures.calendarEvent(
          id: 'ev-2',
          startAt: DateTime(2024, 6, 15, 11),
          endAt: DateTime(2024, 6, 15, 12),
        ),
      ];

      final sorted = events..sort((a, b) => a.startAt.compareTo(b.startAt));

      expect(sorted.map((e) => e.id).toList(), ['ev-1', 'ev-2', 'ev-3'],
          reason: 'Events must appear in chronological order.');
    });

    test('same-day events across multiple types are ordered by time', () {
      final base = DateTime(2024, 6, 15);
      final events = [
        Fixtures.calendarEvent(
          id: 'team',
          startAt: base.add(const Duration(hours: 14)),
          endAt: base.add(const Duration(hours: 15)),
          eventType: CalendarEventType.team,
        ),
        Fixtures.calendarEvent(
          id: 'task',
          startAt: base.add(const Duration(hours: 9)),
          endAt: base.add(const Duration(hours: 10)),
          eventType: CalendarEventType.task,
        ),
      ];

      final sorted = events..sort((a, b) => a.startAt.compareTo(b.startAt));
      expect(sorted.first.id, 'task');
      expect(sorted.last.id, 'team');
    });
  });
}
