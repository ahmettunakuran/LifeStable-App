class TaskEntity {
  TaskEntity({
    required this.id,
    required this.title,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
}

