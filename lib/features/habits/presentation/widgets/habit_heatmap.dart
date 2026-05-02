import 'package:flutter/material.dart';
import '../../domain/habit_model.dart';

class HabitHeatmap extends StatelessWidget {
  final Habit habit;
  final int daysToShow;

  const HabitHeatmap({
    super.key,
    required this.habit,
    this.daysToShow = 14,
  });

  @override
  Widget build(BuildContext context) {
    final today = Habit.normalizeDate(DateTime.now());
    final dates = List.generate(daysToShow, (index) {
      return today.subtract(Duration(days: (daysToShow - 1) - index));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last 2 Weeks',
          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: dates.map((date) {
            final isCompleted = habit.completionDates.any(
              (d) => Habit.normalizeDate(d) == date
            );
            final isToday = date == today;

            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.orangeAccent
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(2),
                border: isToday
                    ? Border.all(color: Colors.white30, width: 1)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
