import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import 'habit.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _resettingHabitIds = <String>{};
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

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

  String _selectedDomainId = 'health';
  String _selectedDomainName = 'Health';

  Future<void> _scheduleDailyReminder(String habitId, String habitName) async {
    await _notifications.periodicallyShow(
      id: habitId.hashCode,
      title: 'Habit Reminder',
      body: "Don't forget: $habitName",
      repeatInterval: RepeatInterval.daily,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _habitChannelId,
          _habitChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _cancelDailyReminder(String habitId) async {
    await _notifications.cancel(id: habitId.hashCode);
  }

  Future<void> _createHabit({
    required String name,
    required String domainId,
    required String domainName,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'guest_user';
    final docRef = await _habitsRef.add({
      'name': name,
      'domain_id': domainId,
      'domain_name': domainName,
      'streak': 0,
      'last_completed': null,
      'is_paused': false,
      'user_id': uid,
      'created_at': FieldValue.serverTimestamp(),
      'completed_dates': [],
    });
    await _scheduleDailyReminder(docRef.id, name);
  }

  Future<void> _completeHabit(Habit habit) async {
    if (habit.isCompletedToday) return;

    int newStreak;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (habit.lastCompleted == null) {
      newStreak = 1;
    } else {
      final lastDate = DateTime(habit.lastCompleted!.year, habit.lastCompleted!.month, habit.lastCompleted!.day);
      final today = DateTime(now.year, now.month, now.day);
      final daysDifference = today.difference(lastDate).inDays;

      if (daysDifference <= 2) {
        newStreak = habit.streak + 1;
      } else {
        newStreak = 1;
      }
    }

    final updatedDates = [...habit.completedDates, todayStr];
    if (updatedDates.length > 30) {
      updatedDates.removeRange(0, updatedDates.length - 30);
    }

    await _habitsRef.doc(habit.id).update({
      'streak': newStreak,
      'last_completed': FieldValue.serverTimestamp(),
      'completed_dates': updatedDates,
    });
  }

  Future<void> _togglePause(Habit habit) async {
    await _habitsRef.doc(habit.id).update({'is_paused': !habit.isPaused});
  }

  Future<void> _deleteHabit(String habitId) async {
    await _cancelDailyReminder(habitId);
    await _habitsRef.doc(habitId).delete();
  }

  Future<void> _checkAndResetStreaks(List<Habit> habits) async {
    for (final habit in habits) {
      if (habit.isPaused || habit.lastCompleted == null || !habit.shouldResetStreak) continue;
      if (_resettingHabitIds.contains(habit.id)) continue;
      _resettingHabitIds.add(habit.id);
      try {
        await _habitsRef.doc(habit.id).update({'streak': 0});
      } finally {
        _resettingHabitIds.remove(habit.id);
      }
    }
  }

  void _showAddDialog(List<Map<String, String>> domainOptions) {
    if (domainOptions.isEmpty) return;
    final nameController = TextEditingController();
    _selectedDomainId = domainOptions.first['id']!;
    _selectedDomainName = domainOptions.first['name']!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New Habit', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Habit Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gold)),
                  suffixIcon: Tooltip(
                    message: 'Enter a short, actionable habit name.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Link to Domain:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.gold.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDomainId,
                  dropdownColor: AppColors.cardBg,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: AppColors.gold,
                  items: domainOptions.map((d) => DropdownMenuItem(value: d['id'], child: Text(d['name']!, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      _selectedDomainId = value!;
                      _selectedDomainName = domainOptions.firstWhere((d) => d['id'] == value)['name']!;
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createHabit(name: nameController.text.trim(), domainId: _selectedDomainId, domainName: _selectedDomainName);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Habit', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('"${habit.name}" will be deleted. Are you sure?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            onPressed: () {
              _deleteHabit(habit.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPauseInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('⏸ Health Guardrail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold)),
            SizedBox(height: 12),
            Text('Pausing a habit protects your streak during stressful periods.', style: TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.gold), onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.homeDashboard)),
        title: const Text('HABIT TRACKER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.info_outline, color: AppColors.gold), onPressed: () => _showPauseInfo(context))],
      ),
      bottomNavigationBar: _buildBottomNav(context),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)])),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _domainsStream,
          builder: (context, domainsSnapshot) {
            final domainOptions = (domainsSnapshot.data?.docs ?? []).map((doc) => <String, String>{'id': doc.id, 'name': (doc.data()['name'] as String?) ?? 'Unnamed'}).toList(growable: false);
            return Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _habitsRef.orderBy('created_at', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No habits yet.', style: const TextStyle(color: Colors.white24, fontSize: 14)));
                    final habits = snapshot.data!.docs.map((doc) => Habit.fromFirestore(doc)).toList();
                    _checkAndResetStreaks(habits);
                    final Map<String, List<Habit>> groupedHabits = {};
                    for (final habit in habits) groupedHabits.putIfAbsent(habit.domainName, () => []).add(habit);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: groupedHabits.entries.map((entry) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildDomainHeader(entry.key), const SizedBox(height: 8), ...entry.value.map((habit) => _buildHabitCard(habit)), const SizedBox(height: 16)])).toList(),
                    );
                  },
                ),
                Positioned(right: 16, bottom: 16, child: FloatingActionButton(backgroundColor: AppColors.gold, foregroundColor: AppColors.black, elevation: 4, onPressed: domainOptions.isEmpty ? null : () => _showAddDialog(domainOptions), child: const Icon(Icons.add))),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDomainHeader(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
      child: Text(name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    final bool paused = habit.isPaused;
    final bool doneToday = habit.isCompletedToday;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: paused ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: paused ? Colors.white.withOpacity(0.08) : AppColors.gold.withOpacity(0.1))),
      child: Row(
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(paused ? '❄️' : '🔥', style: const TextStyle(fontSize: 20)), Text('${habit.streak}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: paused ? Colors.white38 : AppColors.gold))]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(habit.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: paused ? Colors.white38 : Colors.white, decoration: paused ? TextDecoration.lineThrough : TextDecoration.none, decorationColor: Colors.white38)), const SizedBox(height: 2), Text(doneToday ? '✅ Completed today' : paused ? '⏸ Paused' : 'Tap ✓ to complete today', style: TextStyle(fontSize: 11, color: paused ? Colors.white24 : Colors.white54))])),
          Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.check_circle, size: 22, color: doneToday ? Colors.greenAccent : Colors.white24), onPressed: doneToday || paused ? null : () => _completeHabit(habit)), IconButton(icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 22, color: paused ? AppColors.gold : Colors.white54), onPressed: () => _togglePause(habit)), IconButton(icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent), onPressed: () => _confirmDelete(habit))]),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: AppColors.cardBg, border: Border(top: BorderSide(color: AppColors.gold.withOpacity(0.1)))),
      child: SafeArea(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_navBtn(context, Icons.group_outlined, 'Team', AppRoutes.teamDashboard), _navBtn(context, Icons.calendar_month_outlined, 'Calendar', AppRoutes.calendar), _navBtn(context, Icons.dashboard_outlined, 'Dashboard', AppRoutes.homeDashboard), _navBtn(context, Icons.local_fire_department_outlined, 'Habit', AppRoutes.habitTracker, active: true)])),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, String label, String route, {bool active = false}) {
    return GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, route), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? AppColors.gold : AppColors.gold.withOpacity(0.45), size: 22), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? AppColors.gold : Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600))]));
  }
}