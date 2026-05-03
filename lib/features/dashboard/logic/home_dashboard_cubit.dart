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
import '../../../core/logic/ai_pipeline_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
    required this.todayTasks,
    required this.todayEvents,
    required this.finishedEvents,
    required this.closeEvents,
    required this.domains,
    required this.deadlineCount,
    required this.completedHabitsCount,
    this.aiInsight,
    this.isInsightLoading = false,
  });

  final List<Habit> habits;
  final List<TaskEntity> tasks;
  final List<TaskEntity> todayTasks;
  final List<CalendarEventEntity> todayEvents;
  final List<CalendarEventEntity> finishedEvents;
  final List<CalendarEventEntity> closeEvents;
  final List<DomainEntity> domains;
  final int deadlineCount;
  final int completedHabitsCount;
  final String? aiInsight;
  final bool isInsightLoading;

  HomeDashboardLoaded copyWith({
    List<Habit>? habits,
    List<TaskEntity>? tasks,
    List<TaskEntity>? todayTasks,
    List<CalendarEventEntity>? todayEvents,
    List<CalendarEventEntity>? finishedEvents,
    List<CalendarEventEntity>? closeEvents,
    List<DomainEntity>? domains,
    int? deadlineCount,
    int? completedHabitsCount,
    String? aiInsight,
    bool? isInsightLoading,
  }) {
    return HomeDashboardLoaded(
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      todayTasks: todayTasks ?? this.todayTasks,
      todayEvents: todayEvents ?? this.todayEvents,
      finishedEvents: finishedEvents ?? this.finishedEvents,
      closeEvents: closeEvents ?? this.closeEvents,
      domains: domains ?? this.domains,
      deadlineCount: deadlineCount ?? this.deadlineCount,
      completedHabitsCount: completedHabitsCount ?? this.completedHabitsCount,
      aiInsight: aiInsight ?? this.aiInsight,
      isInsightLoading: isInsightLoading ?? this.isInsightLoading,
    );
  }
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
  final AiPipelineService _aiPipelineService = AiPipelineService();

  StreamSubscription? _subscription;
  bool _hasFetchedInsight = false;
  String _lastLanguageCode = '';

  void _setupLocaleListener() {
    localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    final newLang = localeNotifier.value.languageCode;
    if (newLang != _lastLanguageCode && state is HomeDashboardLoaded) {
      _hasFetchedInsight = false;
      _lastLanguageCode = newLang;
      final current = state as HomeDashboardLoaded;
      emit(current.copyWith(aiInsight: null, isInsightLoading: false));
      _fetchInsight(current);
    }
  }

  Future<void> loadOverview() async {
    _lastLanguageCode = localeNotifier.value.languageCode;
    _setupLocaleListener();
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

          final rawTodayTasks = tasks.where((t) {
            if (t.dueDate == null || t.status == TaskStatus.done) return false;
            return t.dueDate!.isAfter(todayStart) && t.dueDate!.isBefore(tomorrowStart);
          }).toList();
          const priorityOrder = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
          rawTodayTasks.sort((a, b) =>
              (priorityOrder[a.priority] ?? 1).compareTo(priorityOrder[b.priority] ?? 1));

          final completedHabitsCount = habits.where((h) => h.isCompletedToday).length;

          return HomeDashboardLoaded(
            habits: habits,
            tasks: tasks,
            todayTasks: rawTodayTasks,
            todayEvents: todayEvents,
            finishedEvents: finishedEvents,
            closeEvents: closeEvents,
            domains: domains,
            deadlineCount: rawTodayTasks.length,
            completedHabitsCount: completedHabitsCount,
          );
        },
      ).listen(
        (newState) {
          if (state is HomeDashboardLoaded) {
            final oldState = state as HomeDashboardLoaded;
            newState = newState.copyWith(
              aiInsight: oldState.aiInsight,
              isInsightLoading: oldState.isInsightLoading,
            );
          }
          emit(newState);

          if (!_hasFetchedInsight && newState.aiInsight == null && !newState.isInsightLoading) {
            _fetchInsight(newState);
          }

          if (newState is HomeDashboardLoaded) {
            _updateWidgets(newState);
          }
        },
        onError: (e) => emit(HomeDashboardError(e.toString())),
      );

    } catch (e) {
      emit(HomeDashboardError(e.toString()));
    }
  }

  Future<void> _fetchInsight(HomeDashboardLoaded currentState) async {
    _hasFetchedInsight = true;
    emit(currentState.copyWith(isInsightLoading: true));
    
    final languageCode = localeNotifier.value.languageCode;
    final StringBuffer promptData = StringBuffer();
    promptData.writeln("TODAY'S TASKS:");
    for (var t in currentState.todayTasks) {
      promptData.writeln("- ${t.title}");
    }
    promptData.writeln("TODAY'S HABITS:");
    for (var h in currentState.habits) {
      promptData.writeln("- ${h.name} (Status: ${h.isCompletedToday ? 'Done' : 'Pending'})");
    }

    final result = await _aiPipelineService.fetchDailyInsights(
      promptData.toString(),
      configKey: 'groq_api_key2',
      languageCode: languageCode,
    );
    
    if (state is HomeDashboardLoaded) {
      emit((state as HomeDashboardLoaded).copyWith(
        isInsightLoading: false,
        aiInsight: result,
      ));
    }
  }

  Future<void> _updateWidgets(HomeDashboardLoaded loadedState) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Build domain id->name lookup
      final Map<String, String> domainNames = {};
      for (final d in loadedState.domains) {
        domainNames[d.id] = d.name;
      }

      // Tasks - group by domain, show all non-done tasks
      final activeTasks = loadedState.tasks.where((t) => t.status != TaskStatus.done).toList();
      final taskCount = activeTasks.length.toString();

      // Group tasks by domain
      final Map<String, List<TaskEntity>> tasksByDomain = {};
      for (final t in activeTasks) {
        final domainName = domainNames[t.domainId] ?? 'Diğer';
        tasksByDomain.putIfAbsent(domainName, () => []);
        tasksByDomain[domainName]!.add(t);
      }

      // Build task detail string with domain headers
      final List<String> taskLines = [];
      int domainCount = 0;
      for (final entry in tasksByDomain.entries) {
        if (domainCount >= 3) break; // max 3 domains
        taskLines.add('📁 ' + entry.key);
        for (final t in entry.value.take(3)) {
          taskLines.add('  • ' + t.title);
        }
        if (entry.value.length > 3) {
          taskLines.add('  +' + (entry.value.length - 3).toString() + ' daha...');
        }
        domainCount++;
      }
      final tasksDetail = taskLines.join('\n');
      await prefs.setString('widget_tasks_count', taskCount + ' görev');
      await prefs.setString('widget_tasks_detail', tasksDetail);

      // Habits - show ALL habits with completion checkmark
      final allHabits = loadedState.habits;
      int doneCount = 0;
      final List<String> habitLines = [];
      for (final h in allHabits.take(4)) {
        if (h.isCompletedToday) doneCount++;
        final icon = h.isCompletedToday ? '✓' : '○';
        habitLines.add(icon + ' ' + h.name);
      }
      // Count all completed, not just first 4
      for (final h in allHabits.skip(4)) {
        if (h.isCompletedToday) doneCount++;
      }
      final habitsDetail = habitLines.join('\n');
      final habitsCount = doneCount.toString() + '/' + allHabits.length.toString() + ' tamamlandı';
      await prefs.setString('widget_habits_count', habitsCount);
      await prefs.setString('widget_habits_detail', habitsDetail);

      // Trigger widget refresh via method channel
      const channel = MethodChannel('com.example.project_lifestable/widget');
      try {
        await channel.invokeMethod('updateWidget');
      } catch (_) {}
    } catch (e) {
      // silently ignore widget update errors
    }
  }

    @override
  Future<void> close() {
    localeNotifier.removeListener(_onLocaleChanged);
    _subscription?.cancel();
    return super.close();
  }
}
