import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_lifestable/features/calendar/domain/entities/calendar_event_entity.dart';
import 'package:project_lifestable/features/dashboard/domain/entities/domain_entity.dart';
import 'package:project_lifestable/features/habits/presentation/habit.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';

class Fixtures {
  Fixtures._();

  static TaskEntity task({
    String id = 'task-1',
    String domainId = 'domain-1',
    String title = 'Test Task',
    String? description,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? teamId,
    String? assignedTo,
    int version = 0,
    DateTime? updatedAt,
    String? lastModifiedBy,
  }) =>
      TaskEntity(
        id: id,
        domainId: domainId,
        title: title,
        description: description,
        status: status,
        priority: priority,
        dueDate: dueDate,
        teamId: teamId,
        assignedTo: assignedTo,
        version: version,
        updatedAt: updatedAt,
        lastModifiedBy: lastModifiedBy,
      );

  static NoteEntity note({
    String id = 'note-1',
    String userId = 'user-1',
    String domainId = 'domain-1',
    String title = 'Test Note',
    String content = 'Test content',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime(2024, 6, 15, 12);
    return NoteEntity(
      id: id,
      userId: userId,
      domainId: domainId,
      title: title,
      content: content,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  static DomainEntity domain({
    String id = 'domain-1',
    String name = 'Health',
    String? description,
    int iconCode = 0xe1af,
    String colorHex = '#7C4DFF',
    String? teamId,
  }) =>
      DomainEntity(
        id: id,
        name: name,
        description: description,
        iconCode: iconCode,
        colorHex: colorHex,
        teamId: teamId,
      );

  static CalendarEventEntity calendarEvent({
    String id = 'event-1',
    String userId = 'user-1',
    String title = 'Team Meeting',
    DateTime? startAt,
    DateTime? endAt,
    CalendarEventType eventType = CalendarEventType.personal,
    String? domainId,
    String? linkedTaskId,
    String? teamId,
    List<String> assignedMemberIds = const [],
    EventSourceCollection sourceCollection = EventSourceCollection.personal,
  }) {
    final base = DateTime(2024, 6, 15, 10);
    return CalendarEventEntity(
      id: id,
      userId: userId,
      title: title,
      startAt: startAt ?? base,
      endAt: endAt ?? base.add(const Duration(hours: 1)),
      eventType: eventType,
      domainId: domainId,
      linkedTaskId: linkedTaskId,
      teamId: teamId,
      assignedMemberIds: assignedMemberIds,
      sourceCollection: sourceCollection,
    );
  }

  static Habit habit({
    String id = 'habit-1',
    String name = 'Morning Run',
    String domainId = 'domain-1',
    String domainName = 'Health',
    int streak = 0,
    DateTime? lastCompleted,
    bool isPaused = false,
    String userId = 'user-1',
    DateTime? createdAt,
    List<String> completedDates = const [],
  }) =>
      Habit(
        id: id,
        name: name,
        domainId: domainId,
        domainName: domainName,
        streak: streak,
        lastCompleted: lastCompleted,
        isPaused: isPaused,
        userId: userId,
        createdAt: createdAt ?? DateTime(2024, 1, 1),
        completedDates: completedDates,
      );

  // Firestore-like map for NoteEntity round-trip tests
  static Map<String, dynamic> noteFirestoreMap({
    String userId = 'user-1',
    String domainId = 'domain-1',
    String title = 'Test Note',
    String content = 'Test content',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime(2024, 6, 15, 12);
    return {
      'userId': userId,
      'domainId': domainId,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt ?? now),
      'updatedAt': Timestamp.fromDate(updatedAt ?? now),
    };
  }
}
