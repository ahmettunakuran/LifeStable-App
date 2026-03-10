import '../entities/task_entity.dart';

abstract class TaskRepository {
  Future<List<TaskEntity>> fetchTasks();

  Future<void> createOrUpdateTask(TaskEntity task);
}

