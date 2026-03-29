import 'entities/task_entity.dart';

int _priorityRank(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return 3;
    case TaskPriority.medium:
      return 2;
    case TaskPriority.low:
      return 1;
  }
}

/// High priority first; ties broken by title.
int compareTasksByPriorityHighFirst(TaskEntity a, TaskEntity b) {
  final byP = _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
  if (byP != 0) return byP;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

void sortTasksByPriorityHighFirst(List<TaskEntity> tasks) {
  tasks.sort(compareTasksByPriorityHighFirst);
}
