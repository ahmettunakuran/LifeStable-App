import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'habit.dart';

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns Firestore reference to current user's habits collection
  CollectionReference get _habitsRef {
    final uid = _auth.currentUser?.uid ?? 'guest_user';
    return _db.collection('users').doc(uid).collection('habits');
  }

  final List<Map<String, String>> _domainOptions = [
    {'id': 'health',   'name': 'Health'},
    {'id': 'school',   'name': 'School'},
    {'id': 'work',     'name': 'Work'},
    {'id': 'sport',    'name': 'Sport'},
    {'id': 'personal', 'name': 'Personal'},
  ];

  String _selectedDomainId   = 'health';
  String _selectedDomainName = 'Health';

  // CREATE
  Future<void> _createHabit({
    required String name,
    required String domainId,
    required String domainName,
  }) async {
    final uid = _auth.currentUser?.uid ?? 'guest_user';
    await _habitsRef.add({
      'name': name,
      'domain_id': domainId,
      'domain_name': domainName,
      'streak': 0,
      'last_completed': null,
      'is_paused': false,
      'user_id': uid,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // COMPLETE — Calendar-day based streak calculation
  Future<void> _completeHabit(Habit habit) async {
    if (habit.isCompletedToday) return;

    int newStreak;

    if (habit.lastCompleted == null) {
      // First completion ever
      newStreak = 1;
    } else {
      final now = DateTime.now();

      // Strip time — compare only calendar days (e.g. Mar 13 vs Mar 14)
      final lastDate = DateTime(
        habit.lastCompleted!.year,
        habit.lastCompleted!.month,
        habit.lastCompleted!.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final daysDifference = today.difference(lastDate).inDays;

      if (daysDifference == 1) {
        // Completed yesterday → increment streak
        newStreak = habit.streak + 1;
      } else if (daysDifference > 2) {
        // Missed more than 2 days → reset streak to 1
        newStreak = 1;
      } else {
        // Same calendar day → no change
        newStreak = habit.streak;
      }
    }

    await _habitsRef.doc(habit.id).update({
      'streak': newStreak,
      'last_completed': FieldValue.serverTimestamp(),
    });
  }

  // PAUSE / RESUME — Health guardrail
  Future<void> _togglePause(Habit habit) async {
    await _habitsRef.doc(habit.id).update({
      'is_paused': !habit.isPaused,
    });
  }

  // DELETE
  Future<void> _deleteHabit(String habitId) async {
    await _habitsRef.doc(habitId).delete();
  }

  // Checks and resets streak if inactive for more than 2 days
  Future<void> _checkAndResetStreak(Habit habit) async {
    if (habit.isPaused) return;
    if (habit.lastCompleted == null) return;
    if (!habit.shouldResetStreak) return;

    await _habitsRef.doc(habit.id).update({'streak': 0});
  }

  // ADD HABIT DIALOG
  void _showAddDialog() {
    final nameController = TextEditingController();
    _selectedDomainId   = 'health';
    _selectedDomainName = 'Health';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('New Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Habit Name',
                  // Tooltip instead of hintText — keeps UI clean and professional
                  suffixIcon: Tooltip(
                    message:
                    'Enter a short, actionable habit name.\n'
                        'Examples: Drink Water, Read 10 Pages, Morning Walk',
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Link to Domain:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedDomainId,
                items: _domainOptions.map((d) {
                  return DropdownMenuItem(
                    value: d['id'],
                    child: Text(d['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setStateDialog(() {
                    _selectedDomainId   = value!;
                    _selectedDomainName = _domainOptions
                        .firstWhere((d) => d['id'] == value)['name']!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createHabit(
                    name: nameController.text.trim(),
                    domainId: _selectedDomainId,
                    domainName: _selectedDomainName,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // DELETE CONFIRMATION DIALOG
  void _confirmDelete(Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('"${habit.name}" will be deleted. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteHabit(habit.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // HEALTH GUARDRAIL INFO SHEET
  void _showPauseInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '⏸ Health Guardrail',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Pausing a habit protects your streak during stressful periods '
                  'like exam weeks or vacations. While paused, missing a day '
                  'will NOT reset your streak. Resume when you are ready!',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showPauseInfo(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _habitsRef
            .orderBy('created_at', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No habits yet. Tap + to add one!'),
            );
          }

          final habits = snapshot.data!.docs
              .map((doc) => Habit.fromFirestore(doc))
              .toList();

          final Map<String, List<Habit>> groupedHabits = {};
          for (final habit in habits) {
            _checkAndResetStreak(habit);
            groupedHabits
                .putIfAbsent(habit.domainName, () => [])
                .add(habit);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: groupedHabits.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  ...entry.value.map((habit) => _buildHabitCard(habit)),
                  const Divider(),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: habit.isPaused ? Colors.grey.shade200 : null,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              habit.isPaused ? '❄️' : '🔥',
              style: const TextStyle(fontSize: 20),
            ),
            Text(
              '${habit.streak}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: habit.isPaused
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          habit.isCompletedToday
              ? '✅ Completed today'
              : habit.isPaused
              ? '⏸ Paused — streak is protected'
              : 'Tap ✓ to complete today',
          style: TextStyle(
            color: habit.isPaused ? Colors.grey : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.check_circle,
                color: habit.isCompletedToday ? Colors.green : Colors.grey,
              ),
              onPressed: habit.isCompletedToday || habit.isPaused
                  ? null
                  : () => _completeHabit(habit),
            ),
            IconButton(
              icon: Icon(
                habit.isPaused ? Icons.play_arrow : Icons.pause,
                color: habit.isPaused ? Colors.blue : Colors.orange,
              ),
              onPressed: () => _togglePause(habit),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _confirmDelete(habit),
            ),
          ],
        ),
      ),
    );
  }
}

