import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/chat_message.dart';
import '../domain/repositories/assistant_repository.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../../../core/logic/ai_pipeline_service.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final AssistantRepository _repository;
  final TaskRepository _taskRepository;
  final CalendarRepository _calendarRepository;
  final AiPipelineService _aiPipeline;

  AssistantCubit({
    required AssistantRepository repository,
    required TaskRepository taskRepository,
    required CalendarRepository calendarRepository,
    required AiPipelineService aiPipeline,
  })  : _repository = repository,
        _taskRepository = taskRepository,
        _calendarRepository = calendarRepository,
        _aiPipeline = aiPipeline,
        super(const AssistantState());

  TaskPriority _parsePriority(String? priority) {
    if (priority == null) return TaskPriority.low;
    return TaskPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == priority.toLowerCase(),
      orElse: () => TaskPriority.low,
    );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage(
      content: content.trim(),
      sender: MessageSender.user,
    );

    final withLoading = [
      ...state.messages,
      userMessage,
      ChatMessage(
        content: '',
        sender: MessageSender.assistant,
        isLoading: true,
      ),
    ];

    emit(state.copyWith(
      messages: withLoading,
      status: AssistantStatus.responding,
    ));

    try {
      final tasks = await _taskRepository.fetchTasks();
      final now = DateTime.now();
      List<CalendarEventEntity> calendarEvents = [];
      try {
        calendarEvents = await _calendarRepository.watchEventsForMonth(now).first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => [],
        );
      } catch (e) {
        print("Calendar fetch error: $e");
      }
      
      final String appData = """
      BUGÜN: ${now.toIso8601String().split('T')[0]}
      MEVCUT GÖREVLER:
      ${tasks.map((t) => "- [ID: ${t.id}] ${t.title} (DueDate: ${t.dueDate})").join("\n")}
      
      MEVCUT TAKVİM ETKİNLİKLERİ:
      ${calendarEvents.map((e) => "- [ID: ${e.id}] ${e.title} (Date: ${e.startAt})").join("\n")}
      """;

      final historyData = state.messages
          .where((m) => !m.isLoading)
          .map((m) => {
                "role": m.sender == MessageSender.user ? "user" : "model",
                "text": m.content
              })
          .toList();

      final aiResult = await _aiPipeline.dispatch(
        content.trim(), 
        historyData,
        appData: appData
      );

      print('AI RESPONSE: Domain: ${aiResult.domain}, Action: ${aiResult.action}, Payload: ${aiResult.payload}');

      if (aiResult.domain == AppDomain.tasks && aiResult.action == 'create') {
        final dueDateStr = aiResult.payload['dueDate'];
        DateTime? dueDate;
        String title = aiResult.payload['title'] ?? 'Yeni Görev';

        if (dueDateStr != null) {
          try {
            dueDate = DateTime.parse(dueDateStr);
            final timePart = "${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}";
            if (!title.contains(timePart)) {
              title = "$title ($timePart)";
            }
          } catch (_) {}
        }

        final task = TaskEntity(
          id: const Uuid().v4(),
          domainId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
          title: title,
          description: aiResult.payload['description'] ?? '',
          status: TaskStatus.todo,
          dueDate: dueDate,
          priority: _parsePriority(aiResult.payload['priority']),
        );
        print('CREATING TASK: ${task.toFirestore()}');
        await _taskRepository.createOrUpdateTask(task);
      } 
      else if (aiResult.domain == AppDomain.calendar && (aiResult.action == 'add_event' || aiResult.action == 'create')) {
        final startAtStr = aiResult.payload['startTime'] ?? aiResult.payload['start_time'] ?? aiResult.payload['date'];
        final endAtStr = aiResult.payload['endTime'] ?? aiResult.payload['end_time'];
        
        DateTime startAt;
        try {
          startAt = startAtStr != null ? DateTime.parse(startAtStr) : DateTime.now();
        } catch (e) {
          startAt = DateTime.now();
        }

        DateTime endAt;
        try {
          endAt = endAtStr != null ? DateTime.parse(endAtStr) : startAt.add(const Duration(hours: 1));
        } catch (e) {
          endAt = startAt.add(const Duration(hours: 1));
        }
        
        String title = aiResult.payload['title'] ?? 'Yeni Etkinlik';
        final timePart = "${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}";
        if (!title.contains(timePart)) {
          title = "$title ($timePart)";
        }

        final event = CalendarEventEntity(
          id: const Uuid().v4(),
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
          title: title,
          description: aiResult.payload['description'] ?? '',
          startAt: startAt,
          endAt: endAt,
          eventType: CalendarEventType.personal,
          sourceCollection: EventSourceCollection.personal,
        );
        
        await _calendarRepository.createPersonalEvent(event);
      } else if (aiResult.action == 'delete') {
        final id = aiResult.payload['id'];
        final ids = aiResult.payload['ids'] as List<dynamic>?;

        if (ids != null && ids.isNotEmpty) {
          for (var deleteId in ids) {
            if (aiResult.domain == AppDomain.tasks) {
              await _taskRepository.deleteTask(deleteId.toString());
            } else if (aiResult.domain == AppDomain.calendar) {
              final event = CalendarEventEntity(
                id: deleteId.toString(),
                userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
                title: '',
                startAt: DateTime.now(),
                endAt: DateTime.now(),
                eventType: CalendarEventType.personal,
              );
              await _calendarRepository.deleteEvent(event);
            }
          }
        } else if (id != null) {
          if (aiResult.domain == AppDomain.tasks) {
            await _taskRepository.deleteTask(id);
          } else if (aiResult.domain == AppDomain.calendar) {
            final event = CalendarEventEntity(
              id: id,
              userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
              title: '',
              startAt: DateTime.now(),
              endAt: DateTime.now(),
              eventType: CalendarEventType.personal,
            );
            await _calendarRepository.deleteEvent(event);
          }
        }
      } else if (aiResult.action == 'update') {
        final id = aiResult.payload['id'];
        if (id != null) {
          if (aiResult.domain == AppDomain.tasks) {
            final existingTask = tasks.cast<TaskEntity?>().firstWhere((t) => t?.id == id, orElse: () => null);
            if (existingTask != null) {
              final dueDateStr = aiResult.payload['dueDate'] ?? aiResult.payload['due_date'];
              DateTime? newDueDate = dueDateStr != null ? DateTime.parse(dueDateStr) : existingTask.dueDate;
              String newTitle = aiResult.payload['title'] ?? existingTask.title;
              if (newDueDate != null) {
                final timePart = "${newDueDate.hour.toString().padLeft(2, '0')}:${newDueDate.minute.toString().padLeft(2, '0')}";
                if (!newTitle.contains(timePart)) {
                  newTitle = "$newTitle ($timePart)";
                }
              }
              final updatedTask = existingTask.copyWith(
                title: newTitle,
                description: aiResult.payload['description'] ?? existingTask.description,
                dueDate: newDueDate,
                priority: aiResult.payload['priority'] != null ? _parsePriority(aiResult.payload['priority']) : existingTask.priority,
              );
              await _taskRepository.createOrUpdateTask(updatedTask);
            }
          } else if (aiResult.domain == AppDomain.calendar) {
            final existingEvent = calendarEvents.cast<CalendarEventEntity?>().firstWhere((e) => e?.id == id, orElse: () => null);
            if (existingEvent != null) {
              final startAtStr = aiResult.payload['startTime'] ?? aiResult.payload['start_time'] ?? aiResult.payload['date'];
              DateTime newStartAt = startAtStr != null ? DateTime.parse(startAtStr) : existingEvent.startAt;
              String newTitle = aiResult.payload['title'] ?? existingEvent.title;
              final timePart = "${newStartAt.hour.toString().padLeft(2, '0')}:${newStartAt.minute.toString().padLeft(2, '0')}";
              if (!newTitle.contains(timePart)) {
                newTitle = "$newTitle ($timePart)";
              }
              final updatedEvent = existingEvent.copyWith(
                title: newTitle,
                description: aiResult.payload['description'] ?? existingEvent.description,
                startAt: newStartAt,
                endAt: aiResult.payload['endTime'] != null ? DateTime.parse(aiResult.payload['endTime']) : newStartAt.add(const Duration(hours: 1)),
              );
              await _calendarRepository.updateEvent(updatedEvent);
            }
          }
        }
      }

      final finalMessages = [
        ...withLoading.where((m) => !m.isLoading),
        ChatMessage(
          content: aiResult.responseText,
          sender: MessageSender.assistant,
        ),
      ];

      emit(state.copyWith(
        messages: finalMessages,
        status: AssistantStatus.idle,
      ));
    } catch (e) {
      print("Assistant Error: $e");
      emit(state.copyWith(
        messages: withLoading.where((m) => !m.isLoading).toList(),
        status: AssistantStatus.error,
        errorMessage: 'İşlem sırasında bir hata oluştu.',
      ));
    }
  }

  void setListening(bool value) =>
      emit(state.copyWith(isListening: value));

  void clearError() => emit(state.copyWith(
    status: AssistantStatus.idle,
    errorMessage: null,
  ));
}
