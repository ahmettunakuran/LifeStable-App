import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/task_entity.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc() : super(TasksInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<DeleteTask>(_onDeleteTask);
  }

  final List<TaskEntity> _tasks = [];

  void _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) {
    emit(TasksLoading());
    // Simulate loading
    emit(TasksLoaded(List.from(_tasks)));
  }

  void _onAddTask(AddTask event, Emitter<TasksState> emit) {
    _tasks.add(event.task);
    emit(TasksLoaded(List.from(_tasks)));
  }

  void _onUpdateTaskStatus(UpdateTaskStatus event, Emitter<TasksState> emit) {
    final index = _tasks.indexWhere((t) => t.id == event.taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: event.status);
      emit(TasksLoaded(List.from(_tasks)));
    }
  }

  void _onDeleteTask(DeleteTask event, Emitter<TasksState> emit) {
    _tasks.removeWhere((t) => t.id == event.taskId);
    emit(TasksLoaded(List.from(_tasks)));
  }
}
