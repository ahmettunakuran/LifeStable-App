import 'package:cloud_firestore/cloud_firestore.dart';
// Imports Firestore package for Timestamp and DocumentSnapshot usage

class Habit {
  final String id;          // Unique Firestore document ID
  final String name;        // Habit name (e.g. Drink Water, Daily Study)
  final String domainId;    // ID of the domain this habit is linked to
  final String domainName;  // Name of the linked domain (e.g. Health, School)
  final int streak;         // Current consecutive completion streak count
  final DateTime? lastCompleted; // Last time the habit was marked as complete
  final bool isPaused;      // Whether the habit is paused (health guardrail)
  final String userId;      // ID of the user who owns this habit
  final DateTime createdAt; // When the habit was first created

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
  });

  // Converts a Firestore document snapshot into a Habit object
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Habit(
      id: doc.id,
      name: data['name'] ?? '',
      domainId: data['domain_id'] ?? '',
      domainName: data['domain_name'] ?? '',
      streak: data['streak'] ?? 0,
      // last_completed can be null if habit was never completed
      lastCompleted: data['last_completed'] != null
          ? (data['last_completed'] as Timestamp).toDate()
          : null,
      isPaused: data['is_paused'] ?? false,
      userId: data['user_id'] ?? '',
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Converts the Habit object into a Map to save to Firestore
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
    };
  }

  // Checks if the habit has already been completed today
  bool get isCompletedToday {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    return lastCompleted!.year == now.year &&
        lastCompleted!.month == now.month &&
        lastCompleted!.day == now.day;
  }

  // Checks if the streak should be reset
  // Reset logic: if more than 2 days passed since last completion, reset to 0
  bool get shouldResetStreak {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastCompleted!).inDays;
    return difference > 2;
  }
}