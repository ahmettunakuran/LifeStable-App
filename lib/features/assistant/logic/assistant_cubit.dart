import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/chat_message.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../../dashboard/domain/repositories/domain_repository.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/logic/ai_pipeline_service.dart';
import '../../../services/help_bot_service.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final TaskRepository _taskRepository;
  final CalendarRepository _calendarRepository;
  final DomainRepository _domainRepository;
  final AiPipelineService _aiPipeline;

  AssistantCubit({
    required TaskRepository taskRepository,
    required CalendarRepository calendarRepository,
    required DomainRepository domainRepository,
    required AiPipelineService aiPipeline,
  })  : _taskRepository = taskRepository,
        _calendarRepository = calendarRepository,
        _domainRepository = domainRepository,
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
      // ── Help Bot intercept ──────────────────────────────────────────────
      // Route "how / what / explain / help" style questions to the semantic
      // FAQ retriever before hitting the Groq action pipeline.
      if (_isHelpQuery(content)) {
        final helpResponse = await HelpBotService().ask(content.trim());
        if (!helpResponse.usedFallback ||
            helpResponse.confidenceScore >= 0.60) {
          final finalMessages = [
            ...withLoading.where((m) => !m.isLoading),
            ChatMessage(
              content: helpResponse.answer,
              sender: MessageSender.assistant,
            ),
          ];
          emit(state.copyWith(
            messages: finalMessages,
            status: AssistantStatus.idle,
          ));
          return;
        }
        // Low-confidence fallback — let Groq handle it normally
      }
      // ── End Help Bot intercept ──────────────────────────────────────────

      final tasks = await _taskRepository.fetchTasks();
      final domains = await _domainRepository.fetchDomains();
      final now = DateTime.now();
      
      // Fetch events for current and next month to support "next week" queries
      List<CalendarEventEntity> calendarEvents = [];
      try {
        final currentMonthEvents = await _calendarRepository.watchEventsForMonth(now).first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => [],
        );
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final nextMonthEvents = await _calendarRepository.watchEventsForMonth(nextMonth).first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => [],
        );
        calendarEvents = [...currentMonthEvents, ...nextMonthEvents];
      } catch (e) {
        print("Calendar fetch error: $e");
      }
      
      final String appData = """
      BUGÜN: ${now.toIso8601String().split('T')[0]}
      KULLANICI ALANLARI (DOMAINS):
      ${domains.map((d) => "- [ID: ${d.id}] ${d.name}").join("\n")}

      MEVCUT GÖREVLER:
      ${tasks.map((t) => "- [ID: ${t.id}] ${t.title} (Bitiş: ${t.dueDate?.toIso8601String()})").join("\n")}
      
      MEVCUT TAKVİM ETKİNLİKLERİ:
      ${calendarEvents.map((e) => "- [ID: ${e.id}] ${e.title} (Başlangıç: ${e.startAt.toIso8601String()}, Bitiş: ${e.endAt.toIso8601String()})").join("\n")}
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
        appData: appData,
        configKey: 'groq_api_key2',
      );

      print('AI RESPONSE: Domain: ${aiResult.domain}, Action: ${aiResult.action}, Payload: ${aiResult.payload}');

      String? redirectTo;
      Object? redirectArgs;
      if (aiResult.domain == AppDomain.tasks && aiResult.action == 'create') {
        redirectTo = AppRoutes.tasksKanban;
        final dueDateStr = aiResult.payload['dueDate']?.toString();
        final DateTime? dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
        String title = aiResult.payload['title'] ?? 'Yeni Görev';
        String domainId = aiResult.payload['domainId'] ?? aiResult.payload['domain_id'] ?? '';
        int matchedDomainIndex = -1;

        // If domain name was provided instead of ID, try to find it
        final domainInput = (aiResult.payload['domain'] ?? aiResult.payload['domainId'] ?? '').toString().toLowerCase();
        if (domainInput.isNotEmpty) {
          for (int i = 0; i < domains.length; i++) {
            if (domains[i].name.toLowerCase() == domainInput || domains[i].id == domainInput) {
              domainId = domains[i].id;
              matchedDomainIndex = i;
              break;
            }
          }
        }

        if (domainId.isEmpty && domains.isNotEmpty) {
          domainId = domains.first.id;
          matchedDomainIndex = 0;
        }

        if (matchedDomainIndex != -1) {
          redirectTo = AppRoutes.domainDashboard;
          redirectArgs = matchedDomainIndex;
        } else {
          redirectTo = AppRoutes.tasksKanban;
        }

        final task = TaskEntity(
          id: const Uuid().v4(),
          domainId: domainId,
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
        redirectTo = AppRoutes.calendar;
        final startAtStr = aiResult.payload['startTime'] ?? 
                         aiResult.payload['start_time'] ?? 
                         aiResult.payload['date'] ?? 
                         aiResult.payload['dueDate'] ?? 
                         aiResult.payload['due_date'];

        final endAtStr = aiResult.payload['endTime'] ?? aiResult.payload['end_time'];
        
        DateTime startAt;
        try {
          startAt = startAtStr != null ? DateTime.parse(startAtStr) : DateTime.now();
        } catch (e) {
          startAt = DateTime.now();
        }

        redirectArgs = {'initialDay': startAt};

        DateTime endAt;
        try {
          endAt = endAtStr != null ? DateTime.parse(endAtStr) : startAt.add(const Duration(hours: 1));
        } catch (e) {
          endAt = startAt.add(const Duration(hours: 1));
        }
        
        String title = aiResult.payload['title'] ?? 'Yeni Etkinlik';

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
      } else if (aiResult.action == 'find_gap') {
        // Do not redirect for gap finding, stay in chat to show suggestions
      } else if (aiResult.action == 'delete') {
        if (aiResult.domain == AppDomain.calendar) {
          redirectTo = AppRoutes.calendar;
        } else if (aiResult.domain == AppDomain.tasks) {
          redirectTo = AppRoutes.tasksKanban;
        }
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
        final id = aiResult.payload['id'] ?? aiResult.payload['domainId'] ?? aiResult.payload['domain_id'];
        if (aiResult.domain == AppDomain.tasks) {
          final existingTask = tasks.cast<TaskEntity?>().firstWhere(
            (t) => t?.id == id || (t != null && aiResult.payload['title'] != null && t.title.toLowerCase().contains(aiResult.payload['title'].toString().toLowerCase())), 
            orElse: () => null
          );
          if (existingTask != null) {
            redirectTo = AppRoutes.tasksKanban;
            final dueDateStr = aiResult.payload['dueDate'] ?? aiResult.payload['due_date'];
            DateTime? newDueDate = dueDateStr != null ? DateTime.parse(dueDateStr) : existingTask.dueDate;
            String newTitle = aiResult.payload['title'] ?? existingTask.title;
            final updatedTask = existingTask.copyWith(
              title: newTitle,
              description: aiResult.payload['description'] ?? existingTask.description,
              dueDate: newDueDate,
              priority: aiResult.payload['priority'] != null ? _parsePriority(aiResult.payload['priority']) : existingTask.priority,
            );
            await _taskRepository.createOrUpdateTask(updatedTask);
          }
        } else if (aiResult.domain == AppDomain.calendar) {
          final existingEvent = calendarEvents.firstWhere(
            (e) => e.id.toString() == id.toString(),
            orElse: () => calendarEvents.firstWhere(
              (e) => aiResult.payload['title'] != null && e.title.toLowerCase().contains(aiResult.payload['title'].toString().toLowerCase()),
              orElse: () => CalendarEventEntity(id: 'none', userId: '', title: '', startAt: DateTime.now(), endAt: DateTime.now()),
            ),
          );

          if (existingEvent.id != 'none') {
            redirectTo = AppRoutes.calendar;
            final startAtStr = aiResult.payload['startTime'] ?? aiResult.payload['start_time'] ?? aiResult.payload['date'];
            final endAtStr = aiResult.payload['endTime'] ?? aiResult.payload['end_time'];

            DateTime newStartAt = startAtStr != null ? DateTime.parse(startAtStr) : existingEvent.startAt;
            redirectArgs = {'initialDay': newStartAt};

            String newTitle = aiResult.payload['title'] ?? existingEvent.title;
            final updatedEvent = existingEvent.copyWith(
              title: newTitle,
              description: aiResult.payload['description'] ?? existingEvent.description,
              startAt: newStartAt,
              endAt: endAtStr != null ? DateTime.parse(endAtStr) : (startAtStr != null ? newStartAt.add(const Duration(hours: 1)) : existingEvent.endAt),
            );
            await _calendarRepository.updateEvent(updatedEvent);
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
        status: redirectTo != null ? AssistantStatus.navigate : AssistantStatus.idle,
        redirectTo: redirectTo,
        redirectArgs: redirectArgs,
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

  /// Returns true when the user's message looks like a help/how-to question
  /// rather than an action command (create, delete, update, find_gap).
  bool _isHelpQuery(String text) {
    final lower = text.toLowerCase().trim();
    const helpPrefixes = [
      'how do i', 'how to', 'how can i', 'what is', 'what are',
      'explain', 'help me with', 'tell me about', 'where is',
      'where can i', 'what does', 'how does', 'why does', 'why is',
      'show me how', 'i don\'t know how',
    ];
    return helpPrefixes.any((p) => lower.startsWith(p)) ||
        (lower.contains('how') && lower.contains('?')) ||
        (lower.contains('what') && lower.contains('?'));
  }
}
