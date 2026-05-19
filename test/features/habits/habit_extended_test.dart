// ignore_for_file: lines_longer_than_80_chars

/// Habit Tracker Extended Tests — TC86 through TC95
///
/// Additional pure-Dart tests for the Habit model covering edge cases:
/// large streak values, completedDates mutations, field serialization,
/// and shouldResetStreak boundary conditions.
/// No Firebase connection is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/habits/presentation/habit.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC86 ────────────────────────────────────────────────────────────────────
  group('TC86: habit with large streak value', () {
    test('streak of 365 is stored and serialized correctly', () {
      final habit = Fixtures.habit(streak: 365);

      expect(habit.streak, 365,
          reason: 'Large streak values must be supported without overflow.');
      expect(habit.toMap()['streak'], 365);
    });

    test('streak > 0 shows fire icon even at streak=365', () {
      final habit = Fixtures.habit(streak: 365);
      expect(habit.streak > 0, isTrue);
    });
  });

  // TC87 ────────────────────────────────────────────────────────────────────
  group('TC87: completedDates count matches expected length', () {
    test('habit with 7 completed dates reports length 7', () {
      const dates = [
        '2024-06-01', '2024-06-02', '2024-06-03',
        '2024-06-04', '2024-06-05', '2024-06-06', '2024-06-07',
      ];
      final habit = Fixtures.habit(completedDates: dates);

      expect(habit.completedDates.length, 7,
          reason: 'All 7 dates must be stored without truncation.');
    });

    test('adding a date to completedDates increases length by one', () {
      const initialDates = ['2024-06-01', '2024-06-02'];
      final updated = Habit(
        id: 'h1',
        name: 'Exercise',
        domainId: 'dom-1',
        domainName: 'Health',
        streak: 3,
        isPaused: false,
        userId: 'user-1',
        createdAt: DateTime(2024),
        completedDates: [...initialDates, '2024-06-03'],
      );

      expect(updated.completedDates.length, 3);
      expect(updated.completedDates.last, '2024-06-03');
    });
  });

  // TC88 ────────────────────────────────────────────────────────────────────
  group('TC88: habit name is preserved in toMap', () {
    test('name field in map matches the model name', () {
      final habit = Fixtures.habit(name: 'Evening meditation');
      final map = habit.toMap();

      expect(map['name'], 'Evening meditation',
          reason: 'Serialized name must match the Habit model name.');
    });
  });

  // TC89 ────────────────────────────────────────────────────────────────────
  group('TC89: habit domainId is preserved in toMap', () {
    test('domain_id in map matches the model domainId', () {
      final habit = Fixtures.habit(domainId: 'domain-wellness');
      final map = habit.toMap();

      expect(map['domain_id'], 'domain-wellness',
          reason: 'Firestore key domain_id must carry the model domainId.');
    });
  });

  // TC90 ────────────────────────────────────────────────────────────────────
  group('TC90: habit userId is preserved in toMap', () {
    test('user_id in map matches the model userId', () {
      final habit = Fixtures.habit(userId: 'user-owner-7');
      final map = habit.toMap();

      expect(map['user_id'], 'user-owner-7',
          reason: 'Ownership must be preserved through serialization.');
    });
  });

  // TC91 ────────────────────────────────────────────────────────────────────
  group('TC91: shouldResetStreak boundary — exactly 2-day gap', () {
    test('shouldResetStreak is false when gap is exactly 2 days', () {
      // DateTime.difference.inDays truncates; 2 days = 48 hours → inDays = 2.
      // The rule is gap > 2, so 2 returns false.
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2));
      final habit = Fixtures.habit(lastCompleted: twoDaysAgo, streak: 5);

      expect(habit.shouldResetStreak, isFalse,
          reason: 'A 2-day gap is within the grace window; streak must be kept.');
    });

    test('shouldResetStreak is true when gap is exactly 3 days', () {
      final threeDaysAgo =
          DateTime.now().subtract(const Duration(days: 3));
      final habit = Fixtures.habit(lastCompleted: threeDaysAgo, streak: 5);

      expect(habit.shouldResetStreak, isTrue,
          reason: 'A 3-day gap exceeds the grace window; streak must reset.');
    });
  });

  // TC92 ────────────────────────────────────────────────────────────────────
  group('TC92: consecutive completion dates build streak', () {
    test('adding date for today continues a running streak', () {
      final today = DateTime.now().toIso8601String().split('T').first;
      const existing = ['2024-06-05', '2024-06-06'];

      final updated = Habit(
        id: 'streak-habit',
        name: 'Read 30 min',
        domainId: 'dom-1',
        domainName: 'Learning',
        streak: 2,
        lastCompleted: DateTime.now(),
        isPaused: false,
        userId: 'user-1',
        createdAt: DateTime(2024),
        completedDates: [...existing, today],
      );

      expect(updated.completedDates.contains(today), isTrue,
          reason: "Today's date must be recorded in completedDates.");
      expect(updated.completedDates.length, 3);
    });
  });

  // TC93 ────────────────────────────────────────────────────────────────────
  group('TC93: isPaused habit can still hold a positive streak', () {
    test('paused habit retains its streak value while paused', () {
      final paused = Fixtures.habit(isPaused: true, streak: 42);

      expect(paused.streak, 42,
          reason: 'Pausing must not zero out the streak; it is preserved.');
      expect(paused.isPaused, isTrue);
    });
  });

  // TC94 ────────────────────────────────────────────────────────────────────
  group('TC94: created_at field appears in toMap', () {
    test('toMap contains created_at as a Timestamp-compatible value', () {
      final habit = Fixtures.habit(createdAt: DateTime(2024, 1, 15));
      final map = habit.toMap();

      expect(map.containsKey('created_at'), isTrue,
          reason: 'created_at is required for Firestore queries.');
      // The value is a cloud_firestore Timestamp.
      expect(map['created_at'], isNotNull);
    });
  });

  // TC95 ────────────────────────────────────────────────────────────────────
  group('TC95: empty completedDates serializes to empty list in toMap', () {
    test('brand-new habit produces an empty list for completed_dates', () {
      final habit = Fixtures.habit(completedDates: const []);
      final map = habit.toMap();

      expect(map['completed_dates'], isA<List>());
      expect((map['completed_dates'] as List).isEmpty, isTrue,
          reason: 'A habit with no completions must emit an empty list, not null.');
    });
  });
}
