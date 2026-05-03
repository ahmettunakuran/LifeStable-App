import 'package:uuid/uuid.dart';

enum MessageSender { user, assistant }

class SuggestedSlot {
  final DateTime startTime;
  final DateTime endTime;
  const SuggestedSlot({required this.startTime, required this.endTime});

  Duration get duration => endTime.difference(startTime);
}

class PendingEvent {
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final int existingMinutes;
  final int dailyMax;

  const PendingEvent({
    required this.title,
    this.description,
    required this.startAt,
    required this.endAt,
    required this.existingMinutes,
    required this.dailyMax,
  });

  int get newEventMinutes => endAt.difference(startAt).inMinutes;
  int get totalMinutes => existingMinutes + newEventMinutes;
}

/// Single recurring class/session parsed from a schedule image.
class ScheduleEntry {
  final String title;
  final String? description;
  final int dayOfWeek; // 1=Mon, 7=Sun (ISO)
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const ScheduleEntry({
    required this.title,
    this.description,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

class PendingScheduleImport {
  final List<ScheduleEntry> entries;
  const PendingScheduleImport({required this.entries});
}

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isLoading;
  final List<SuggestedSlot>? suggestedSlots;
  final String? slotTitle;
  final bool slotsConsumed;
  final PendingEvent? pendingEvent;
  final bool pendingResolved;
  final PendingScheduleImport? pendingSchedule;
  final bool pendingScheduleResolved;

  ChatMessage({
    String? id,
    required this.content,
    required this.sender,
    DateTime? timestamp,
    this.isLoading = false,
    this.suggestedSlots,
    this.slotTitle,
    this.slotsConsumed = false,
    this.pendingEvent,
    this.pendingResolved = false,
    this.pendingSchedule,
    this.pendingScheduleResolved = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    List<SuggestedSlot>? suggestedSlots,
    String? slotTitle,
    bool? slotsConsumed,
    PendingEvent? pendingEvent,
    bool? pendingResolved,
    PendingScheduleImport? pendingSchedule,
    bool? pendingScheduleResolved,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      sender: sender,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
      suggestedSlots: suggestedSlots ?? this.suggestedSlots,
      slotTitle: slotTitle ?? this.slotTitle,
      slotsConsumed: slotsConsumed ?? this.slotsConsumed,
      pendingEvent: pendingEvent ?? this.pendingEvent,
      pendingResolved: pendingResolved ?? this.pendingResolved,
      pendingSchedule: pendingSchedule ?? this.pendingSchedule,
      pendingScheduleResolved:
          pendingScheduleResolved ?? this.pendingScheduleResolved,
    );
  }
}