import '../entities/task_entity.dart';

abstract class TaskRepository {
  Future<List<TaskEntity>> fetchTasks();
  Future<void> createOrUpdateTask(TaskEntity task);
  Future<void> deleteTask(String taskId);
  Stream<List<TaskEntity>> watchTasks();
}
