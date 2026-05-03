import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String name;
  final String domainId;
  final String domainName;
  final int streak;
  final DateTime? lastCompleted;
  final bool isPaused;
  final String userId;
  final DateTime createdAt;
  final List<String> completedDates;

  Habit({
    required this.id,
    required this.name,
    required this.domainId,
    required this.domainName,
    required this.streak,
    this.lastCompleted,
    required this.isPaused,
    required this.userId,
    required this.createdAt,
    this.completedDates = const [],
  });

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      domainId: data['domain_id'] ?? '',
      domainName: data['domain_name'] ?? '',
      streak: data['streak'] ?? 0,
      lastCompleted: data['last_completed'] != null
          ? (data['last_completed'] as Timestamp).toDate()
          : null,
      isPaused: data['is_paused'] ?? false,
      userId: data['user_id'] ?? '',
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      completedDates: (data['completed_dates'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'domain_id': domainId,
      'domain_name': domainName,
      'streak': streak,
      'last_completed': lastCompleted != null
          ? Timestamp.fromDate(lastCompleted!)
          : null,
      'is_paused': isPaused,
      'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
      'completed_dates': completedDates,
    };
  }

  bool get isCompletedToday {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    return lastCompleted!.year == now.year &&
        lastCompleted!.month == now.month &&
        lastCompleted!.day == now.day;
  }

  bool get shouldResetStreak {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastCompleted!).inDays;
    return difference > 2;
  }
}
