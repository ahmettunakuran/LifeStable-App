import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import '../domain/habit_model.dart';
import './widgets/streak_indicator.dart';
import './widgets/completion_chart.dart';
import './widgets/habit_heatmap.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _resettingHabitIds = <String>{};
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _habitChannelId = 'habit_reminders';
  static const _habitChannelName = 'Habit Reminders';

  CollectionReference get _habitsRef {
    final uid = _auth.currentUser?.uid ?? 'guest_user';
    return _db.collection('users').doc(uid).collection('habits');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _domainsStream {
    final uid = _auth.currentUser?.uid ?? 'guest_user';
    return _db.collection('users').doc(uid).collection('domains').snapshots();
  }

  Future<void> _completeHabit(Habit habit) async {
    final today = Habit.normalizeDate(DateTime.now());
    if (habit.completionDates.any((d) => Habit.normalizeDate(d) == today)) {
      return;
    }

    final updatedHabit = habit.copyWith(
      completionDates: [...habit.completionDates, today],
      lastCompleted: DateTime.now(),
    );
    
    final newStreak = Habit.calculateStreak(updatedHabit.completionDates);

    await _habitsRef.doc(habit.id).update(
      updatedHabit.copyWith(streak: newStreak).toFirestore()
    );
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(S.of('new_habit'), style: const TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: S.of('habit_name'),
            labelStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final uid = _auth.currentUser?.uid ?? 'guest_user';
                final newHabit = Habit(
                  id: '', // Firestore will assign
                  name: name,
                  createdAt: DateTime.now(),
                  userId: uid,
                  completionDates: const [],
                );
                await _habitsRef.add(newHabit.toFirestore());
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: Text(S.of('add'), style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(S.of('delete_habit_title'), style: const TextStyle(color: AppColors.gold)),
        content: Text(S.of('delete_habit_confirm', args: {'name': habit.name}), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.of('cancel'))),
          TextButton(
            onPressed: () async {
              await _habitsRef.doc(habit.id).delete();
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(S.of('delete'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gold),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.homeDashboard)),
        title: Text(S.of('habit_tracker'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.gold,
                letterSpacing: 1.5)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              Color(0xFF0D0D0D),
              Color(0xFF1A1200),
              Color(0xFF0D0D0D)
            ])),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              _habitsRef.orderBy('created_at', descending: false).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                  child: Text(S.of('no_habits_yet'),
                      style: const TextStyle(color: Colors.white24, fontSize: 14)));
            }

            final habits =
                snapshot.data!.docs.map((doc) => Habit.fromFirestore(doc)).toList();

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: habits.length,
              itemBuilder: (context, index) => _buildHabitItem(habits[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    final today = Habit.normalizeDate(DateTime.now());
    final isDoneToday = habit.isCompletedToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            habit.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                          onPressed: () => _confirmDelete(habit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    HabitHeatmap(habit: habit),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StreakIndicator(streak: habit.currentStreak),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: isDoneToday ? null : () => _completeHabit(habit),
                    icon: Icon(
                      isDoneToday ? Icons.check_circle : Icons.circle_outlined,
                      color: isDoneToday ? Colors.greenAccent : AppColors.gold,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          CompletionChart(habit: habit),
        ],
      ),
    );
  }
}