import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc(this._repository) : super(TasksInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<TasksUpdated>(_onTasksUpdated);
    on<AddTask>(_onAddTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<DeleteTask>(_onDeleteTask);
  }

  final TaskRepository _repository;
  StreamSubscription? _subscription;

  void _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) {
    emit(TasksLoading());
    _subscription?.cancel();
    _subscription = _repository.watchTasks().listen(
      (tasks) => add(TasksUpdated(tasks)),
      onError: (e) => emit(TasksError(e.toString())),
    );
  }

  void _onTasksUpdated(TasksUpdated event, Emitter<TasksState> emit) {
    emit(TasksLoaded(event.tasks));
  }

  Future<void> _onAddTask(AddTask event, Emitter<TasksState> emit) async {
    try {
      await _repository.createOrUpdateTask(event.task);
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  Future<void> _onUpdateTaskStatus(UpdateTaskStatus event, Emitter<TasksState> emit) async {
    try {
      final currentState = state;
      if (currentState is TasksLoaded) {
        final task = currentState.tasks.firstWhere((t) => t.id == event.taskId);
        final updatedTask = task.copyWith(status: event.status);
        await _repository.createOrUpdateTask(updatedTask);
      }
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TasksState> emit) async {
    try {
      await _repository.deleteTask(event.taskId);
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
