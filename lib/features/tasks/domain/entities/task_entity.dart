enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high }

class TaskEntity {
  TaskEntity({
    required this.id,
    required this.domainId,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.teamId,
    this.assignedTo,
    this.version = 0,
    this.updatedAt,
    this.lastModifiedBy,
  });

  final String id;
  final String domainId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? teamId;
  final String? assignedTo;
  final int version;
  final DateTime? updatedAt;
  final String? lastModifiedBy;

  TaskEntity copyWith({
    String? id,
    String? domainId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    String? teamId,
    String? assignedTo,
    int? version,
    DateTime? updatedAt,
    String? lastModifiedBy,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      domainId: domainId ?? this.domainId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      teamId: teamId ?? this.teamId,
      assignedTo: assignedTo ?? this.assignedTo,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'domainId': domainId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (teamId != null) 'teamId': teamId,
      if (assignedTo != null) 'assignedTo': assignedTo,
    };
  }

  factory TaskEntity.fromFirestore(String id, Map<String, dynamic> data) {
    return TaskEntity(
      id: id,
      domainId: data['domainId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      status: TaskStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TaskStatus.todo,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      dueDate:
          data['dueDate'] != null ? DateTime.parse(data['dueDate'] as String) : null,
      teamId: data['teamId'] as String?,
      assignedTo: data['assignedTo'] as String?,
      version: data['version'] as int? ?? 0,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'] as String)
          : null,
      lastModifiedBy: data['lastModifiedBy'] as String?,
    );
  }
}
