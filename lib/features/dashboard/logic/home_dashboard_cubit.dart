import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../habits/presentation/habit.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../domain/entities/domain_entity.dart';
import '../domain/repositories/domain_repository.dart';

sealed class HomeDashboardState {
  const HomeDashboardState();
}

class HomeDashboardInitial extends HomeDashboardState {
  const HomeDashboardInitial();
}

class HomeDashboardLoading extends HomeDashboardState {
  const HomeDashboardLoading();
}

class HomeDashboardLoaded extends HomeDashboardState {
  const HomeDashboardLoaded({
    required this.habits,
    required this.tasks,
    required this.todayEvents,
    required this.finishedEvents,
    required this.closeEvents,
    required this.domains,
    required this.deadlineCount,
    required this.completedHabitsCount,
  });

  final List<Habit> habits;
  final List<TaskEntity> tasks;
  final List<CalendarEventEntity> todayEvents;
  final List<CalendarEventEntity> finishedEvents;
  final List<CalendarEventEntity> closeEvents;
  final List<DomainEntity> domains;
  final int deadlineCount;
  final int completedHabitsCount;
}

class HomeDashboardError extends HomeDashboardState {
  const HomeDashboardError(this.message);
  final String message;
}

class HomeDashboardCubit extends Cubit<HomeDashboardState> {
  HomeDashboardCubit(
    this._taskRepository,
    this._calendarRepository,
    this._domainRepository,
  ) : super(const HomeDashboardInitial());

  final TaskRepository _taskRepository;
  final CalendarRepository _calendarRepository;
  final DomainRepository _domainRepository;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _subscription;

  Future<void> loadOverview() async {
    emit(const HomeDashboardLoading());
    try {
      final uid = _auth.currentUser?.uid ?? 'guest_user';
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final threeDaysLater = todayStart.add(const Duration(days: 3));

      // Combine all streams into one for real-time updates
      _subscription = Rx.combineLatest4(
        _db.collection('users').doc(uid).collection('habits').snapshots().map(
            (snap) => snap.docs.map((doc) => Habit.fromFirestore(doc)).toList()),
        _taskRepository.watchTasks(),
        _domainRepository.watchDomains(),
        _calendarRepository.watchEventsForMonth(DateTime(now.year, now.month)),
        (List<Habit> habits, List<TaskEntity> tasks, List<DomainEntity> domains, List<CalendarEventEntity> allEvents) {
          
          final todayEvents = allEvents.where((e) {
            return e.startAt.isAfter(todayStart) && e.startAt.isBefore(tomorrowStart);
          }).toList();

          final finishedEvents = allEvents.where((e) => e.endAt.isBefore(now)).toList();
          final closeEvents = allEvents.where((e) {
            return e.startAt.isAfter(now) && e.startAt.isBefore(threeDaysLater);
          }).toList();

          final todayTasksCount = tasks.where((t) {
            if (t.dueDate == null) return false;
            return t.dueDate!.isAfter(todayStart) && t.dueDate!.isBefore(tomorrowStart);
          }).length;

          final completedHabitsCount = habits.where((h) => h.isCompletedToday).length;

          return HomeDashboardLoaded(
            habits: habits,
            tasks: tasks,
            todayEvents: todayEvents,
            finishedEvents: finishedEvents,
            closeEvents: closeEvents,
            domains: domains,
            deadlineCount: todayTasksCount,
            completedHabitsCount: completedHabitsCount,
          );
        },
      ).listen(
        (newState) => emit(newState),
        onError: (e) => emit(HomeDashboardError(e.toString())),
      );

    } catch (e) {
      emit(HomeDashboardError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
