import 'package:flutter/material.dart';

class HabitTrackerPage extends StatelessWidget {
  const HabitTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
      ),
      body: const Center(
        child: Text('Habit Tracker Placeholder'),
      ),
    );
  }
}

