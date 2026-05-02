import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:home_widget/home_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../notes/domain/entities/note_entity.dart';
import '../../notes/domain/repositories/note_repository.dart';
import '../../../core/logic/ai_pipeline_service.dart';
import '../../habits/domain/habit_model.dart';
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
    required this.todayTasks,
    required this.todayEvents,
    required this.finishedEvents,
    required this.closeEvents,
    required this.domains,
    required this.deadlineCount,
    required this.completedHabitsCount,
    this.dailySummary,
    this.aiProactiveSuggestions,
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
  final String? dailySummary;
  final List<String>? aiProactiveSuggestions;
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
    this._noteRepository,
    this._aiPipeline,
  ) : super(const HomeDashboardInitial());

  final TaskRepository _taskRepository;
  final CalendarRepository _calendarRepository;
  final DomainRepository _domainRepository;
  final NoteRepository _noteRepository;
  final AiPipelineService _aiPipeline;
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
      _subscription = Rx.combineLatest5(
        _db.collection('users').doc(uid).collection('habits').snapshots().map(
            (snap) => snap.docs.map((doc) => Habit.fromFirestore(doc)).toList()),
        _taskRepository.watchTasks(),
        _domainRepository.watchDomains(),
        _calendarRepository.watchEventsForMonth(DateTime(now.year, now.month)),
        _noteRepository.watchNotes(uid),
        (List<Habit> habits, List<TaskEntity> tasks, List<DomainEntity> domains, List<CalendarEventEntity> allEvents, List<NoteEntity> notes) {
          
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

          String? currentSummary;
          List<String>? currentProactive;
          if (state is HomeDashboardLoaded) {
            currentSummary = (state as HomeDashboardLoaded).dailySummary;
            currentProactive = (state as HomeDashboardLoaded).aiProactiveSuggestions;
          }

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
            dailySummary: currentSummary,
            aiProactiveSuggestions: currentProactive,
          );
        },
      ).listen(
        (newState) {
          emit(newState);
          if (newState is HomeDashboardLoaded) {
            _updateHomeWidgets(newState);
            if (newState.dailySummary == null) {
              _generateDailySummary(newState);
            }
            if (newState.aiProactiveSuggestions == null) {
              _generateProactiveRecommendations(newState);
            }
          }
        },
        onError: (e) => emit(HomeDashboardError(e.toString())),
      );

    } catch (e) {
      emit(HomeDashboardError(e.toString()));
    }
  }

  Future<void> _generateDailySummary(HomeDashboardLoaded currentState) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      final completedToday = currentState.tasks.where((t) => 
        t.status == TaskStatus.done && 
        t.updatedAt != null && 
        t.updatedAt!.isAfter(todayStart)
      ).toList();

      final uid = _auth.currentUser?.uid ?? 'guest_user';
      final notes = await _noteRepository.watchNotes(uid).first;
      final todayNotes = notes.where((n) => n.updatedAt.isAfter(todayStart)).toList();

      if (completedToday.isEmpty && todayNotes.isEmpty && currentState.completedHabitsCount == 0) {
        emit(currentState); // No need to summarize nothing
        return;
      }

      final contextData = """
      TAMAMLANAN GÖREVLER:
      ${completedToday.map((t) => "- ${t.title}").join("\n")}
      
      BUGÜNKÜ NOTLAR:
      ${todayNotes.map((n) => "- ${n.title}: ${n.content}").join("\n")}
      
      TAMAMLANAN ALIŞKANLIKLAR: ${currentState.completedHabitsCount}
      """;

      final aiResult = await _aiPipeline.dispatch(
        "Bugünkü ilerlememi ve notlarımı kısaca özetle. Motivasyon verici ve hafif bir ton kullan.",
        [],
        appData: contextData,
      );

      if (state is HomeDashboardLoaded) {
        emit((state as HomeDashboardLoaded).copyWith(dailySummary: aiResult.responseText));
      }
    } catch (e) {
      print("Summary Generation Error: $e");
    }
  }

  Future<void> _generateProactiveRecommendations(HomeDashboardLoaded currentState) async {
    try {
      final contextData = """
      BEKLEYEN GÖREVLER:
      ${currentState.tasks.where((t) => t.status != TaskStatus.done).take(5).map((t) => "- ${t.title}").join("\n")}
      
      ALIŞKANLIKLAR (Bugün yapılmayanlar):
      ${currentState.habits.where((h) => !h.isCompletedToday).map((h) => "- ${h.name}").join("\n")}
      """;

      final aiResult = await _aiPipeline.dispatch(
        "Kullanıcının mevcut görevlerine ve eksik alışkanlıklarına bakarak yapması gereken en fazla 3 proaktif öneri ver. Örneğin 'Bugün ders çalışma rutinine ek olarak kısa bir tekrar fena olmaz' veya 'Alışveriş listesi yapma zamanı'. Sadece önerileri madde işareti (*) kullanarak liste halinde dön, başka bir şey yazma.",
        [],
        appData: contextData,
      );

      final suggestions = aiResult.responseText
          .split('\n')
          .where((line) => line.trim().startsWith('*'))
          .map((line) => line.replaceAll('*', '').trim())
          .take(3)
          .toList();

      if (suggestions.isNotEmpty && state is HomeDashboardLoaded) {
        emit((state as HomeDashboardLoaded).copyWith(aiProactiveSuggestions: suggestions));
      }
    } catch (e) {
      print("Proactive Recommendations Error: $e");
    }
  }

  Future<void> _updateHomeWidgets(HomeDashboardLoaded state) async {
    try {
      final tasksJson = jsonEncode(state.todayTasks.map((t) => {'title': t.title, 'isDone': t.status == TaskStatus.done}).toList());
      final habitsJson = jsonEncode(state.habits.map((h) => {'name': h.name, 'isDone': h.isCompletedToday}).toList());

      await HomeWidget.saveWidgetData<String>('tasks_data', tasksJson);
      await HomeWidget.saveWidgetData<String>('habits_data', habitsJson);
      await HomeWidget.saveWidgetData<int>('active_habits_count', state.habits.where((h) => !h.isPaused).length);
      await HomeWidget.saveWidgetData<int>('tasks_count', state.todayTasks.length);

      await HomeWidget.updateWidget(
        name: 'LifeStableWidgetProvider',
        iOSName: 'LifeStableWidget',
      );
    } catch (e) {
      print("HomeWidget Update Error: $e");
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

extension on HomeDashboardLoaded {
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
    String? dailySummary,
    List<String>? aiProactiveSuggestions,
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
      dailySummary: dailySummary ?? this.dailySummary,
      aiProactiveSuggestions: aiProactiveSuggestions ?? this.aiProactiveSuggestions,
    );
  }
}
