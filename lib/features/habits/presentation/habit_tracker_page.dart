import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
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
          title: Text(S.of('new_habit'), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: S.of('habit_name_label'),
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gold)),
                  suffixIcon: Tooltip(
                    message: S.of('enter_habit_name_tooltip'),
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Text(S.of('link_to_domain_label'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.of('cancel'), style: const TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createHabit(name: nameController.text.trim(), domainId: _selectedDomainId, domainName: _selectedDomainName);
                  Navigator.pop(ctx);
                }
              },
              child: Text(S.of('create_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(S.of('delete_habit_title'), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          S.of('delete_habit_body').replaceAll('{name}', habit.name),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.of('cancel'), style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            onPressed: () {
              _deleteHabit(habit.id);
              Navigator.pop(ctx);
            },
            child: Text(S.of('delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
          children: [
            Text(S.of('health_guardrail'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.gold)),
            const SizedBox(height: 12),
            Text(S.of('pause_habit_instructions'), style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.gold),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.homeDashboard);
                }
              },
            ),
            title: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
              ).createShader(b),
              child: Text(
                S.of('habits'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => _showPauseInfo(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(context),
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)])),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _domainsStream,
              builder: (context, domainsSnapshot) {
                final domainDocs = domainsSnapshot.data?.docs ?? [];
                final domainOptions = domainDocs
                    .map((doc) => <String, String>{
                          'id': doc.id,
                          'name': (doc.data()['name'] as String?) ?? 'Unnamed',
                        })
                    .toList(growable: false);
                final Map<String, Color> domainColors = {};
                for (final doc in domainDocs) {
                  final hex = doc.data()['colorHex'] as String?;
                  if (hex != null) {
                    try {
                      domainColors[doc.id] = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                    } catch (_) {}
                  }
                }
                return Stack(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _habitsRef.orderBy('created_at', descending: false).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                        }
                        final habits = (snapshot.data?.docs ?? [])
                            .map((doc) => Habit.fromFirestore(doc))
                            .toList();
                        _checkAndResetStreaks(habits);
                        final doneToday = habits.where((h) => h.isCompletedToday).length;
                        final ordered = [
                          ...habits.where((h) => !h.isPaused),
                          ...habits.where((h) => h.isPaused),
                        ];
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          children: [
                            _buildStreakCard(habits, doneToday),
                            const SizedBox(height: 22),
                            if (habits.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Center(
                                  child: Text(S.of('no_habits_yet'),
                                      style: const TextStyle(color: Colors.white24, fontSize: 14)),
                                ),
                              )
                            else ...[
                              _buildSectionHeader(doneToday, habits.length),
                              const SizedBox(height: 14),
                              ...ordered.map((h) => _buildHabitCard(h, domainColors[h.domainId])),
                            ],
                          ],
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
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildSectionHeader(int done, int total) {
    return Text(
      S.of('today_habits_completed').replaceAll('{done}', '$done').replaceAll('{total}', '$total'),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStreakCard(List<Habit> habits, int doneToday) {
    final int maxStreak =
        habits.fold<int>(0, (best, h) => h.streak > best ? h.streak : best);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
                      ).createShader(b),
                      child: Text(
                        S.of('current_streak_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$maxStreak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          S.of('days'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      S.of('done_today_streak_subtitle').replaceAll('{done}', '$doneToday').replaceAll('{total}', '${habits.length}'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.local_fire_department, color: AppColors.gold, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            S.of('last_30_days'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _build30DayGrid(habits),
        ],
      ),
    );
  }

  Widget _build30DayGrid(List<Habit> habits) {
    final now = DateTime.now();
    final activeHabits = habits.where((h) => !h.isPaused).toList();
    final total = activeHabits.length;
    final List<Widget> squares = [];
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: 29 - i));
      final key = _dateKey(d);
      final count =
          activeHabits.where((h) => h.completedDates.contains(key)).length;
      final ratio = total == 0 ? 0.0 : count / total;
      final Color c = ratio <= 0
          ? Colors.white.withValues(alpha: 0.05)
          : AppColors.gold.withValues(alpha: 0.25 + 0.7 * ratio.clamp(0.0, 1.0));
      squares.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(children: squares.sublist(0, 15)),
        const SizedBox(height: 4),
        Row(children: squares.sublist(15, 30)),
      ],
    );
  }

  Widget _buildHabitCard(Habit habit, Color? domainColor) {
    final bool paused = habit.isPaused;
    final bool done = habit.isCompletedToday;
    final Color dotColor = domainColor ?? AppColors.gold;
    final now = DateTime.now();
    int weekDone = 0;
    for (int i = 0; i < 7; i++) {
      if (habit.completedDates.contains(_dateKey(now.subtract(Duration(days: i))))) {
        weekDone++;
      }
    }

    return GestureDetector(
      onLongPress: () => _showHabitOptions(habit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: paused ? 0.03 : 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: paused ? Colors.white.withValues(alpha: 0.07) : AppColors.gold.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildHabitIcon(habit, paused),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: paused ? Colors.white24 : dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              habit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: (paused || done) ? Colors.white38 : Colors.white,
                                decoration:
                                    done ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        paused
                            ? '${habit.domainName} · ${S.of('paused_suffix')}'
                            : (habit.domainName.isEmpty ? S.of('daily') : habit.domainName),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showHabitOptions(habit),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_vert,
                        color: Colors.white.withValues(alpha: 0.45), size: 20),
                  ),
                ),
                const SizedBox(width: 4),
                _buildHabitAction(habit, paused, done),
              ],
            ),
            if (!paused) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: weekDone / 7,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  color: AppColors.gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHabitIcon(Habit habit, bool paused) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: paused ? Colors.white.withValues(alpha: 0.04) : AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: paused ? 0.08 : 0.25)),
          ),
          child: Icon(
            paused ? Icons.pause_rounded : Icons.local_fire_department,
            color: paused ? Colors.white24 : AppColors.gold,
            size: 24,
          ),
        ),
        if (!paused)
          Positioned(
            bottom: -6,
            left: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: Text(
                '${habit.streak}',
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHabitAction(Habit habit, bool paused, bool done) {
    if (paused) {
      return _actionBox(Icons.play_arrow_rounded, AppColors.gold,
          onTap: () => _togglePause(habit));
    }
    if (done) {
      return _actionBox(Icons.check_rounded, Colors.greenAccent);
    }
    return _actionBox(Icons.check_rounded, AppColors.gold,
        onTap: () => _completeHabit(habit));
  }

  Widget _actionBox(IconData icon, Color color, {VoidCallback? onTap}) {
    final box = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }

  void _showHabitOptions(Habit habit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  habit.name,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                habit.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: AppColors.gold,
              ),
              title: Text(
                habit.isPaused ? S.of('resume') : S.of('pause'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _togglePause(habit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: Text(S.of('delete'), style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(habit);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: AppColors.cardBg, border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.1)))),
      child: SafeArea(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_navBtn(context, Icons.group_outlined, S.of('nav_team'), AppRoutes.teamDashboard), _navBtn(context, Icons.calendar_month_outlined, S.of('nav_calendar'), AppRoutes.calendar), _navBtn(context, Icons.dashboard_outlined, S.of('nav_dashboard'), AppRoutes.homeDashboard), _navBtn(context, Icons.local_fire_department_outlined, S.of('nav_habit'), AppRoutes.habitTracker, active: true)])),
    );
  }

  Widget _navBtn(BuildContext context, IconData icon, String label, String route, {bool active = false}) {
    return GestureDetector(onTap: () => Navigator.pushReplacementNamed(context, route), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? AppColors.gold : AppColors.gold.withValues(alpha: 0.45), size: 22), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600))]));
  }
}