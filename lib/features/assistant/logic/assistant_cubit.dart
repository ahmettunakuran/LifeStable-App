import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/chat_message.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../../dashboard/domain/repositories/domain_repository.dart';
import '../../dashboard/domain/entities/domain_entity.dart';
import '../../settings/data/user_preferences_service.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/logic/ai_pipeline_service.dart';
import '../../../services/help_bot_service.dart';
import '../../../services/schedule_image_parser.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final TaskRepository _taskRepository;
  final CalendarRepository _calendarRepository;
  final DomainRepository _domainRepository;
  final AiPipelineService _aiPipeline;

  final UserPreferencesService _preferencesService;

  AssistantCubit({
    required TaskRepository taskRepository,
    required CalendarRepository calendarRepository,
    required DomainRepository domainRepository,
    required AiPipelineService aiPipeline,
    UserPreferencesService? preferencesService,
  })  : _taskRepository = taskRepository,
        _calendarRepository = calendarRepository,
        _domainRepository = domainRepository,
        _aiPipeline = aiPipeline,
        _preferencesService = preferencesService ?? UserPreferencesService(),
        super(const AssistantState());

  TaskPriority _parsePriority(String? priority) {
    if (priority == null) return TaskPriority.low;
    return TaskPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == priority.toLowerCase(),
      orElse: () => TaskPriority.low,
    );
  }

  CollectionReference<Map<String, dynamic>> _habitsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habits');
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

      List<QueryDocumentSnapshot<Map<String, dynamic>>> habitDocs = [];
      try {
        final snap = await _habitsRef().get().timeout(const Duration(seconds: 2));
        habitDocs = snap.docs;
      } catch (e) {
        print("Habit fetch error: $e");
      }

      UserPreferences prefs = const UserPreferences();
      try {
        prefs = await _preferencesService.load().timeout(const Duration(seconds: 2));
      } catch (e) {
        print("Preferences fetch error: $e");
      }

      final preferredHours = prefs.topPreferredHours();
      final preferredHoursLine = preferredHours.isEmpty
          ? "Henüz öğrenilmiş tercih yok."
          : preferredHours.map((h) => "${h.toString().padLeft(2, '0')}:00").join(", ");

      final String appData = """
      BUGÜN: ${now.toIso8601String().split('T')[0]}
      KULLANICI ALANLARI (DOMAINS):
      ${domains.map((d) => "- [ID: ${d.id}] ${d.name}").join("\n")}

      MEVCUT GÖREVLER:
      ${tasks.map((t) => "- [ID: ${t.id}] ${t.title} (Bitiş: ${t.dueDate?.toIso8601String()})").join("\n")}

      MEVCUT TAKVİM ETKİNLİKLERİ:
      ${calendarEvents.map((e) => "- [ID: ${e.id}] ${e.title} (Başlangıç: ${e.startAt.toIso8601String()}, Bitiş: ${e.endAt.toIso8601String()})").join("\n")}

      MEVCUT ALIŞKANLIKLAR (HABITS):
      ${habitDocs.map((d) => "- [ID: ${d.id}] ${d.data()['name'] ?? ''} (Domain: ${d.data()['domain_name'] ?? ''}, Streak: ${d.data()['streak'] ?? 0})").join("\n")}

      KULLANICI TERCİHLERİ:
      - Çalışma saatleri: ${prefs.workStartHour.toString().padLeft(2, '0')}:00 - ${prefs.workEndHour.toString().padLeft(2, '0')}:00
      - Uyku: ${prefs.sleepStartHour.toString().padLeft(2, '0')}:00 - ${prefs.sleepEndHour.toString().padLeft(2, '0')}:00
      - Tercih edilen odak bloğu: ${prefs.focusBlockMinutes} dk, mola: ${prefs.breakMinutes} dk
      - Günlük maksimum yoğunluk: ${prefs.dailyMaxScheduledMinutes} dk
      - Geçmişte kabul edilen popüler saatler: $preferredHoursLine
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
        configKey: 'groq_api_key',
      );

      print('AI RESPONSE: Domain: ${aiResult.domain}, Action: ${aiResult.action}, Payload: ${aiResult.payload}');

      String? redirectTo;
      Object? redirectArgs;
      UndoableAction? undoable;
      String? responseOverride;
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
        undoable = UndoableAction(
          token: const Uuid().v4(),
          kind: UndoableKind.task,
          entityId: task.id,
          label: 'Task "$title" oluşturuldu',
        );
      }
      else if (aiResult.domain == AppDomain.calendar && (aiResult.action == 'add_event' || aiResult.action == 'create')) {
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

        DateTime endAt;
        try {
          endAt = endAtStr != null ? DateTime.parse(endAtStr) : startAt.add(const Duration(hours: 1));
        } catch (e) {
          endAt = startAt.add(const Duration(hours: 1));
        }

        final String title = aiResult.payload['title'] ?? 'Yeni Etkinlik';
        final String description = aiResult.payload['description'] ?? '';

        final existingMinutes = _scheduledMinutesOnDay(startAt, calendarEvents);
        final newMinutes = endAt.difference(startAt).inMinutes;

        if (existingMinutes + newMinutes > prefs.dailyMaxScheduledMinutes) {
          // Don't create yet; surface a guardrail bubble. Skip default redirect.
          final guardrail = ChatMessage(
            content: _guardrailText(existingMinutes, newMinutes, prefs.dailyMaxScheduledMinutes, startAt),
            sender: MessageSender.assistant,
            pendingEvent: PendingEvent(
              title: title,
              description: description,
              startAt: startAt,
              endAt: endAt,
              existingMinutes: existingMinutes,
              dailyMax: prefs.dailyMaxScheduledMinutes,
            ),
          );
          emit(state.copyWith(
            messages: [...withLoading.where((m) => !m.isLoading), guardrail],
            status: AssistantStatus.idle,
          ));
          return;
        }

        redirectTo = AppRoutes.calendar;
        redirectArgs = {'initialDay': startAt};

        final event = CalendarEventEntity(
          id: const Uuid().v4(),
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
          title: title,
          description: description,
          startAt: startAt,
          endAt: endAt,
          eventType: CalendarEventType.personal,
          sourceCollection: EventSourceCollection.personal,
        );

        await _calendarRepository.createPersonalEvent(event);
        undoable = UndoableAction(
          token: const Uuid().v4(),
          kind: UndoableKind.calendarEvent,
          entityId: event.id,
          label: 'Etkinlik "$title" eklendi',
        );
      } else if (aiResult.domain == AppDomain.calendar && aiResult.action == 'create_batch') {
        final rawEvents = aiResult.payload['events'];
        final eventsList = (rawEvents is List) ? rawEvents : const [];
        int created = 0;
        for (final raw in eventsList) {
          if (raw is! Map) continue;
          final m = raw.cast<String, dynamic>();
          final title = (m['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          final startStr = (m['startTime'] ?? m['start_time'] ?? '').toString();
          final endStr = (m['endTime'] ?? m['end_time'] ?? '').toString();
          final start = DateTime.tryParse(startStr);
          if (start == null) continue;
          final end = DateTime.tryParse(endStr) ?? start.add(const Duration(hours: 1));
          final event = CalendarEventEntity(
            id: const Uuid().v4(),
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
            title: title,
            description: (m['description'] ?? '').toString(),
            startAt: start,
            endAt: end,
            eventType: CalendarEventType.personal,
            sourceCollection: EventSourceCollection.personal,
          );
          try {
            await _calendarRepository.createPersonalEvent(event);
            created++;
          } catch (_) {}
        }
        if (created > 0) {
          redirectTo = AppRoutes.calendar;
          responseOverride = '$created etkinlik takvime eklendi.';
        } else {
          responseOverride =
              'Takvime ekleyebileceğim bir etkinlik çıkaramadım. Daha net bir görüntü dener misin?';
        }
      } else if (aiResult.domain == AppDomain.habits && aiResult.action == 'create') {
        redirectTo = AppRoutes.habitTracker;
        final name = (aiResult.payload['title'] ?? aiResult.payload['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          String domainId = (aiResult.payload['domainId'] ?? aiResult.payload['domain_id'] ?? '').toString();
          String domainName = (aiResult.payload['domainName'] ?? aiResult.payload['domain_name'] ?? '').toString();

          final domainInput = (aiResult.payload['domain'] ?? '').toString().toLowerCase();
          if (domainInput.isNotEmpty) {
            for (final d in domains) {
              if (d.name.toLowerCase() == domainInput || d.id == domainInput) {
                domainId = d.id;
                domainName = d.name;
                break;
              }
            }
          }
          if (domainId.isEmpty && domains.isNotEmpty) {
            domainId = domains.first.id;
            domainName = domains.first.name;
          }

          final ref = await _habitsRef().add({
            'name': name,
            'domain_id': domainId,
            'domain_name': domainName,
            'streak': 0,
            'last_completed': null,
            'is_paused': false,
            'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'guest_user',
            'created_at': FieldValue.serverTimestamp(),
            'completed_dates': <String>[],
          });
          undoable = UndoableAction(
            token: const Uuid().v4(),
            kind: UndoableKind.habit,
            entityId: ref.id,
            label: 'Alışkanlık "$name" eklendi',
          );
        }
      } else if (aiResult.domain == AppDomain.domains && aiResult.action == 'create') {
        final rawName = (aiResult.payload['title'] ?? aiResult.payload['name'] ?? '').toString().trim();
        if (rawName.isNotEmpty) {
          final name = rawName[0].toUpperCase() + rawName.substring(1);
          final existing = domains.cast<DomainEntity?>().firstWhere(
            (d) => d != null && d.name.toLowerCase() == name.toLowerCase(),
            orElse: () => null,
          );
          if (existing != null) {
            responseOverride = '"${existing.name}" alanı zaten mevcut, yeni bir tane oluşturmadım.';
          } else {
            final newDomain = DomainEntity(
              id: const Uuid().v4(),
              name: name,
              description: (aiResult.payload['description'] ?? '').toString(),
              iconCode: 0xe1af, // Icons.school default
              colorHex: '#7C4DFF',
            );
            await _domainRepository.createOrUpdateDomain(newDomain);
            redirectTo = AppRoutes.homeDashboard;
            undoable = UndoableAction(
              token: const Uuid().v4(),
              kind: UndoableKind.domain,
              entityId: newDomain.id,
              label: 'Alan "$name" oluşturuldu',
            );
          }
        }
      } else if (aiResult.domain == AppDomain.habits && aiResult.action == 'delete') {
        redirectTo = AppRoutes.habitTracker;
        final id = aiResult.payload['id']?.toString();
        final ids = (aiResult.payload['ids'] as List<dynamic>?)?.map((e) => e.toString()).toList();
        final titleHint = (aiResult.payload['title'] ?? aiResult.payload['name'] ?? '').toString().toLowerCase();

        final targets = <String>{};
        if (ids != null) targets.addAll(ids);
        if (id != null && id.isNotEmpty) targets.add(id);
        if (targets.isEmpty && titleHint.isNotEmpty) {
          for (final d in habitDocs) {
            final name = (d.data()['name'] ?? '').toString().toLowerCase();
            if (name.contains(titleHint)) targets.add(d.id);
          }
        }
        for (final hid in targets) {
          await _habitsRef().doc(hid).delete().catchError((_) {});
        }
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

      List<SuggestedSlot>? slots;
      String? slotTitle;
      if (aiResult.action == 'find_gap') {
        final raw = aiResult.payload['suggestedSlots'];
        if (raw is List) {
          slots = raw
              .whereType<Map>()
              .map((m) {
                final start = m['startTime']?.toString() ?? m['start_time']?.toString();
                final end = m['endTime']?.toString() ?? m['end_time']?.toString();
                if (start == null || end == null) return null;
                final s = DateTime.tryParse(start);
                final e = DateTime.tryParse(end);
                if (s == null || e == null) return null;
                return SuggestedSlot(startTime: s, endTime: e);
              })
              .whereType<SuggestedSlot>()
              .toList();
          if (slots.isEmpty) slots = null;
        }
        slotTitle = aiResult.payload['title']?.toString();
      }

      final finalMessages = [
        ...withLoading.where((m) => !m.isLoading),
        ChatMessage(
          content: responseOverride ?? aiResult.responseText,
          sender: MessageSender.assistant,
          suggestedSlots: slots,
          slotTitle: slotTitle,
        ),
      ];

      emit(state.copyWith(
        messages: finalMessages,
        status: redirectTo != null ? AssistantStatus.navigate : AssistantStatus.idle,
        redirectTo: redirectTo,
        redirectArgs: redirectArgs,
        undoable: undoable,
        clearUndoable: undoable == null,
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

  Future<void> acceptSlot({
    required String messageId,
    required SuggestedSlot slot,
    String? title,
  }) async {
    final eventTitle = (title?.trim().isNotEmpty ?? false) ? title!.trim() : 'Yeni Etkinlik';

    UserPreferences prefs = const UserPreferences();
    try {
      prefs = await _preferencesService.load().timeout(const Duration(seconds: 2));
    } catch (_) {}

    List<CalendarEventEntity> dayEvents = [];
    try {
      dayEvents = await _calendarRepository.watchEventsForMonth(slot.startTime).first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
    } catch (_) {}

    final existing = _scheduledMinutesOnDay(slot.startTime, dayEvents);
    final newMin = slot.endTime.difference(slot.startTime).inMinutes;
    if (existing + newMin > prefs.dailyMaxScheduledMinutes) {
      final updated = state.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(slotsConsumed: true);
      }).toList();
      final guardrail = ChatMessage(
        content: _guardrailText(existing, newMin, prefs.dailyMaxScheduledMinutes, slot.startTime),
        sender: MessageSender.assistant,
        pendingEvent: PendingEvent(
          title: eventTitle,
          startAt: slot.startTime,
          endAt: slot.endTime,
          existingMinutes: existing,
          dailyMax: prefs.dailyMaxScheduledMinutes,
        ),
      );
      emit(state.copyWith(messages: [...updated, guardrail]));
      return;
    }

    final event = CalendarEventEntity(
      id: const Uuid().v4(),
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
      title: eventTitle,
      startAt: slot.startTime,
      endAt: slot.endTime,
      eventType: CalendarEventType.personal,
      sourceCollection: EventSourceCollection.personal,
    );
    await _calendarRepository.createPersonalEvent(event);
    await _preferencesService.recordAcceptedSlot(slot.startTime).catchError((_) {});

    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(slotsConsumed: true);
    }).toList();

    final confirmation = ChatMessage(
      content: '"$eventTitle" ${_formatRange(slot)} olarak takvime eklendi.',
      sender: MessageSender.assistant,
    );

    emit(state.copyWith(
      messages: [...updated, confirmation],
      status: AssistantStatus.navigate,
      redirectTo: AppRoutes.calendar,
      redirectArgs: {'initialDay': slot.startTime},
      undoable: UndoableAction(
        token: const Uuid().v4(),
        kind: UndoableKind.calendarEvent,
        entityId: event.id,
        label: 'Etkinlik "$eventTitle" eklendi',
      ),
    ));
  }

  Future<void> requestLighterDay() async {
    await sendMessage('Daha boş bir gün öner, başka uygun saatler göster.');
  }

  /// Runs OCR on an image via Gemini Vision, then dispatches the extracted
  /// text (plus an optional caption) to Groq as a framed attachment prompt.
  /// For class schedules (table with day columns), uses Vision's structured
  /// JSON output directly to preserve day-of-week mapping.
  Future<void> sendImage(String imagePath, {String? caption}) async {
    final captionText = caption?.trim() ?? '';
    final userBubble =
        captionText.isEmpty ? '📷 Resim' : '📷 $captionText';

    final withLoading = [
      ...state.messages,
      ChatMessage(content: userBubble, sender: MessageSender.user),
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

    // ── Step 1: ML Kit + per-day text → structured entries (deterministic) ─
    List<Map<String, dynamic>>? scheduleRaw;
    try {
      scheduleRaw = await ScheduleImageParser(_aiPipeline).parse(imagePath);
    } catch (e) {
      print('ML Kit schedule parse failed: $e');
      scheduleRaw = null;
    }

    // ── Step 2: Fallback to Vision-only structured schedule extraction ──
    scheduleRaw ??= await _aiPipeline.extractScheduleFromImage(imagePath);

    if (scheduleRaw != null && scheduleRaw.length >= 3) {
      final parsed = <ScheduleEntry>[];
      for (final m in scheduleRaw) {
        final title = (m['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final dow = (m['dayOfWeek'] as num?)?.toInt();
        final sh = (m['startHour'] as num?)?.toInt();
        final sm = (m['startMinute'] as num?)?.toInt() ?? 0;
        final eh = (m['endHour'] as num?)?.toInt();
        final em = (m['endMinute'] as num?)?.toInt() ?? 0;
        if (dow == null || dow < 1 || dow > 7) continue;
        if (sh == null || sh < 0 || sh > 23) continue;
        if (eh == null || eh < 0 || eh > 23) continue;
        parsed.add(ScheduleEntry(
          title: title,
          description: (m['description'] ?? '').toString(),
          dayOfWeek: dow,
          startHour: sh,
          startMinute: sm,
          endHour: eh,
          endMinute: em,
        ));
      }

      if (parsed.length >= 3) {
        emit(state.copyWith(
          messages: [
            ...withLoading.where((m) => !m.isLoading),
            ChatMessage(
              content:
                  '${parsed.length} tekrarlayan ders buldum. Hangi haftalara ekleyim?',
              sender: MessageSender.assistant,
              pendingSchedule: PendingScheduleImport(entries: parsed),
            ),
          ],
          status: AssistantStatus.idle,
        ));
        return;
      }
    }

    // ── Fall back to plain OCR + Groq for non-schedule images ───────────
    final extracted = await _aiPipeline.extractTextFromImage(imagePath);
    if (extracted == null || extracted.trim().isEmpty) {
      emit(state.copyWith(
        messages: [
          ...withLoading.where((m) => !m.isLoading),
          ChatMessage(
            content:
                'Resimden okunabilir bir metin çıkaramadım. Daha net bir fotoğrafla tekrar dener misin?',
            sender: MessageSender.assistant,
          ),
        ],
        status: AssistantStatus.idle,
      ));
      return;
    }

    final framed = StringBuffer()
      ..writeln('Kullanıcı bir resim ekledi. Resimden çıkarılan metin:')
      ..writeln('---')
      ..writeln(extracted)
      ..writeln('---');
    if (captionText.isNotEmpty) {
      framed.writeln('Kullanıcının talebi: $captionText');
    } else {
      framed.writeln(
          'Kullanıcı not eklemedi. İçerik bir ders programı / haftalık takvim / 3+ etkinlik içeriyorsa create_batch ile takvime ekle. Görev listesi ise tasks oluştur.');
    }

    try {
      final domains = await _domainRepository.fetchDomains();
      final now = DateTime.now();
      List<CalendarEventEntity> calendarEvents = [];
      try {
        calendarEvents = await _calendarRepository
            .watchEventsForMonth(now)
            .first
            .timeout(const Duration(seconds: 2), onTimeout: () => []);
      } catch (_) {}

      final appData = """
      BUGÜN: ${now.toIso8601String().split('T')[0]}
      DOMAINS:
      ${domains.map((d) => "- [ID: ${d.id}] ${d.name}").join("\n")}
      MEVCUT TAKVİM:
      ${calendarEvents.map((e) => "- ${e.title} (${e.startAt.toIso8601String()})").join("\n")}
      """;

      final aiResult = await _aiPipeline.dispatch(
        framed.toString(),
        const [],
        appData: appData,
      );
      print('IMAGE DISPATCH: ${aiResult.domain} ${aiResult.action}');

      PendingScheduleImport? pendingSchedule;
      String? responseOverride;

      if (aiResult.domain == AppDomain.calendar &&
          aiResult.action == 'ask_schedule_scope') {
        final rawEntries = aiResult.payload['entries'];
        final list = (rawEntries is List) ? rawEntries : const [];
        final parsed = <ScheduleEntry>[];
        for (final raw in list) {
          if (raw is! Map) continue;
          final m = raw.cast<String, dynamic>();
          final title = (m['title'] ?? '').toString().trim();
          if (title.isEmpty) continue;
          final dow = (m['dayOfWeek'] as num?)?.toInt();
          final sh = (m['startHour'] as num?)?.toInt();
          final sm = (m['startMinute'] as num?)?.toInt() ?? 0;
          final eh = (m['endHour'] as num?)?.toInt();
          final em = (m['endMinute'] as num?)?.toInt() ?? 0;
          if (dow == null || dow < 1 || dow > 7) continue;
          if (sh == null || sh < 0 || sh > 23) continue;
          if (eh == null || eh < 0 || eh > 23) continue;
          parsed.add(ScheduleEntry(
            title: title,
            description: (m['description'] ?? '').toString(),
            dayOfWeek: dow,
            startHour: sh,
            startMinute: sm,
            endHour: eh,
            endMinute: em,
          ));
        }
        if (parsed.isNotEmpty) {
          pendingSchedule = PendingScheduleImport(entries: parsed);
          responseOverride =
              '${parsed.length} tekrarlayan ders buldum. Hangi haftalara ekleyim?';
        } else {
          responseOverride =
              'Resimdeki takvimden ders çıkaramadım. Daha net bir görüntü dener misin?';
        }
      }

      emit(state.copyWith(
        messages: [
          ...withLoading.where((m) => !m.isLoading),
          ChatMessage(
            content: responseOverride ?? aiResult.responseText,
            sender: MessageSender.assistant,
            pendingSchedule: pendingSchedule,
          ),
        ],
        status: AssistantStatus.idle,
      ));
    } catch (e) {
      print("Image dispatch error: $e");
      emit(state.copyWith(
        messages: withLoading.where((m) => !m.isLoading).toList(),
        status: AssistantStatus.error,
        errorMessage: 'Resim işlenirken bir hata oluştu.',
      ));
    }
  }

  String _formatRange(SuggestedSlot s) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = '${two(s.startTime.day)}.${two(s.startTime.month)}';
    final start = '${two(s.startTime.hour)}:${two(s.startTime.minute)}';
    final end = '${two(s.endTime.hour)}:${two(s.endTime.minute)}';
    return '$d $start–$end';
  }

  int _scheduledMinutesOnDay(DateTime day, List<CalendarEventEntity> events) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    int total = 0;
    for (final e in events) {
      if (e.endAt.isBefore(start) || e.startAt.isAfter(end)) continue;
      final clipStart = e.startAt.isBefore(start) ? start : e.startAt;
      final clipEnd = e.endAt.isAfter(end) ? end : e.endAt;
      total += clipEnd.difference(clipStart).inMinutes.clamp(0, 24 * 60);
    }
    return total;
  }

  String _guardrailText(int existing, int newMin, int max, DateTime day) {
    String hm(int min) {
      final h = min ~/ 60;
      final m = min % 60;
      if (h == 0) return '$m dk';
      if (m == 0) return '$h sa';
      return '$h sa $m dk';
    }
    final dayStr = '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
    return '$dayStr için zaten ${hm(existing)} planın var. '
        'Bu etkinlik (${hm(newMin)}) eklenirse toplam ${hm(existing + newMin)} olacak '
        've günlük sağlıklı limitini (${hm(max)}) aşacaksın. '
        'Kendine bir mola hak ediyorsun. Yine de eklemek istiyor musun?';
  }

  Future<void> confirmPendingEvent(String messageId) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => ChatMessage(content: '', sender: MessageSender.assistant),
    );
    final pe = msg.pendingEvent;
    if (pe == null || msg.pendingResolved) return;

    final event = CalendarEventEntity(
      id: const Uuid().v4(),
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
      title: pe.title,
      description: pe.description ?? '',
      startAt: pe.startAt,
      endAt: pe.endAt,
      eventType: CalendarEventType.personal,
      sourceCollection: EventSourceCollection.personal,
    );
    await _calendarRepository.createPersonalEvent(event);

    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(pendingResolved: true);
    }).toList();

    emit(state.copyWith(
      messages: [
        ...updated,
        ChatMessage(
          content: '"${pe.title}" eklendi. Yine de bir mola almayı unutma.',
          sender: MessageSender.assistant,
        ),
      ],
      status: AssistantStatus.navigate,
      redirectTo: AppRoutes.calendar,
      redirectArgs: {'initialDay': pe.startAt},
      undoable: UndoableAction(
        token: const Uuid().v4(),
        kind: UndoableKind.calendarEvent,
        entityId: event.id,
        label: 'Etkinlik "${pe.title}" eklendi',
      ),
    ));
  }

  void dismissPendingEvent(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(pendingResolved: true);
    }).toList();
    emit(state.copyWith(messages: updated));
  }

  /// Materialises a pending schedule import into actual calendar events
  /// across [weeks] weeks. The first occurrence of each entry's weekday
  /// is found relative to today (skipping past times); subsequent weeks
  /// are +7 days each.
  Future<void> acceptScheduleImport({
    required String messageId,
    required int weeks,
    int weekOffset = 0,
  }) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => ChatMessage(content: '', sender: MessageSender.assistant),
    );
    final pending = msg.pendingSchedule;
    if (pending == null || msg.pendingScheduleResolved) return;

    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(pendingScheduleResolved: true);
    }).toList();
    emit(state.copyWith(
      messages: updated,
      status: AssistantStatus.responding,
    ));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int created = 0;

    for (final entry in pending.entries) {
      // Find next occurrence of this weekday on/after today.
      var diff = entry.dayOfWeek - today.weekday;
      if (diff < 0) diff += 7;
      var firstOccurrence = today.add(Duration(days: diff));
      // If it's today but the start time has already passed, push to next week.
      final candidateStart = DateTime(
        firstOccurrence.year,
        firstOccurrence.month,
        firstOccurrence.day,
        entry.startHour,
        entry.startMinute,
      );
      if (candidateStart.isBefore(now)) {
        firstOccurrence = firstOccurrence.add(const Duration(days: 7));
      }
      // Apply caller's week offset (1 = "haftaya").
      firstOccurrence = firstOccurrence.add(Duration(days: 7 * weekOffset));

      for (var w = 0; w < weeks; w++) {
        final occurrenceDate = firstOccurrence.add(Duration(days: 7 * w));
        final start = DateTime(
          occurrenceDate.year,
          occurrenceDate.month,
          occurrenceDate.day,
          entry.startHour,
          entry.startMinute,
        );
        final end = DateTime(
          occurrenceDate.year,
          occurrenceDate.month,
          occurrenceDate.day,
          entry.endHour,
          entry.endMinute,
        );
        final event = CalendarEventEntity(
          id: const Uuid().v4(),
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
          title: entry.title,
          description: entry.description ?? '',
          startAt: start,
          endAt: end,
          eventType: CalendarEventType.personal,
          sourceCollection: EventSourceCollection.personal,
        );
        try {
          await _calendarRepository.createPersonalEvent(event);
          created++;
        } catch (_) {}
      }
    }

    emit(state.copyWith(
      messages: [
        ...state.messages.map((m) {
          if (m.id != messageId) return m;
          return m.copyWith(pendingScheduleResolved: true);
        }),
        ChatMessage(
          content: created > 0
              ? '$created etkinlik takvime eklendi.'
              : 'Etkinlik oluşturulamadı.',
          sender: MessageSender.assistant,
        ),
      ],
      status: created > 0
          ? AssistantStatus.navigate
          : AssistantStatus.idle,
      redirectTo: created > 0 ? AppRoutes.calendar : null,
    ));
  }

  void dismissScheduleImport(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(pendingScheduleResolved: true);
    }).toList();
    emit(state.copyWith(messages: updated));
  }

  Future<void> requestBreakInstead(String messageId) async {
    dismissPendingEvent(messageId);
    await sendMessage('Günüm dolu görünüyor, bana daha boş bir gün öner ya da kısa bir mola için uygun bir slot bul.');
  }

  Future<void> undoLast(String token) async {
    final u = state.undoable;
    if (u == null || u.token != token) return;
    try {
      switch (u.kind) {
        case UndoableKind.task:
          await _taskRepository.deleteTask(u.entityId);
          break;
        case UndoableKind.calendarEvent:
          final placeholder = CalendarEventEntity(
            id: u.entityId,
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'default',
            title: '',
            startAt: DateTime.now(),
            endAt: DateTime.now(),
            eventType: CalendarEventType.personal,
          );
          await _calendarRepository.deleteEvent(placeholder);
          break;
        case UndoableKind.habit:
          await _habitsRef().doc(u.entityId).delete();
          break;
        case UndoableKind.domain:
          await _domainRepository.deleteDomain(u.entityId);
          break;
      }
      emit(state.copyWith(
        clearUndoable: true,
        messages: [
          ...state.messages,
          ChatMessage(
            content: '${u.label} geri alındı.',
            sender: MessageSender.assistant,
          ),
        ],
      ));
    } catch (e) {
      print('Undo failed: $e');
      emit(state.copyWith(
        clearUndoable: true,
        status: AssistantStatus.error,
        errorMessage: 'Geri alma başarısız oldu.',
      ));
    }
  }

  void clearUndoable() {
    if (state.undoable == null) return;
    emit(state.copyWith(clearUndoable: true));
  }

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
