import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/entities/calendar_event_entity.dart';
import '../domain/repositories/calendar_repository.dart';

// ─── States ──────────────────────────────────────────────────────────────────

sealed class CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarLoaded extends CalendarState {
  CalendarLoaded({
    required this.eventMap,
    required this.selectedDay,
    required this.focusedDay,
    required this.selectedEvents,
    this.conflicts = const {},
  });

  /// Key: midnight-normalised date. Value: all events starting that day.
  final Map<DateTime, List<CalendarEventEntity>> eventMap;
  final DateTime selectedDay;
  final DateTime focusedDay;

  /// Events on [selectedDay], pre-sliced from [eventMap].
  final List<CalendarEventEntity> selectedEvents;

  /// IDs of events that overlap with at least one other event on the same day.
  final Set<String> conflicts;

  bool hasConflict(String eventId) => conflicts.contains(eventId);
}

class CalendarError extends CalendarState {
  CalendarError(this.message);
  final String message;
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit(this._repo) : super(CalendarLoading());

  final CalendarRepository _repo;
  StreamSubscription<List<CalendarEventEntity>>? _sub;

  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void init() => _subscribe(_focused);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void onPageChanged(DateTime focusedDay) {
    _focused = focusedDay;
    _subscribe(focusedDay);
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    _selected = selectedDay;
    _focused = focusedDay;
    final current = state;
    if (current is CalendarLoaded) {
      emit(CalendarLoaded(
        eventMap: current.eventMap,
        selectedDay: selectedDay,
        focusedDay: focusedDay,
        selectedEvents: _eventsFor(current.eventMap, selectedDay),
        conflicts: current.conflicts,
      ));
    }
  }

  /// Returns all events that would conflict with [start]–[end] window,
  /// optionally excluding [excludeId] (useful when editing an existing event).
  List<CalendarEventEntity> findConflicts({
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) {
    final current = state;
    if (current is! CalendarLoaded) return [];

    final candidate = CalendarEventEntity(
      id: excludeId ?? '__check__',
      userId: '',
      title: '',
      startAt: start,
      endAt: end,
    );

    final dayKey = _normalise(start);
    final dayEvents = current.eventMap[dayKey] ?? [];

    return dayEvents
        .where((e) => e.id != excludeId && candidate.overlapsWith(e))
        .toList();
  }

  // ── Save routing ──────────────────────────────────────────────────────────

  Future<void> saveEvent(CalendarEventEntity event) {
    final isNew = event.id.isEmpty;
    if (event.isTeamEvent) {
      return isNew
          ? _repo.createTeamEvent(event)
          : _repo.updateEvent(event);
    }
    return isNew
        ? _repo.createPersonalEvent(event)
        : _repo.updateEvent(event);
  }

  Future<void> deleteEvent(CalendarEventEntity event) =>
      _repo.deleteEvent(event);

  // ── Internal ───────────────────────────────────────────────────────────────

  void _subscribe(DateTime month) {
    _sub?.cancel();
    _sub = _repo.watchEventsForMonth(month).listen(
          (events) {
        final map = _buildMap(events);
        final conflicts = _detectConflicts(map);
        emit(CalendarLoaded(
          eventMap: map,
          selectedDay: _selected,
          focusedDay: _focused,
          selectedEvents: _eventsFor(map, _selected),
          conflicts: conflicts,
        ));
      },
      onError: (e) => emit(CalendarError(e.toString())),
    );
  }

  Map<DateTime, List<CalendarEventEntity>> _buildMap(
      List<CalendarEventEntity> events,
      ) {
    final map = <DateTime, List<CalendarEventEntity>>{};
    for (final e in events) {
      map.putIfAbsent(_normalise(e.startAt), () => []).add(e);
    }
    return map;
  }

  /// For each day, mark any two events that temporally overlap.
  Set<String> _detectConflicts(
      Map<DateTime, List<CalendarEventEntity>> map,
      ) {
    final conflictIds = <String>{};
    for (final dayEvents in map.values) {
      for (int i = 0; i < dayEvents.length; i++) {
        for (int j = i + 1; j < dayEvents.length; j++) {
          if (dayEvents[i].overlapsWith(dayEvents[j])) {
            conflictIds.add(dayEvents[i].id);
            conflictIds.add(dayEvents[j].id);
          }
        }
      }
    }
    return conflictIds;
  }

  List<CalendarEventEntity> _eventsFor(
      Map<DateTime, List<CalendarEventEntity>> map,
      DateTime day,
      ) =>
      map[_normalise(day)] ?? [];

  DateTime _normalise(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}