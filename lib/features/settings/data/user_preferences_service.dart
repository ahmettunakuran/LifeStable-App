import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPreferences {
  final int workStartHour;
  final int workEndHour;
  final int sleepStartHour;
  final int sleepEndHour;
  final int focusBlockMinutes;
  final int breakMinutes;
  final int dailyMaxScheduledMinutes;
  final List<int> acceptedSlotHours;

  const UserPreferences({
    this.workStartHour = 9,
    this.workEndHour = 18,
    this.sleepStartHour = 23,
    this.sleepEndHour = 7,
    this.focusBlockMinutes = 90,
    this.breakMinutes = 15,
    this.dailyMaxScheduledMinutes = 480,
    this.acceptedSlotHours = const [],
  });

  factory UserPreferences.fromMap(Map<String, dynamic> data) {
    return UserPreferences(
      workStartHour: (data['workStartHour'] ?? 9) as int,
      workEndHour: (data['workEndHour'] ?? 18) as int,
      sleepStartHour: (data['sleepStartHour'] ?? 23) as int,
      sleepEndHour: (data['sleepEndHour'] ?? 7) as int,
      focusBlockMinutes: (data['focusBlockMinutes'] ?? 90) as int,
      breakMinutes: (data['breakMinutes'] ?? 15) as int,
      dailyMaxScheduledMinutes: (data['dailyMaxScheduledMinutes'] ?? 480) as int,
      acceptedSlotHours: ((data['acceptedSlotHours'] as List<dynamic>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'workStartHour': workStartHour,
        'workEndHour': workEndHour,
        'sleepStartHour': sleepStartHour,
        'sleepEndHour': sleepEndHour,
        'focusBlockMinutes': focusBlockMinutes,
        'breakMinutes': breakMinutes,
        'dailyMaxScheduledMinutes': dailyMaxScheduledMinutes,
        'acceptedSlotHours': acceptedSlotHours,
      };

  UserPreferences copyWith({
    int? workStartHour,
    int? workEndHour,
    int? sleepStartHour,
    int? sleepEndHour,
    int? focusBlockMinutes,
    int? breakMinutes,
    int? dailyMaxScheduledMinutes,
    List<int>? acceptedSlotHours,
  }) {
    return UserPreferences(
      workStartHour: workStartHour ?? this.workStartHour,
      workEndHour: workEndHour ?? this.workEndHour,
      sleepStartHour: sleepStartHour ?? this.sleepStartHour,
      sleepEndHour: sleepEndHour ?? this.sleepEndHour,
      focusBlockMinutes: focusBlockMinutes ?? this.focusBlockMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      dailyMaxScheduledMinutes: dailyMaxScheduledMinutes ?? this.dailyMaxScheduledMinutes,
      acceptedSlotHours: acceptedSlotHours ?? this.acceptedSlotHours,
    );
  }

  List<int> topPreferredHours({int limit = 3}) {
    if (acceptedSlotHours.isEmpty) return const [];
    final counts = <int, int>{};
    for (final h in acceptedSlotHours) {
      counts[h] = (counts[h] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }
}

class UserPreferencesService {
  static const _maxHistory = 30;

  DocumentReference<Map<String, dynamic>> _ref() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('preferences');
  }

  Future<UserPreferences> load() async {
    try {
      final snap = await _ref().get();
      if (!snap.exists) return const UserPreferences();
      return UserPreferences.fromMap(snap.data() ?? const {});
    } catch (_) {
      return const UserPreferences();
    }
  }

  Stream<UserPreferences> watch() {
    return _ref().snapshots().map((snap) {
      if (!snap.exists) return const UserPreferences();
      return UserPreferences.fromMap(snap.data() ?? const {});
    });
  }

  Future<void> save(UserPreferences prefs) async {
    await _ref().set(prefs.toMap(), SetOptions(merge: true));
  }

  Future<void> recordAcceptedSlot(DateTime startTime) async {
    final current = await load();
    final updated = [...current.acceptedSlotHours, startTime.hour];
    if (updated.length > _maxHistory) {
      updated.removeRange(0, updated.length - _maxHistory);
    }
    await save(current.copyWith(acceptedSlotHours: updated));
  }
}
