import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Habit extends Equatable {
  final String id;
  final String name;
  final String domainId;
  final String domainName;
  final bool isPaused;
  final List<DateTime> completionDates;
  final DateTime createdAt;
  final DateTime? lastCompleted;
  final int streak;
  final String userId;

  const Habit({
    required this.id,
    required this.name,
    this.domainId = '',
    this.domainName = '',
    this.isPaused = false,
    this.completionDates = const [],
    required this.createdAt,
    this.lastCompleted,
    this.streak = 0,
    this.userId = '',
  });

  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final completionStrings = (data['completed_dates'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      domainId: data['domain_id'] ?? '',
      domainName: data['domain_name'] ?? '',
      isPaused: data['is_paused'] ?? false,
      completionDates: completionStrings.map((s) => DateTime.parse(s)).toList(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastCompleted: (data['last_completed'] as Timestamp?)?.toDate(),
      streak: data['streak'] ?? 0,
      userId: data['user_id'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'domain_id': domainId,
      'domain_name': domainName,
      'is_paused': isPaused,
      'completed_dates': completionDates
          .map((d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
          .toList(),
      'created_at': Timestamp.fromDate(createdAt),
      'last_completed': lastCompleted != null ? Timestamp.fromDate(lastCompleted!) : null,
      'streak': streak,
      'user_id': userId,
    };
  }

  Habit copyWith({
    String? id,
    String? name,
    String? domainId,
    String? domainName,
    bool? isPaused,
    List<DateTime>? completionDates,
    DateTime? createdAt,
    DateTime? lastCompleted,
    int? streak,
    String? userId,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      domainId: domainId ?? this.domainId,
      domainName: domainName ?? this.domainName,
      isPaused: isPaused ?? this.isPaused,
      completionDates: completionDates ?? this.completionDates,
      createdAt: createdAt ?? this.createdAt,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      streak: streak ?? this.streak,
      userId: userId ?? this.userId,
    );
  }

  int get currentStreak => calculateStreak(completionDates);

  bool get isCompletedToday {
    final today = normalizeDate(DateTime.now());
    return completionDates.any((d) => normalizeDate(d) == today);
  }

  static int calculateStreak(List<DateTime> dates, {bool allowGracePeriod = true}) {
    if (dates.isEmpty) return 0;

    final sortedDates = dates
        .map(normalizeDate)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = normalizeDate(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (sortedDates.first.isBefore(yesterday)) {
      if (!allowGracePeriod ||
          sortedDates.first.isBefore(yesterday.subtract(const Duration(days: 1)))) {
        return 0;
      }
    }

    int streak = 0;
    DateTime checkDate = sortedDates.first;

    for (int i = 0; i < sortedDates.length; i++) {
      if (i == 0) {
        streak = 1;
        continue;
      }

      final expected = checkDate.subtract(const Duration(days: 1));
      if (sortedDates[i] == expected) {
        streak++;
        checkDate = expected;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        domainId,
        domainName,
        isPaused,
        completionDates,
        createdAt,
        lastCompleted,
        streak,
        userId,
      ];
}
