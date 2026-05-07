// ignore_for_file: lines_longer_than_80_chars

/// Task Management — BLoC Layer Tests — TC11, TC12, TC13, TC19
///
/// Tests for TasksBloc (presentation/business layer).
/// MockTaskRepository stubs all Firestore interactions so tests run offline.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project_lifestable/features/tasks/domain/entities/task_entity.dart';
import 'package:project_lifestable/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:project_lifestable/features/tasks/presentation/bloc/tasks_event.dart';
import 'package:project_lifestable/features/tasks/presentation/bloc/tasks_state.dart';

import '../../helpers/fixtures.dart';
import '../../mocks/mocks.dart';

void main() {
  late MockTaskRepository mockRepo;

  setUpAll(registerFallbacks);

  setUp(() {
    mockRepo = MockTaskRepository();
    // Default: watchTasks returns an empty stream unless overridden.
    when(() => mockRepo.watchTasks()).thenAnswer((_) => const Stream.empty());
  });

  // TC11 ────────────────────────────────────────────────────────────────────
  group('TC11: create a new task', () {
    blocTest<TasksBloc, TasksState>(
      'AddTask event calls repository.createOrUpdateTask once',
      build: () {
        when(() => mockRepo.createOrUpdateTask(any()))
            .thenAnswer((_) async {});
        return TasksBloc(mockRepo);
      },
      act: (bloc) => bloc.add(
        AddTask(Fixtures.task(title: 'Buy groceries')),
      ),
      expect: () => <TasksState>[],
      verify: (_) {
        verify(() => mockRepo.createOrUpdateTask(any())).called(1);
      },
    );
  });

  // TC12 ────────────────────────────────────────────────────────────────────
  group('TC12: move task to In-Progress', () {
    blocTest<TasksBloc, TasksState>(
      'UpdateTaskStatus(inProgress) calls createOrUpdateTask with updated status',
      build: () {
        when(() => mockRepo.createOrUpdateTask(any()))
            .thenAnswer((_) async {});
        return TasksBloc(mockRepo);
      },
      seed: () => TasksLoaded([Fixtures.task(id: 'task-1', status: TaskStatus.todo)]),
      act: (bloc) => bloc.add(UpdateTaskStatus('task-1', TaskStatus.inProgress)),
      expect: () => <TasksState>[],
      verify: (_) {
        final captured =
            verify(() => mockRepo.createOrUpdateTask(captureAny())).captured;
        final updated = captured.first as TaskEntity;
        expect(updated.status, TaskStatus.inProgress,
            reason: 'Repository must receive the task with status=inProgress.');
      },
    );
  });

  // TC13 ────────────────────────────────────────────────────────────────────
  group('TC13: mark task as Done', () {
    blocTest<TasksBloc, TasksState>(
      'UpdateTaskStatus(done) calls createOrUpdateTask with status=done',
      build: () {
        when(() => mockRepo.createOrUpdateTask(any()))
            .thenAnswer((_) async {});
        return TasksBloc(mockRepo);
      },
      seed: () => TasksLoaded([
        Fixtures.task(id: 'task-2', status: TaskStatus.inProgress),
      ]),
      act: (bloc) => bloc.add(UpdateTaskStatus('task-2', TaskStatus.done)),
      expect: () => <TasksState>[],
      verify: (_) {
        final captured =
            verify(() => mockRepo.createOrUpdateTask(captureAny())).captured;
        final updated = captured.first as TaskEntity;
        expect(updated.status, TaskStatus.done,
            reason: 'Task moved to done must have status=done in Firestore.');
      },
    );
  });

  // TC19 ────────────────────────────────────────────────────────────────────
  group('TC19: delete a task', () {
    blocTest<TasksBloc, TasksState>(
      'DeleteTask event calls repository.deleteTask with correct taskId',
      build: () {
        when(() => mockRepo.deleteTask(any())).thenAnswer((_) async {});
        return TasksBloc(mockRepo);
      },
      act: (bloc) => bloc.add(DeleteTask('task-99')),
      expect: () => <TasksState>[],
      verify: (_) {
        verify(() => mockRepo.deleteTask('task-99')).called(1);
      },
    );

    blocTest<TasksBloc, TasksState>(
      'after stream update, deleted task is absent from TasksLoaded',
      build: () {
        when(() => mockRepo.watchTasks()).thenAnswer(
          (_) => Stream.value([Fixtures.task(id: 'task-keep')]),
        );
        return TasksBloc(mockRepo);
      },
      act: (bloc) => bloc.add(LoadTasks()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TasksLoading>(),
        isA<TasksLoaded>().having(
          (s) => s.tasks.any((t) => t.id == 'task-delete'),
          'deleted task present',
          isFalse,
        ),
      ],
    );
  });

  // LoadTasks smoke test (used by multiple TCs as prerequisite)
  group('LoadTasks lifecycle', () {
    blocTest<TasksBloc, TasksState>(
      'emits [TasksLoading, TasksLoaded] when watchTasks stream emits',
      build: () {
        when(() => mockRepo.watchTasks()).thenAnswer(
          (_) => Stream.value([Fixtures.task()]),
        );
        return TasksBloc(mockRepo);
      },
      act: (bloc) => bloc.add(LoadTasks()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TasksLoading>(),
        isA<TasksLoaded>(),
      ],
    );

    blocTest<TasksBloc, TasksState>(
      'emits TasksError when repository stream throws',
      build: () {
        when(() => mockRepo.watchTasks())
            .thenAnswer((_) => Stream.error(Exception('Firestore unavailable')));
        return TasksBloc(mockRepo);
      },
      act: (bloc) => bloc.add(LoadTasks()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<TasksLoading>(),
        isA<TasksError>(),
      ],
    );
  });
}
