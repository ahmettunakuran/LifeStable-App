import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'habit.dart';
// Imports Habit model for type usage throughout this file

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  // Firestore and Auth instances for database operations
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Returns Firestore reference to current user's habits collection
  // Path: users → {userId} → habits
  CollectionReference get _habitsRef {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('habits');
  }

  // Available domain options for linking habits
  // In the future this can be fetched dynamically from Firestore domains collection
  final List<Map<String, String>> _domainOptions = [
    {'id': 'health',  'name': 'Health'},
    {'id': 'school',  'name': 'School'},
    {'id': 'work',    'name': 'Work'},
    {'id': 'sport',   'name': 'Sport'},
    {'id': 'personal','name': 'Personal'},
  ];

  // Tracks which domain is selected in the add/edit dialog
  String _selectedDomainId = 'health';
  String _selectedDomainName = 'Health';

  // CREATE — Adds a new habit linked to a domain
  Future<void> _createHabit({
    required String name,
    required String domainId,
    required String domainName,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _habitsRef.add({
      'name': name,
      'domain_id': domainId,
      'domain_name': domainName,
      'streak': 0,
      // New habits start with no completions
      'last_completed': null,
      'is_paused': false,
      'user_id': uid,
      // Uses Firebase server time for reliability
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // COMPLETE — Marks a habit as done today and updates streak
  // This is the core streak calculation logic
  Future<void> _completeHabit(Habit habit) async {
    // Prevent completing an already completed habit today
    if (habit.isCompletedToday) return;

    int newStreak;

    if (habit.lastCompleted == null) {
      // First time completing this habit, streak starts at 1
      newStreak = 1;
    } else {
      final now = DateTime.now();
      final daysDifference = now.difference(habit.lastCompleted!).inDays;

      if (daysDifference == 1) {
        // Completed yesterday, increment streak by 1
        newStreak = habit.streak + 1;
      } else if (daysDifference > 2) {
        // Missed more than 2 days, reset streak to 1
        // Reset logic: streak resets to 1 (not 0) because completing today counts
        newStreak = 1;
      } else {
        // Completed within the same day window, keep streak
        newStreak = habit.streak;
      }
    }

    await _habitsRef.doc(habit.id).update({
      'streak': newStreak,
      // Records the exact time of completion
      'last_completed': FieldValue.serverTimestamp(),
    });
  }

  // PAUSE/RESUME — Health guardrail to pause habit during stress periods
  // This prevents streak anxiety during exam weeks or high stress times
  Future<void> _togglePause(Habit habit) async {
    await _habitsRef.doc(habit.id).update({
      'is_paused': !habit.isPaused,
    });
  }

  // DELETE — Permanently removes a habit from Firestore
  Future<void> _deleteHabit(String habitId) async {
    await _habitsRef.doc(habitId).delete();
  }

  // Checks and resets streak if user has been inactive for more than 2 days
  // This is called when the habit list is loaded
  Future<void> _checkAndResetStreak(Habit habit) async {
    // Skip paused habits — health guardrail prevents streak loss
    if (habit.isPaused) return;
    if (habit.lastCompleted == null) return;
    if (!habit.shouldResetStreak) return;

    // Reset streak to 0 if more than 2 days have passed
    await _habitsRef.doc(habit.id).update({'streak': 0});
  }

  // Shows dialog for adding a new habit
  void _showAddDialog() {
    final nameController = TextEditingController();
    _selectedDomainId = 'health';
    _selectedDomainName = 'Health';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder allows the dialog to update its own UI state
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('New Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Drink Water, Daily Study',
                  labelText: 'Habit Name',
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Link to Domain:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              // Dropdown for selecting which domain this habit belongs to
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
                    _selectedDomainId = value!;
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
                // Only creates habit if name is not empty
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

  // Shows confirmation dialog before deleting a habit
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

  // Shows a bottom sheet explaining the health guardrail pause feature
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
          // Info button explaining the health guardrail feature
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showPauseInfo(context),
          ),
        ],
      ),
      // FAB button to open the add habit dialog
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      // StreamBuilder listens to real-time Firestore changes
      body: StreamBuilder<QuerySnapshot>(
        stream: _habitsRef
            .orderBy('created_at', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          // Shows loading spinner while waiting for Firestore data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Shows empty state if user has no habits yet
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No habits yet. Tap + to add one!'),
            );
          }

          // Converts Firestore documents to Habit objects
          final habits = snapshot.data!.docs
              .map((doc) => Habit.fromFirestore(doc))
              .toList();

          // Groups habits by their linked domain name for organized display
          final Map<String, List<Habit>> groupedHabits = {};
          for (final habit in habits) {
            // Check and reset streaks for inactive habits when loading
            _checkAndResetStreak(habit);
            groupedHabits
                .putIfAbsent(habit.domainName, () => [])
                .add(habit);
          }

          // Builds a list grouped by domain
          return ListView(
            padding: const EdgeInsets.all(16),
            children: groupedHabits.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Domain group header
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
                  // List of habits under this domain
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

  // Builds a single habit card with streak, complete, pause, and delete actions
  Widget _buildHabitCard(Habit habit) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Paused habits appear slightly transparent as a visual indicator
      color: habit.isPaused ? Colors.grey.shade200 : null,
      child: ListTile(
        // Fire icon showing current streak count
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shows fire emoji if streak is active, snowflake if paused
            Text(
              habit.isPaused ? '❄️' : '🔥',
              style: const TextStyle(fontSize: 20),
            ),
            Text(
              '${habit.streak}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            // Strike-through text for paused habits
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
            // Complete button — disabled if already done today or paused
            IconButton(
              icon: Icon(
                Icons.check_circle,
                // Green if completed today, grey otherwise
                color: habit.isCompletedToday
                    ? Colors.green
                    : Colors.grey,
              ),
              onPressed: habit.isCompletedToday || habit.isPaused
                  ? null
                  : () => _completeHabit(habit),
            ),
            // Pause/Resume button — health guardrail feature
            IconButton(
              icon: Icon(
                habit.isPaused ? Icons.play_arrow : Icons.pause,
                // Blue for resume, orange for pause
                color: habit.isPaused ? Colors.blue : Colors.orange,
              ),
              onPressed: () => _togglePause(habit),
            ),
            // Delete button
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

