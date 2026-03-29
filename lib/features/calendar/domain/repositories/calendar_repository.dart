import '../entities/calendar_event_entity.dart';

abstract interface class CalendarRepository {
  /// Emits merged personal + team events for [month] in real-time.
  Stream<List<CalendarEventEntity>> watchEventsForMonth(DateTime month);

  /// Creates a personal event under `users/{uid}/calendar_events`.
  Future<void> createPersonalEvent(CalendarEventEntity event);

  /// Creates a team event under `teams/{teamId}/calendar_events`.
  /// All team members see this event automatically via [watchEventsForMonth].
  Future<void> createTeamEvent(CalendarEventEntity event);

  /// Updates an existing event in the correct collection.
  Future<void> updateEvent(CalendarEventEntity event);

  /// Deletes an event from the correct collection.
  Future<void> deleteEvent(CalendarEventEntity event);
}