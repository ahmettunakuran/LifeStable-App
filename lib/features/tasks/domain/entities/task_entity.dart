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
  });

  final String id;
  final String domainId; // Added to link task to a domain
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;

  TaskEntity copyWith({
    String? id,
    String? domainId,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      domainId: domainId ?? this.domainId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
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
      dueDate: data['dueDate'] != null ? DateTime.parse(data['dueDate'] as String) : null,
    );
  }
}
