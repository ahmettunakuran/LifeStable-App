import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/habit_model.dart';

class CompletionChart extends StatelessWidget {
  final Habit habit;
  const CompletionChart({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final last7Days = List.generate(7, (index) {
      return Habit.normalizeDate(DateTime.now().subtract(Duration(days: 6 - index)));
    });

    return SizedBox(
      height: 100,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = last7Days[groupIndex];
                final completed = rod.toY == 1;
                return BarTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n${completed ? 'Completed' : 'Missed'}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < last7Days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('E').format(last7Days[index]).substring(0, 1),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(last7Days.length, (index) {
            final date = last7Days[index];
            final isCompleted = habit.completionDates.any((d) => Habit.normalizeDate(d) == date);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: isCompleted ? 1 : 0.1,
                  color: isCompleted ? Colors.orangeAccent : Colors.grey.withOpacity(0.3),
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
