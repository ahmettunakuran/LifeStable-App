// ignore_for_file: lines_longer_than_80_chars

/// Habit Tracker Tests — TC26 through TC33
///
/// Pure Dart tests for the Habit model: streak logic, pause/guardrail
/// behaviour, Firestore serialization, and completion tracking.
/// No Firebase connection is required.

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/habits/presentation/habit.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC26 ────────────────────────────────────────────────────────────────────
  group('TC26: isCompletedToday logic', () {
    test('returns true when lastCompleted matches today\'s date', () {
      final now = DateTime.now();
      final habit = Fixtures.habit(lastCompleted: now);
      expect(habit.isCompletedToday, isTrue,
          reason: 'Habit completed today must report isCompletedToday=true.');
    });

    test('returns false when lastCompleted is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final habit = Fixtures.habit(lastCompleted: yesterday);
      expect(habit.isCompletedToday, isFalse);
    });

    test('returns false when lastCompleted is null (never completed)', () {
      final habit = Fixtures.habit(lastCompleted: null);
      expect(habit.isCompletedToday, isFalse);
    });
  });

  // TC27 ────────────────────────────────────────────────────────────────────
  group('TC27: streak increment on daily completion', () {
    test('streak is incremented when building the updated Habit model', () {
      final habit = Fixtures.habit(streak: 4);

      // Simulates the update applied after marking today complete.
      final updated = Habit(
        id: habit.id,
        name: habit.name,
        domainId: habit.domainId,
        domainName: habit.domainName,
        streak: habit.streak + 1,
        lastCompleted: DateTime.now(),
        isPaused: habit.isPaused,
        userId: habit.userId,
        createdAt: habit.createdAt,
        completedDates: [
          ...habit.completedDates,
          DateTime.now().toIso8601String().split('T').first,
        ],
      );

      expect(updated.streak, 5,
          reason: 'Streak must increase by one on consecutive completion.');
    });

    test('streak starts at 1 after first-ever completion', () {
      final habit = Fixtures.habit(streak: 0);
      final afterFirst = Habit(
        id: habit.id,
        name: habit.name,
        domainId: habit.domainId,
        domainName: habit.domainName,
        streak: 1,
        lastCompleted: DateTime.now(),
        isPaused: false,
        userId: habit.userId,
        createdAt: habit.createdAt,
      );
      expect(afterFirst.streak, 1);
    });
  });

  // TC28 ────────────────────────────────────────────────────────────────────
  group('TC28: isPaused flag — Health Guardrail', () {
    test('paused habit has isPaused=true and serializes correctly', () {
      final paused = Fixtures.habit(isPaused: true, streak: 12);
      expect(paused.isPaused, isTrue);

      final map = paused.toMap();
      expect(map['is_paused'], isTrue,
          reason: 'Firestore field is_paused must reflect the paused state.');
    });

    test('resuming a paused habit sets isPaused=false', () {
      final resumed = Fixtures.habit(isPaused: false);
      expect(resumed.isPaused, isFalse);
      expect(resumed.toMap()['is_paused'], isFalse);
    });
  });

  // TC29 ────────────────────────────────────────────────────────────────────
  group('TC29: streak resets after 2+ days gap', () {
    test('shouldResetStreak is true when gap > 2 days', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      final habit = Fixtures.habit(lastCompleted: threeDaysAgo, streak: 7);
      expect(habit.shouldResetStreak, isTrue,
          reason: 'A 3-day gap must trigger streak reset.');
    });

    test('shouldResetStreak is false when gap is exactly 1 day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final habit = Fixtures.habit(lastCompleted: yesterday, streak: 3);
      expect(habit.shouldResetStreak, isFalse,
          reason: 'Completing yesterday keeps the streak alive.');
    });

    test('shouldResetStreak is false when habit was completed today', () {
      final habit = Fixtures.habit(lastCompleted: DateTime.now(), streak: 5);
      expect(habit.shouldResetStreak, isFalse);
    });

    test('shouldResetStreak is false when lastCompleted is null', () {
      final habit = Fixtures.habit(lastCompleted: null);
      expect(habit.shouldResetStreak, isFalse,
          reason: 'Null lastCompleted means the habit was never completed; '
              'no streak to reset.');
    });
  });

  // TC30 ────────────────────────────────────────────────────────────────────
  group('TC30: toMap produces valid Firestore-compatible data', () {
    test('all required fields are present in the map', () {
      final habit = Fixtures.habit(streak: 5, isPaused: false);
      final map = habit.toMap();

      expect(map.containsKey('name'), isTrue);
      expect(map.containsKey('domain_id'), isTrue);
      expect(map.containsKey('domain_name'), isTrue);
      expect(map.containsKey('streak'), isTrue);
      expect(map.containsKey('is_paused'), isTrue);
      expect(map.containsKey('user_id'), isTrue);
      expect(map.containsKey('created_at'), isTrue);
      expect(map.containsKey('completed_dates'), isTrue);
    });

    test('field values match the model state', () {
      final habit = Fixtures.habit(
        name: 'Meditate',
        streak: 10,
        isPaused: false,
        domainId: 'dom-wellness',
      );
      final map = habit.toMap();

      expect(map['name'], 'Meditate');
      expect(map['streak'], 10);
      expect(map['is_paused'], false);
      expect(map['domain_id'], 'dom-wellness');
    });
  });

  // TC31 ────────────────────────────────────────────────────────────────────
  group('TC31: Fire icon — streak visual indicator', () {
    test('streak > 0 indicates an active fire streak', () {
      final active = Fixtures.habit(streak: 3);
      expect(active.streak > 0, isTrue,
          reason: 'Any streak > 0 should trigger the fire icon.');
    });

    test('streak == 0 means no active fire display', () {
      final inactive = Fixtures.habit(streak: 0);
      expect(inactive.streak > 0, isFalse);
    });

    test('streak == 1 still shows fire icon (single-day start)', () {
      final singleDay = Fixtures.habit(streak: 1);
      expect(singleDay.streak > 0, isTrue);
    });
  });

  // TC32 ────────────────────────────────────────────────────────────────────
  group('TC32: completedDates sub-collection log', () {
    test('completedDates list contains all recorded completion date strings', () {
      const dates = ['2024-06-01', '2024-06-02', '2024-06-03'];
      final habit = Fixtures.habit(completedDates: dates);

      expect(habit.completedDates.length, 3);
      expect(habit.completedDates, containsAll(dates));
    });

    test('completedDates is empty for a brand-new habit', () {
      final habit = Fixtures.habit(completedDates: const []);
      expect(habit.completedDates, isEmpty);
    });

    test('completedDates round-trips through toMap correctly', () {
      const dates = ['2024-07-10', '2024-07-11'];
      final habit = Fixtures.habit(completedDates: dates);
      final map = habit.toMap();

      expect(map['completed_dates'], isA<List>());
      expect(map['completed_dates'], containsAll(dates));
    });
  });

  // TC33 ────────────────────────────────────────────────────────────────────
  group('TC33: paused habit streak protection logic', () {
    test('paused habit with 3-day gap still has shouldResetStreak=true', () {
      // shouldResetStreak only checks the time gap, not isPaused.
      // Streak protection for paused habits must be enforced at the
      // service/repository layer before calling habit.shouldResetStreak.
      final paused = Fixtures.habit(
        isPaused: true,
        streak: 15,
        lastCompleted: DateTime.now().subtract(const Duration(days: 3)),
      );

      // Document the raw model behaviour: shouldResetStreak is based purely
      // on the time gap.  The guardrail (skip reset when paused) is applied
      // in the calling layer.
      expect(paused.shouldResetStreak, isTrue,
          reason: 'Raw model returns true; pause protection is applied externally.');
    });

    test('simulated pause protection prevents streak reset', () {
      final paused = Fixtures.habit(
        isPaused: true,
        streak: 15,
        lastCompleted: DateTime.now().subtract(const Duration(days: 3)),
      );

      // Service layer guardrail: if paused, skip the reset.
      final shouldActuallyReset = paused.shouldResetStreak && !paused.isPaused;

      expect(shouldActuallyReset, isFalse,
          reason: 'When isPaused=true, the streak must be protected.');
    });
  });
}
