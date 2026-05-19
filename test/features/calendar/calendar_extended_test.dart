// ignore_for_file: lines_longer_than_80_chars

/// Calendar Extended Tests — TC96 through TC105
///
/// Additional pure-Dart tests for CalendarEventEntity: copyWith, duration
/// edge cases, toFirestore/fromFirestore round-trip, and event filtering.
/// No Firebase connection required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/calendar/domain/entities/calendar_event_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC96 ────────────────────────────────────────────────────────────────────
  group('TC96: CalendarEventEntity copyWith updates title', () {
    test('new title is reflected; other fields remain unchanged', () {
      final original = Fixtures.calendarEvent(title: 'Old Title');
      final updated = original.copyWith(title: 'New Title');

      expect(updated.title, 'New Title');
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.startAt, original.startAt);
      expect(updated.endAt, original.endAt);
    });
  });

  // TC97 ────────────────────────────────────────────────────────────────────
  group('TC97: copyWith updates eventType', () {
    test('event can be reclassified from personal to task type', () {
      final original =
          Fixtures.calendarEvent(eventType: CalendarEventType.personal);
      final reclassified =
          original.copyWith(eventType: CalendarEventType.task);

      expect(reclassified.eventType, CalendarEventType.task);
      expect(original.eventType, CalendarEventType.personal,
          reason: 'Original must not be mutated (immutability).');
    });
  });

  // TC98 ────────────────────────────────────────────────────────────────────
  group('TC98: event spanning midnight has correct duration', () {
    test('event from 23:00 to 01:00 next day reports 2-hour duration', () {
      final start = DateTime(2024, 6, 15, 23, 0);
      final end = DateTime(2024, 6, 16, 1, 0); // next day
      final event = Fixtures.calendarEvent(startAt: start, endAt: end);

      expect(event.duration, const Duration(hours: 2),
          reason: 'Midnight-spanning events must report the correct duration.');
    });
  });

  // TC99 ────────────────────────────────────────────────────────────────────
  group('TC99: recurring event flag is serialized to Firestore', () {
    test('isRecurring=true is preserved in toFirestore map', () {
      final event =
          Fixtures.calendarEvent().copyWith(isRecurring: true);
      final map = event.toFirestore();

      expect(map['isRecurring'], isTrue,
          reason: 'isRecurring flag must be written to Firestore for repeat sync.');
    });

    test('isRecurring defaults to false and is serialized correctly', () {
      final event = Fixtures.calendarEvent();
      final map = event.toFirestore();
      expect(map['isRecurring'], isFalse);
    });
  });

  // TC100 ───────────────────────────────────────────────────────────────────
  group('TC100: event with colorHex is preserved in toFirestore', () {
    test('colorHex appears in the map when set', () {
      final event = Fixtures.calendarEvent().copyWith(colorHex: '#FF5722');
      final map = event.toFirestore();

      expect(map.containsKey('colorHex'), isTrue,
          reason: 'colorHex is required for themed calendar rendering.');
      expect(map['colorHex'], '#FF5722');
    });

    test('colorHex key is absent when not set', () {
      final event = Fixtures.calendarEvent(); // colorHex = null by default
      final map = event.toFirestore();

      expect(map.containsKey('colorHex'), isFalse,
          reason: 'Absent colorHex must not be written to Firestore.');
    });
  });

  // TC101 ───────────────────────────────────────────────────────────────────
  group('TC101: event with externalEventId is preserved in toFirestore', () {
    test('externalEventId appears in map when set', () {
      final event =
          Fixtures.calendarEvent().copyWith(externalEventId: 'google-evt-xyz');
      final map = event.toFirestore();

      expect(map.containsKey('externalEventId'), isTrue);
      expect(map['externalEventId'], 'google-evt-xyz');
    });
  });

  // TC102 ───────────────────────────────────────────────────────────────────
  group('TC102: CalendarEventEntity fromFirestore round-trip', () {
    test('all scalar fields survive toFirestore → fromFirestore', () {
      final original = Fixtures.calendarEvent(
        id: 'rt-event',
        userId: 'user-rt',
        title: 'Round-trip meeting',
        eventType: CalendarEventType.team,
        teamId: 'team-rt',
        assignedMemberIds: ['m1', 'm2'],
      );

      final map = original.toFirestore();
      final restored = CalendarEventEntity.fromFirestore(original.id, map);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.title, original.title);
      expect(restored.eventType, original.eventType);
      expect(restored.teamId, original.teamId);
      expect(restored.assignedMemberIds, containsAll(['m1', 'm2']));
      expect(restored.startAt.toIso8601String(),
          original.startAt.toIso8601String());
    });
  });

  // TC103 ───────────────────────────────────────────────────────────────────
  group('TC103: filter events by eventType', () {
    test('only personal events are returned after filtering', () {
      final events = [
        Fixtures.calendarEvent(id: 'p1', eventType: CalendarEventType.personal),
        Fixtures.calendarEvent(id: 't1', eventType: CalendarEventType.task),
        Fixtures.calendarEvent(id: 'p2', eventType: CalendarEventType.personal),
        Fixtures.calendarEvent(id: 'c1', eventType: CalendarEventType.classSchedule),
      ];

      final personal =
          events.where((e) => e.eventType == CalendarEventType.personal).toList();

      expect(personal.length, 2);
      expect(personal.map((e) => e.id), containsAll(['p1', 'p2']));
    });
  });

  // TC104 ───────────────────────────────────────────────────────────────────
  group('TC104: event with multiple assigned members', () {
    test('all member IDs are preserved after construction', () {
      const members = ['uid-1', 'uid-2', 'uid-3', 'uid-4'];
      final event = Fixtures.calendarEvent(
        eventType: CalendarEventType.team,
        teamId: 'team-big',
        assignedMemberIds: members,
      );

      expect(event.assignedMemberIds.length, 4);
      expect(event.assignedMemberIds, containsAll(members));
    });

    test('assignedMemberIds survives toFirestore round-trip', () {
      const members = ['uid-a', 'uid-b'];
      final event = Fixtures.calendarEvent(assignedMemberIds: members);
      final map = event.toFirestore();

      expect(map['assignedMemberIds'], isA<List>());
      expect(map['assignedMemberIds'], containsAll(members));
    });
  });

  // TC105 ───────────────────────────────────────────────────────────────────
  group('TC105: sourceCollection is preserved via copyWith', () {
    test('copyWith can change sourceCollection to team', () {
      final original = Fixtures.calendarEvent(
        sourceCollection: EventSourceCollection.personal,
      );
      final teamVersion = original.copyWith(
        sourceCollection: EventSourceCollection.team,
      );

      expect(teamVersion.sourceCollection, EventSourceCollection.team);
      expect(original.sourceCollection, EventSourceCollection.personal,
          reason: 'Original entity must not be mutated.');
    });
  });
}
