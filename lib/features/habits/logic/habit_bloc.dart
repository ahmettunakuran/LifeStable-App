import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../domain/habit_model.dart';

// Events
abstract class HabitEvent extends Equatable {
  const HabitEvent();
  @override
  List<Object> get props => [];
}

class LoadHabits extends HabitEvent {}

class ToggleHabitCompletion extends HabitEvent {
  final String habitId;
  final DateTime date;
  const ToggleHabitCompletion(this.habitId, this.date);

  @override
  List<Object> get props => [habitId, date];
}

// States
abstract class HabitState extends Equatable {
  const HabitState();
  @override
  List<Object> get props => [];
}

class HabitLoading extends HabitState {}

class HabitLoaded extends HabitState {
  final List<Habit> habits;
  const HabitLoaded(this.habits);

  @override
  List<Object> get props => [habits];
}

class HabitBloc extends Bloc<HabitEvent, HabitState> {
  HabitBloc() : super(HabitLoading()) {
    on<LoadHabits>(_onLoadHabits);
    on<ToggleHabitCompletion>(_onToggleHabitCompletion);
  }

  void _onLoadHabits(LoadHabits event, Emitter<HabitState> emit) {
    // Mock data for demonstration
    final habits = [
      Habit(
        id: '1',
        name: 'Morning Meditation',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        completionDates: [
          DateTime.now().subtract(const Duration(days: 0)),
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now().subtract(const Duration(days: 2)),
          DateTime.now().subtract(const Duration(days: 4)),
        ],
      ),
      Habit(
        id: '2',
        name: 'Read 20 Pages',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        completionDates: List.generate(10, (index) => DateTime.now().subtract(Duration(days: index))),
      ),
      Habit(
        id: '3',
        name: 'Drink 2L Water',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        completionDates: [
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now().subtract(const Duration(days: 2)),
        ],
      ),
    ];
    emit(HabitLoaded(habits));
  }

  void _onToggleHabitCompletion(ToggleHabitCompletion event, Emitter<HabitState> emit) {
    if (state is HabitLoaded) {
      final currentState = state as HabitLoaded;
      final updatedHabits = currentState.habits.map((habit) {
        if (habit.id == event.habitId) {
          final normalizedDate = Habit.normalizeDate(event.date);
          final dates = List<DateTime>.from(habit.completionDates);
          if (dates.any((d) => Habit.normalizeDate(d) == normalizedDate)) {
            dates.removeWhere((d) => Habit.normalizeDate(d) == normalizedDate);
          } else {
            dates.add(event.date);
          }
          return habit.copyWith(completionDates: dates);
        }
        return habit;
      }).toList();
      emit(HabitLoaded(updatedHabits));
    }
  }
}
