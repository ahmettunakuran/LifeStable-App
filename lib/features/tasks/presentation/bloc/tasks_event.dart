import '../../domain/entities/task_entity.dart';

abstract class TasksEvent {}

class LoadTasks extends TasksEvent {}

class AddTask extends TasksEvent {
  AddTask(this.task);
  final TaskEntity task;
}

class UpdateTaskStatus extends TasksEvent {
  UpdateTaskStatus(this.taskId, this.status);
  final String taskId;
  final TaskStatus status;
}

class DeleteTask extends TasksEvent {
  DeleteTask(this.taskId);
  final String taskId;
}

class TasksUpdated extends TasksEvent {
  TasksUpdated(this.tasks);
  final List<TaskEntity> tasks;
}
