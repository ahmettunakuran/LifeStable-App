enum CalendarEventType { personal, task, classSchedule, team }

extension CalendarEventTypeX on CalendarEventType {
  String get label => switch (this) {
    CalendarEventType.personal => 'Personal',
    CalendarEventType.task => 'Task',
    CalendarEventType.classSchedule => 'Class',
    CalendarEventType.team => 'Team',
  };
}

class CalendarEventEntity {
  const CalendarEventEntity({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startAt,
    required this.endAt,
    this.eventType = CalendarEventType.personal,
    this.domainId,
    this.linkedTaskId,
    this.linkedTaskTitle,
    this.colorHex,
    this.isRecurring = false,
    this.externalEventId,
    // ── Team fields ─────────────────────────────────────────
    this.teamId,
    this.teamName,
    this.assignedMemberIds = const [],
    this.sourceCollection = EventSourceCollection.personal,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final CalendarEventType eventType;

  // Personal / task link
  final String? domainId;
  final String? linkedTaskId;
  final String? linkedTaskTitle;
  final String? colorHex;
  final bool isRecurring;
  final String? externalEventId;

  // Team fields
  /// The team this event belongs to (only set when eventType == team).
  final String? teamId;

  /// Denormalised team name for display without extra query.
  final String? teamName;

  /// UIDs of members assigned / invited to this event.
  final List<String> assignedMemberIds;

  /// Whether this event lives in the personal collection or a team collection.
  final EventSourceCollection sourceCollection;

  // ── Computed helpers ────────────────────────────────────────────────────

  bool get hasLinkedTask => linkedTaskId != null && linkedTaskId!.isNotEmpty;
  bool get isTeamEvent => eventType == CalendarEventType.team && teamId != null;

  Duration get duration => endAt.difference(startAt);

  /// Returns true when [other] temporally overlaps with this event.
  bool overlapsWith(CalendarEventEntity other) {
    if (id == other.id) return false;
    return startAt.isBefore(other.endAt) && endAt.isAfter(other.startAt);
  }

  CalendarEventEntity copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    CalendarEventType? eventType,
    String? domainId,
    String? linkedTaskId,
    String? linkedTaskTitle,
    String? colorHex,
    bool? isRecurring,
    String? externalEventId,
    String? teamId,
    String? teamName,
    List<String>? assignedMemberIds,
    EventSourceCollection? sourceCollection,
  }) =>
      CalendarEventEntity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        description: description ?? this.description,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        eventType: eventType ?? this.eventType,
        domainId: domainId ?? this.domainId,
        linkedTaskId: linkedTaskId ?? this.linkedTaskId,
        linkedTaskTitle: linkedTaskTitle ?? this.linkedTaskTitle,
        colorHex: colorHex ?? this.colorHex,
        isRecurring: isRecurring ?? this.isRecurring,
        externalEventId: externalEventId ?? this.externalEventId,
        teamId: teamId ?? this.teamId,
        teamName: teamName ?? this.teamName,
        assignedMemberIds: assignedMemberIds ?? this.assignedMemberIds,
        sourceCollection: sourceCollection ?? this.sourceCollection,
      );

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'title': title,
    'description': description,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
    'eventType': eventType.name,
    if (domainId != null) 'domainId': domainId,
    if (linkedTaskId != null) 'linkedTaskId': linkedTaskId,
    if (linkedTaskTitle != null) 'linkedTaskTitle': linkedTaskTitle,
    if (colorHex != null) 'colorHex': colorHex,
    'isRecurring': isRecurring,
    if (externalEventId != null) 'externalEventId': externalEventId,
    if (teamId != null) 'teamId': teamId,
    if (teamName != null) 'teamName': teamName,
    'assignedMemberIds': assignedMemberIds,
  };

  factory CalendarEventEntity.fromFirestore(
      String id,
      Map<String, dynamic> data, {
        EventSourceCollection source = EventSourceCollection.personal,
      }) =>
      CalendarEventEntity(
        id: id,
        userId: data['userId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        description: data['description'] as String?,
        startAt: DateTime.parse(data['startAt'] as String),
        endAt: DateTime.parse(data['endAt'] as String),
        eventType: CalendarEventType.values.firstWhere(
              (e) => e.name == data['eventType'],
          orElse: () => CalendarEventType.personal,
        ),
        domainId: data['domainId'] as String?,
        linkedTaskId: data['linkedTaskId'] as String?,
        linkedTaskTitle: data['linkedTaskTitle'] as String?,
        colorHex: data['colorHex'] as String?,
        isRecurring: data['isRecurring'] as bool? ?? false,
        externalEventId: data['externalEventId'] as String?,
        teamId: data['teamId'] as String?,
        teamName: data['teamName'] as String?,
        assignedMemberIds: (data['assignedMemberIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
            [],
        sourceCollection: source,
      );
}

enum EventSourceCollection { personal, team }