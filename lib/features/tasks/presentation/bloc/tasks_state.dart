import '../../domain/entities/task_entity.dart';

abstract class TasksState {}

class TasksInitial extends TasksState {}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  TasksLoaded(this.tasks);
  final List<TaskEntity> tasks;
}

class TasksError extends TasksState {
  TasksError(this.message);
  final String message;
}
